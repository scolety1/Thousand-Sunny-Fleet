$script:TsfRuntimeManifestVersion='tsf_runtime_artifact_manifest_v1'
$script:TsfRuntimeKeyLength=32
$script:TsfRuntimeHardPathLimit=240
$script:TsfRuntimeTargetPathLimit=225
$script:TsfRuntimeArtifacts=[ordered]@{
    manifest='manifest.json'
    manifest_temp='mn.tmp'
    manifest_backup='mb.tmp'
    mission='m.json'
    preflight='pf.json'
    role_preflight='rp.json'
    worker_instruction='wi.json'
    worker_result='wr.json'
    adapter_result='ar.json'
    verifier_result='vr.json'
    preservation_packet='pp.json'
    durable_result='dr.json'
    durable_temp='d.tmp'
    event_journal='ej.jsonl'
    usage='u.json'
    stderr='se.log'
    prompt='q.txt'
    queue_document='qd.json'
    queue_result='qe.json'
    lifecycle_result='lc.json'
    runtime_evidence='re.json'
    approval_ledger='al.json'
}

function Get-TsfRuntimeSha256Text {
    param([Parameter(Mandatory)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()}
}

function ConvertTo-TsfRuntimeShortKey {
    param([Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$FullSha256)
    $alphabet='abcdefghijklmnopqrstuvwxyz234567';$bytes=[byte[]]::new(20)
    for($i=0;$i-lt20;$i++){$bytes[$i]=[Convert]::ToByte($FullSha256.Substring($i*2,2),16)}
    $output=[Text.StringBuilder]::new();$buffer=0;$bits=0
    foreach($byte in $bytes){$buffer=($buffer-shl8)-bor$byte;$bits+=8;while($bits-ge5){$bits-=5;[void]$output.Append($alphabet[($buffer-shr$bits)-band31]);$buffer=$buffer-band((1-shl$bits)-1)}}
    $key=$output.ToString();if($key.Length-ne$script:TsfRuntimeKeyLength){throw 'Internal Base32 storage-key length error.'};$key
}

function Get-TsfRuntimeIdentity {
    param([Parameter(Mandatory)][ValidateSet('mission','run','receipt','conflict')][string]$Kind,[Parameter(Mandatory)][object]$Value)
    $json=([pscustomobject][ordered]@{kind=$Kind;value=$Value}|ConvertTo-Json -Compress -Depth 100)
    $full=Get-TsfRuntimeSha256Text $json
    [pscustomobject]@{kind=$Kind;full_sha256=$full;short_key=ConvertTo-TsfRuntimeShortKey $full;encoding='base32_lower_no_padding';effective_security_bits=160}
}

function Get-TsfRuntimeArtifactCatalog { [pscustomobject]$script:TsfRuntimeArtifacts }

function Get-TsfCanonicalRuntimeRoot {
    $repo=Get-TsfKernelFullPath (Get-TsfKernelRoot)
    Get-TsfKernelFullPath (Join-Path $repo '.codex-local\rt')
}

function Assert-TsfCanonicalRuntimeRoot {
    param([Parameter(Mandatory)][string]$RuntimeRoot)
    $expected=Get-TsfCanonicalRuntimeRoot;$actual=Get-TsfKernelFullPath $RuntimeRoot;$repo=Get-TsfKernelFullPath (Get-TsfKernelRoot)
    if(![string]::Equals($actual,$expected,[StringComparison]::OrdinalIgnoreCase)){throw "NONCANONICAL_RUNTIME_ROOT_REJECTED: $actual"}
    if(!(Test-TsfKernelPathInside $actual $repo)-or!(Test-TsfKernelReparseContained $actual $repo)){throw 'CANONICAL_RUNTIME_ROOT_CONTAINMENT_FAILED'}
    $actual
}

function Assert-TsfRuntimePathUnderCanonicalRoot {
    param([Parameter(Mandatory)][string]$Path)
    $root=Assert-TsfCanonicalRuntimeRoot (Get-TsfCanonicalRuntimeRoot);$full=Get-TsfKernelFullPath $Path
    if(!(Test-TsfKernelPathInside $full $root)-or!(Test-TsfKernelReparseContained $full (Get-TsfKernelRoot))){throw "RUNTIME_PATH_OUTSIDE_CANONICAL_ROOT: $full"}
    $full
}

function Test-TsfRuntimePathPlan {
    param([Parameter(Mandatory)][string]$RuntimeRoot,[Parameter(Mandatory)][string[]]$Paths)
    $root=Get-TsfKernelFullPath $RuntimeRoot
    $rows=@();$errors=[Collections.Generic.List[string]]::new()
    foreach($path in $Paths){
        $full=Get-TsfKernelFullPath $path
        $contained=Test-TsfKernelPathInside $full $root
        $length=$full.Length
        if(!$contained){$errors.Add("Runtime path escapes canonical root: $full")|Out-Null}
        if($length-gt$script:TsfRuntimeHardPathLimit){$errors.Add("Runtime path exceeds hard Windows budget ($script:TsfRuntimeHardPathLimit): $length :: $full")|Out-Null}
        $rows+=[pscustomobject]@{path=$full;length=$length;contained=$contained;within_hard_limit=($length-le$script:TsfRuntimeHardPathLimit);within_target=($length-le$script:TsfRuntimeTargetPathLimit)}
    }
    $max=if($rows.Count){($rows|Measure-Object -Property length -Maximum).Maximum}else{0}
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors);hard_limit=$script:TsfRuntimeHardPathLimit;target_limit=$script:TsfRuntimeTargetPathLimit;maximum_path_length=$max;target_met=($max-le$script:TsfRuntimeTargetPathLimit);paths=$rows}
}

function New-TsfRuntimeStoragePlan {
    param(
        [Parameter(Mandatory)][string]$RuntimeRoot,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [ValidateSet('preservation','adapter','queue_control','lifecycle_control')][string]$Layout='preservation',
        [switch]$TestOnlyAllowAlternateRoot
    )
    $root=if($TestOnlyAllowAlternateRoot){Get-TsfKernelFullPath $RuntimeRoot}else{Assert-TsfCanonicalRuntimeRoot $RuntimeRoot}
    $missionIdentity=Get-TsfRuntimeIdentity mission ([pscustomobject][ordered]@{mission_id=$MissionId;mission_revision=$MissionRevision})
    $runIdentity=Get-TsfRuntimeIdentity run ([pscustomobject][ordered]@{mission_identity_sha256=$missionIdentity.full_sha256;run_id=$RunId})
    $prefix=switch($Layout){'preservation'{'p'}'adapter'{'a'}'queue_control'{'q'}'lifecycle_control'{'l'}}
    $directory=Join-Path (Join-Path (Join-Path $root $prefix) $missionIdentity.short_key) $runIdentity.short_key
    $staging=Join-Path (Join-Path (Join-Path $root 'x') $missionIdentity.short_key) $runIdentity.short_key
    $artifacts=[ordered]@{};$stagingArtifacts=[ordered]@{}
    foreach($entry in $script:TsfRuntimeArtifacts.GetEnumerator()){$artifacts[$entry.Key]=Join-Path $directory $entry.Value;$stagingArtifacts[$entry.Key]=Join-Path $staging $entry.Value}
    $receiptRoot=Join-Path $directory 'r'
    $receiptIdentity=Get-TsfRuntimeIdentity receipt ([pscustomobject][ordered]@{mission_identity_sha256=$missionIdentity.full_sha256;run_identity_sha256=$runIdentity.full_sha256})
    $receiptPaths=[ordered]@{admission=Join-Path $receiptRoot "a-$($receiptIdentity.short_key).json";transaction=Join-Path $receiptRoot "t-$($receiptIdentity.short_key).json";admission_temp=Join-Path $receiptRoot "x-$($receiptIdentity.short_key).tmp";transaction_temp=Join-Path $receiptRoot "y-$($receiptIdentity.short_key).tmp";transaction_backup=Join-Path $receiptRoot "z-$($receiptIdentity.short_key).tmp"}
    $all=@($artifacts.GetEnumerator()|ForEach-Object{$_.Value})+@($stagingArtifacts.GetEnumerator()|ForEach-Object{$_.Value})+@($receiptPaths.GetEnumerator()|ForEach-Object{$_.Value})
    $budget=Test-TsfRuntimePathPlan $root $all
    [pscustomobject]@{schema_version='tsf_runtime_storage_plan_v1';runtime_root=$root;layout=$Layout;mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;mission_identity=$missionIdentity;run_identity=$runIdentity;receipt_identity=$receiptIdentity;directory=$directory;staging_directory=$staging;artifacts=[pscustomobject]$artifacts;staging_artifacts=[pscustomobject]$stagingArtifacts;receipt_root=$receiptRoot;receipt_paths=[pscustomobject]$receiptPaths;budget=$budget}
}

function New-TsfRuntimeStorageManifest {
    param(
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][string]$MissionContentHash,
        [Parameter(Mandatory)][string]$PolicyFingerprint,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory)][string]$Worktree,
        [Parameter(Mandatory)][string]$TranslatorVersion,
        [Parameter(Mandatory)][string]$AdapterVersion,
        [object[]]$Artifacts=@(),
        [datetimeoffset]$CreatedAt=[datetimeoffset]::UtcNow
    )
    [pscustomobject][ordered]@{
        schema_version=$script:TsfRuntimeManifestVersion
        created_at=$CreatedAt.ToUniversalTime().ToString('o')
        mission_id=[string]$Plan.mission_id
        mission_revision=[int]$Plan.mission_revision
        run_id=[string]$Plan.run_id
        mission_content_hash=$MissionContentHash
        policy_fingerprint=$PolicyFingerprint
        repository=$Repository
        branch=$Branch
        worktree=$Worktree
        translator_version=$TranslatorVersion
        adapter_version=$AdapterVersion
        mission_identity_sha256=[string]$Plan.mission_identity.full_sha256
        mission_key=[string]$Plan.mission_identity.short_key
        run_identity_sha256=[string]$Plan.run_identity.full_sha256
        run_key=[string]$Plan.run_identity.short_key
        artifacts=@($Artifacts)
    }
}

function New-TsfRuntimeArtifactRecord {
    param(
        [Parameter(Mandatory)][string]$LogicalType,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$PacketDirectory,
        [Parameter(Mandatory)][string]$EvidenceClassification,
        [Parameter(Mandatory)][string]$Producer,
        [datetimeoffset]$CreatedAt=[datetimeoffset]::UtcNow
    )
    $full=Get-TsfKernelFullPath $Path;$dir=Get-TsfKernelFullPath $PacketDirectory
    if(!(Test-TsfKernelPathInside $full $dir)-or!(Test-Path -LiteralPath $full -PathType Leaf)){throw "Runtime artifact is missing or outside packet: $full"}
    $relative=[IO.Path]::GetFileName($full)
    if($relative-notmatch'^[A-Za-z0-9._-]+$'){throw "Runtime artifact filename is not compact and fixed: $relative"}
    [pscustomobject][ordered]@{
        logical_type=$LogicalType
        path=$relative
        sha256=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        size=[long](Get-Item -LiteralPath $full).Length
        evidence_classification=$EvidenceClassification
        producer=$Producer
        created_at=$CreatedAt.ToUniversalTime().ToString('o')
    }
}

function Write-TsfRuntimeStorageManifest {
    param([Parameter(Mandatory)][object]$Manifest,[Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$PacketDirectory)
    $schema=Join-Path (Get-TsfKernelRoot) 'fleet\control\runtime-artifact-manifest.schema.v1.json'
    $validation=Test-TsfJsonContract $Manifest $schema
    if(!$validation.valid){throw "Runtime manifest violates schema: $($validation.errors -join '; ')"}
    Write-TsfKernelJson $Manifest $Path
    $observed=Read-TsfKernelJson $Path
    $integrity=Test-TsfRuntimeStorageManifest $observed $PacketDirectory ([string]$Manifest.mission_id) ([int]$Manifest.mission_revision) ([string]$Manifest.run_id)
    if(!$integrity.valid){throw "Runtime manifest failed post-write verification: $($integrity.errors -join '; ')"}
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-TsfRuntimeStorageManifest {
    param([Parameter(Mandatory)][object]$Manifest,[Parameter(Mandatory)][string]$PacketDirectory,[string]$ExpectedMissionId='',[int]$ExpectedMissionRevision=0,[string]$ExpectedRunId='')
    $errors=[Collections.Generic.List[string]]::new();$dir=Get-TsfKernelFullPath $PacketDirectory
    if([string]$Manifest.schema_version-ne$script:TsfRuntimeManifestVersion){$errors.Add('Unsupported runtime artifact manifest version.')|Out-Null}
    $missionIdentity=Get-TsfRuntimeIdentity mission ([pscustomobject][ordered]@{mission_id=[string]$Manifest.mission_id;mission_revision=[int]$Manifest.mission_revision})
    $runIdentity=Get-TsfRuntimeIdentity run ([pscustomobject][ordered]@{mission_identity_sha256=$missionIdentity.full_sha256;run_id=[string]$Manifest.run_id})
    if([string]$Manifest.mission_identity_sha256-ne$missionIdentity.full_sha256-or[string]$Manifest.mission_key-ne$missionIdentity.short_key){$errors.Add('Runtime manifest mission-key collision or identity mismatch.')|Out-Null}
    if([string]$Manifest.run_identity_sha256-ne$runIdentity.full_sha256-or[string]$Manifest.run_key-ne$runIdentity.short_key){$errors.Add('Runtime manifest run-key collision or identity mismatch.')|Out-Null}
    if((Split-Path -Leaf $dir)-ne$runIdentity.short_key-or(Split-Path -Leaf (Split-Path -Parent $dir))-ne$missionIdentity.short_key-or(Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $dir)))-notin@('p','x')){$errors.Add('Runtime manifest directory keys do not match full identities.')|Out-Null}
    if($ExpectedMissionId-and[string]$Manifest.mission_id-ne$ExpectedMissionId){$errors.Add('Runtime manifest mission binding mismatch.')|Out-Null}
    if($ExpectedMissionRevision-and[int]$Manifest.mission_revision-ne$ExpectedMissionRevision){$errors.Add('Runtime manifest revision binding mismatch.')|Out-Null}
    if($ExpectedRunId-and[string]$Manifest.run_id-ne$ExpectedRunId){$errors.Add('Runtime manifest run binding mismatch.')|Out-Null}
    foreach($artifact in @($Manifest.artifacts)){
        if([IO.Path]::IsPathRooted([string]$artifact.path)-or[string]$artifact.path-match'(^|[\\/])\.\.([\\/]|$)'){$errors.Add("Unsafe runtime artifact manifest path: $($artifact.path)")|Out-Null;continue}
        $path=Get-TsfKernelFullPath ([string]$artifact.path) $dir
        if(!(Test-TsfKernelPathInside $path $dir)-or!(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("Runtime artifact missing or outside packet: $($artifact.path)")|Out-Null;continue}
        $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();$size=(Get-Item -LiteralPath $path).Length
        if($hash-ne[string]$artifact.sha256-or$size-ne[long]$artifact.size){$errors.Add("Runtime artifact hash/size mismatch: $($artifact.path)")|Out-Null}
    }
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors);mission_identity=$missionIdentity;run_identity=$runIdentity}
}

function Get-TsfManifestBoundArtifact {
    param(
        [Parameter(Mandatory)][object]$Descriptor,
        [Parameter(Mandatory)][string]$LogicalType,
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$ExpectedProducer,
        [Parameter(Mandatory)][string[]]$AllowedEvidenceClassifications
    )
    if([string]$Descriptor.layout-ne'COMPACT_V1'){throw 'LEGACY_PACKET_WRITE_PROHIBITED'}
    $records=@($Descriptor.manifest.artifacts|Where-Object{[string]$_.logical_type-eq$LogicalType})
    if($records.Count-ne1){throw "MANIFEST_ARTIFACT_MISSING_OR_AMBIGUOUS: $LogicalType"}
    $record=$records[0]
    if([string]$record.path-ne$ExpectedPath){throw "MANIFEST_ARTIFACT_PATH_MISMATCH: $LogicalType"}
    if([string]$record.producer-ne$ExpectedProducer){throw "MANIFEST_ARTIFACT_PRODUCER_MISMATCH: $LogicalType"}
    if($AllowedEvidenceClassifications-notcontains[string]$record.evidence_classification){throw "MANIFEST_ARTIFACT_EVIDENCE_CLASS_MISMATCH: $LogicalType"}
    $path=Get-TsfKernelFullPath ([string]$record.path) ([string]$Descriptor.packet_directory)
    if(!(Test-TsfKernelPathInside $path ([string]$Descriptor.packet_directory))-or!(Test-Path -LiteralPath $path -PathType Leaf)){throw "MANIFEST_ARTIFACT_OUTSIDE_PACKET: $LogicalType"}
    $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if($hash-ne[string]$record.sha256){throw "MANIFEST_ARTIFACT_HASH_MISMATCH: $LogicalType"}
    [pscustomobject]@{record=$record;path=$path;sha256=$hash}
}

function Get-TsfPreservationPacketDescriptor {
    param([Parameter(Mandatory)][string]$PacketPath,[string]$ExpectedMissionId='',[int]$ExpectedMissionRevision=0)
    $path=Get-TsfKernelFullPath $PacketPath;$leaf=Split-Path -Leaf $path
    if($leaf-eq'pp.json'){
        $dir=Split-Path -Parent $path;$manifestPath=Join-Path $dir $script:TsfRuntimeArtifacts.manifest
        if(!(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Compact preservation packet is missing manifest.json.'}
        $manifest=Read-TsfKernelJson $manifestPath;$validation=Test-TsfRuntimeStorageManifest $manifest $dir $ExpectedMissionId $ExpectedMissionRevision
        if(!$validation.valid){throw "Compact preservation manifest failed validation: $($validation.errors -join '; ')"}
        return [pscustomobject]@{layout='COMPACT_V1';packet_path=$path;packet_directory=$dir;manifest_path=$manifestPath;manifest=$manifest;preservation_store=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $dir))}
    }
    if($leaf-eq'preservation_packet.json'){
        $packet=Read-TsfKernelJson $path;if($ExpectedMissionId-and[string]$packet.mission_id-ne$ExpectedMissionId){throw 'Legacy preservation mission binding mismatch.'}
        return [pscustomobject]@{layout='LEGACY_READ_ONLY';packet_path=$path;packet_directory=Split-Path -Parent $path;manifest_path='';manifest=$null;preservation_store=Split-Path -Parent (Split-Path -Parent $path)}
    }
    throw 'Unknown preservation packet layout.'
}

function Get-TsfRuntimeReceiptPlan {
    param([Parameter(Mandatory)][object]$Result,[Parameter(Mandatory)][string]$ResultHash,[Parameter(Mandatory)][string]$PreservationPacketPath,[Parameter(Mandatory)][string]$PreservationHash)
    $descriptor=Get-TsfPreservationPacketDescriptor -PacketPath $PreservationPacketPath -ExpectedMissionId ([string]$Result.mission_id) -ExpectedMissionRevision ([int]$Result.mission_revision)
    if($descriptor.layout-eq'COMPACT_V1'){
        if([string]$descriptor.manifest.policy_fingerprint-ne[string]$Result.policy_fingerprint){throw 'Compact preservation policy binding mismatch.'}
        if([string]$descriptor.manifest.run_id-ne[string]$Result.result_id){throw 'Compact preservation run/result binding mismatch.'}
        $durable=@($descriptor.manifest.artifacts|Where-Object{[string]$_.logical_type-eq'durable_result'})
        $durableResultBound=($durable.Count-eq1-and[string]$durable[0].sha256-eq$ResultHash)
        $root=Join-Path $descriptor.packet_directory 'r';$containmentRoot=$descriptor.preservation_store
    }else{
        throw 'LEGACY_PACKET_WRITE_PROHIBITED'
    }
    $identity=[pscustomobject][ordered]@{mission_id=[string]$Result.mission_id;mission_revision=[int]$Result.mission_revision;result_id=[string]$Result.result_id;policy_fingerprint=[string]$Result.policy_fingerprint;preservation_packet_sha256=$PreservationHash}
    $identitySha256=Get-TsfContractJsonHash $identity;$key=ConvertTo-TsfRuntimeShortKey $identitySha256
    $conflictIdentitySha256=Get-TsfRuntimeSha256Text "$identitySha256|$ResultHash";$conflictKey=ConvertTo-TsfRuntimeShortKey $conflictIdentitySha256
    $paths=[ordered]@{root=$root;key=$key;identity_sha256=$identitySha256;conflict_identity_sha256=$conflictIdentitySha256;admission=Join-Path $root "a-$key.json";transaction=Join-Path $root "t-$key.json";admission_temp=Join-Path $root "x-$key.tmp";transaction_temp=Join-Path $root "y-$key.tmp";transaction_backup=Join-Path $root "z-$key.tmp";conflict=Join-Path $root "c-$conflictKey.json";packet_descriptor=$descriptor;durable_result_bound=$durableResultBound}
    $budget=Test-TsfRuntimePathPlan -RuntimeRoot $containmentRoot -Paths @($paths.admission,$paths.transaction,$paths.admission_temp,$paths.transaction_temp,$paths.transaction_backup,$paths.conflict)
    if(!$budget.valid){throw "Canonical receipt path preflight failed: $($budget.errors -join '; ')"}
    $paths['budget']=$budget
    [pscustomobject]$paths
}

function Add-TsfRuntimeDurableResult {
    param([Parameter(Mandatory)][object]$Value,[Parameter(Mandatory)][string]$PreservationPacketPath)
    $descriptor=Get-TsfPreservationPacketDescriptor $PreservationPacketPath
    if($descriptor.layout-ne'COMPACT_V1'){throw 'New durable results may only be added to compact V1 preservation packets.'}
    $dir=[string]$descriptor.packet_directory;$plan=New-TsfRuntimeStoragePlan -RuntimeRoot ([string]$descriptor.preservation_store) -MissionId ([string]$descriptor.manifest.mission_id) -MissionRevision ([int]$descriptor.manifest.mission_revision) -RunId ([string]$descriptor.manifest.run_id) -Layout preservation
    $expectedHash=Get-TsfContractJsonHash $Value
    if(Test-Path -LiteralPath $plan.artifacts.durable_result){
        $existing=Read-TsfKernelJson $plan.artifacts.durable_result
        if((Get-TsfContractJsonHash $existing)-ne$expectedHash){throw 'Immutable compact durable-result artifact already exists with different content.'}
        return [pscustomobject]@{path=[string]$plan.artifacts.durable_result;sha256=(Get-FileHash $plan.artifacts.durable_result -Algorithm SHA256).Hash.ToLowerInvariant();idempotent_replay=$true}
    }
    Write-TsfKernelJson $Value $plan.artifacts.durable_temp
    $parsed=Read-TsfKernelJson $plan.artifacts.durable_temp
    if((Get-TsfContractJsonHash $parsed)-ne$expectedHash){throw 'Staged compact durable result failed parse/hash verification.'}
    Move-Item -LiteralPath $plan.artifacts.durable_temp -Destination $plan.artifacts.durable_result
    $record=New-TsfRuntimeArtifactRecord -LogicalType 'durable_result' -Path $plan.artifacts.durable_result -PacketDirectory $dir -EvidenceClassification 'KERNEL_OBSERVED' -Producer 'durable_result_mapper'
    $manifest=$descriptor.manifest
    $manifest.artifacts=@($manifest.artifacts|Where-Object{[string]$_.logical_type-ne'durable_result'})+@($record)
    $validation=Test-TsfJsonContract $manifest (Join-Path (Get-TsfKernelRoot) 'fleet\control\runtime-artifact-manifest.schema.v1.json')
    if(!$validation.valid){throw "Updated runtime manifest violates schema: $($validation.errors -join '; ')"}
    Write-TsfKernelJson $manifest $plan.artifacts.manifest_temp
    $temp=Read-TsfKernelJson $plan.artifacts.manifest_temp;$integrity=Test-TsfRuntimeStorageManifest $temp $dir ([string]$manifest.mission_id) ([int]$manifest.mission_revision) ([string]$manifest.run_id)
    if(!$integrity.valid){throw "Updated runtime manifest failed verification: $($integrity.errors -join '; ')"}
    [IO.File]::Replace([string]$plan.artifacts.manifest_temp,[string]$plan.artifacts.manifest,[string]$plan.artifacts.manifest_backup)
    if(Test-Path -LiteralPath $plan.artifacts.manifest_backup){Remove-Item -LiteralPath $plan.artifacts.manifest_backup -Force}
    [pscustomobject]@{path=[string]$plan.artifacts.durable_result;sha256=(Get-FileHash $plan.artifacts.durable_result -Algorithm SHA256).Hash.ToLowerInvariant();idempotent_replay=$false}
}
