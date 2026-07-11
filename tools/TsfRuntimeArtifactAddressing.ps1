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
    producer_registry='pr.json'
    producer_registry_temp='px.tmp'
    transition_01='t01.json'
    transition_02='t02.json'
    transition_03='t03.json'
    transition_04='t04.json'
    transition_05='t05.json'
    transition_06='t06.json'
    transition_07='t07.json'
    transition_08='t08.json'
    transition_temp='tt.tmp'
    transition_backup='tb.tmp'
    recovery_marker='rc.json'
    registry_mission='gm.json'
    context_update='cc.json'
}

$script:TsfProducerEvidenceContract=[ordered]@{
    mission=[pscustomobject]@{layout='lifecycle_control';artifact='mission';producer='canonical_mission_translator';classification='KERNEL_OBSERVED'}
    queue_document=[pscustomobject]@{layout='queue_control';artifact='queue_document';producer='canonical_queue_executor';classification='KERNEL_OBSERVED'}
    preflight=[pscustomobject]@{layout='lifecycle_control';artifact='preflight';producer='enforcement_kernel';classification='KERNEL_OBSERVED'}
    role_preflight=[pscustomobject]@{layout='lifecycle_control';artifact='role_preflight';producer='role_permission_preflight';classification='KERNEL_OBSERVED'}
    worker_instruction=[pscustomobject]@{layout='lifecycle_control';artifact='worker_instruction';producer='enforcement_kernel';classification='KERNEL_OBSERVED'}
    worker_result=[pscustomobject]@{layout='lifecycle_control';artifact='worker_result';producer='mission_lifecycle';classification='KERNEL_OBSERVED'}
    adapter_result=[pscustomobject]@{layout='adapter';artifact='adapter_result';producer='codex_app_server_adapter';classification='ADAPTER_OBSERVED'}
    event_journal=[pscustomobject]@{layout='adapter';artifact='event_journal';producer='codex_app_server_adapter';classification='NATIVE_OBSERVED'}
    usage=[pscustomobject]@{layout='lifecycle_control';artifact='usage';producer='codex_app_server_adapter';classification='NATIVE_OBSERVED'}
    verifier_result=[pscustomobject]@{layout='lifecycle_control';artifact='verifier_result';producer='enforcement_kernel_verifier';classification='VERIFIER_OBSERVED'}
    prompt=[pscustomobject]@{layout='adapter';artifact='prompt';producer='mission_lifecycle';classification='KERNEL_OBSERVED'}
    stderr=[pscustomobject]@{layout='adapter';artifact='stderr';producer='codex_app_server_diagnostic';classification='UNVERIFIED'}
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

function Get-TsfCanonicalProductionQueueRoot {
    $repo=Get-TsfKernelFullPath (Get-TsfKernelRoot)
    $policyPath=Join-Path $repo 'fleet\control\mission-queue-state-policy.v1.json'
    $policy=Read-TsfKernelJson $policyPath
    if([string]$policy.schema_version-ne'mission_queue_state_policy_v1'-or[string]::IsNullOrWhiteSpace([string]$policy.queue_root)){throw 'CANONICAL_QUEUE_POLICY_INVALID'}
    $root=Get-TsfKernelFullPath ([string]$policy.queue_root) $repo
    if(!(Test-TsfKernelPathInside $root $repo)-or!(Test-TsfKernelReparseContained $root $repo)){throw 'CANONICAL_QUEUE_ROOT_CONTAINMENT_FAILED'}
    $root
}

function Resolve-TsfQueueAuthority {
    param([string]$QueueRoot,[switch]$TestOnlyAllowAlternateQueueRoot)
    $repo=Get-TsfKernelFullPath (Get-TsfKernelRoot);$production=Get-TsfCanonicalProductionQueueRoot
    $actual=if([string]::IsNullOrWhiteSpace($QueueRoot)){$production}else{Get-TsfKernelFullPath $QueueRoot $repo}
    $kind='PRODUCTION'
    if(![string]::Equals($actual,$production,[StringComparison]::OrdinalIgnoreCase)){
        if(!$TestOnlyAllowAlternateQueueRoot){throw "NONCANONICAL_QUEUE_ROOT_REJECTED: $actual"}
        $fixtureRoot=Get-TsfKernelFullPath (Join-Path $repo '.codex-local\fixtures')
        $runtimeRoot=Get-TsfCanonicalRuntimeRoot
        if((!(Test-TsfKernelPathInside $actual $fixtureRoot))-and(!(Test-TsfKernelPathInside $actual $runtimeRoot))){throw 'TEST_QUEUE_ROOT_NOT_ISOLATED'}
        if(!(Test-TsfKernelReparseContained $actual $repo)){throw 'TEST_QUEUE_ROOT_NOT_ISOLATED'}
        $kind='TEST_ONLY'
    }
    $policyHash=(Get-FileHash (Join-Path $repo 'fleet\control\mission-queue-state-policy.v1.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $identity=Get-TsfRuntimeSha256Text "$kind|$actual|$policyHash"
    [pscustomobject]@{schema_version='tsf_queue_authority_v1';kind=$kind;root=$actual;policy_sha256=$policyHash;identity_sha256=$identity;production_root=$production}
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
    param([Parameter(Mandatory)][string]$RuntimeRoot,[Parameter(Mandatory)][object[]]$Paths)
    $root=Get-TsfKernelFullPath $RuntimeRoot
    $rows=@();$errors=[Collections.Generic.List[string]]::new()
    foreach($item in $Paths){
        $path=if($item-is[string]){$item}else{[string]$item.path}
        $logicalType=if($item-is[string]){'unspecified'}else{[string]$item.logical_type}
        $full=Get-TsfKernelFullPath $path
        $contained=(Test-TsfKernelPathInside $full $root)-and(Test-TsfKernelReparseContained $full (Get-TsfKernelRoot))
        $length=$full.Length
        if(!$contained){$errors.Add("Runtime path escapes canonical root: $full")|Out-Null}
        if($length-gt$script:TsfRuntimeHardPathLimit){$errors.Add("Runtime path exceeds hard Windows budget ($script:TsfRuntimeHardPathLimit): $length :: $full")|Out-Null}
        $rows+=[pscustomobject]@{logical_type=$logicalType;path=$full;length=$length;contained=$contained;within_hard_limit=($length-le$script:TsfRuntimeHardPathLimit);within_target=($length-le$script:TsfRuntimeTargetPathLimit)}
    }
    $max=if($rows.Count){($rows|Measure-Object -Property length -Maximum).Maximum}else{0}
    $maximumRow=@($rows|Where-Object{$_.length-eq$max}|Select-Object -First 1)
    [pscustomobject]@{valid=$errors.Count-eq0-and$max-le$script:TsfRuntimeTargetPathLimit;errors=@($errors);hard_limit=$script:TsfRuntimeHardPathLimit;target_limit=$script:TsfRuntimeTargetPathLimit;maximum_path_length=$max;maximum_logical_type=if($maximumRow.Count){[string]$maximumRow[0].logical_type}else{''};target_met=($max-le$script:TsfRuntimeTargetPathLimit);paths=$rows}
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

function New-TsfCompleteRuntimePathPlan {
    param(
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId
    )
    $root=Assert-TsfCanonicalRuntimeRoot (Get-TsfCanonicalRuntimeRoot)
    $q=New-TsfRuntimeStoragePlan $root $MissionId $MissionRevision $RunId -Layout queue_control
    $l=New-TsfRuntimeStoragePlan $root $MissionId $MissionRevision $RunId -Layout lifecycle_control
    $a=New-TsfRuntimeStoragePlan $root $MissionId $MissionRevision $RunId -Layout adapter
    $p=New-TsfRuntimeStoragePlan $root $MissionId $MissionRevision $RunId -Layout preservation
    $rows=[Collections.Generic.List[object]]::new()
    function Add-PlanPath([string]$Type,[string]$Path){$rows.Add([pscustomobject]@{logical_type=$Type;path=$Path})|Out-Null}
    foreach($name in @('queue_document','queue_result','runtime_evidence','approval_ledger','preflight','role_preflight','worker_instruction','worker_result','verifier_result','context_update','transition_01','transition_02','transition_03','transition_04','transition_05','transition_06','transition_07','transition_08','transition_temp','transition_backup','recovery_marker')){Add-PlanPath "queue.$name" ([string]$q.artifacts.$name)}
    $registryMissionPath=Join-Path (Join-Path $q.directory 'g') $script:TsfRuntimeArtifacts.registry_mission
    Add-PlanPath 'queue.registry_mission' $registryMissionPath
    foreach($state in @('s1','s2','s3','s4','s5','s6')){Add-PlanPath "queue.kernel_state.$state" (Join-Path (Join-Path $q.directory 's') (Join-Path $state "k-$($q.mission_identity.short_key).json"))}
    foreach($name in @('lifecycle_result','mission','preflight','role_preflight','worker_instruction','worker_result','usage','verifier_result','producer_registry','producer_registry_temp')){Add-PlanPath "lifecycle.$name" ([string]$l.artifacts.$name)}
    foreach($state in @('s1','s2','s3','s4','s5','s6')){Add-PlanPath "kernel_state.$state" (Join-Path (Join-Path $l.directory 's') (Join-Path $state "k-$($l.mission_identity.short_key).json"))}
    foreach($name in @('adapter_result','event_journal','stderr','prompt')){Add-PlanPath "adapter.$name" ([string]$a.artifacts.$name)}
    foreach($name in @('manifest','manifest_temp','manifest_backup','mission','queue_document','preflight','role_preflight','worker_instruction','worker_result','adapter_result','event_journal','usage','verifier_result','prompt','stderr','producer_registry','preservation_packet','durable_result','durable_temp')){Add-PlanPath "preservation.$name" ([string]$p.artifacts.$name);Add-PlanPath "staging.$name" ([string]$p.staging_artifacts.$name)}
    foreach($name in @('admission','transaction','admission_temp','transaction_temp','transaction_backup')){Add-PlanPath "receipt.$name" ([string]$p.receipt_paths.$name)}
    $templateKey='a234567a234567a234567a234567a2345'
    foreach($entry in @(
        @{type='receipt.conflict';leaf="c-$templateKey.json"},
        @{type='receipt.recovery';leaf="r-$templateKey.json"}
    )){Add-PlanPath $entry.type (Join-Path $p.receipt_root $entry.leaf)}
    $budget=Test-TsfRuntimePathPlan $root @($rows)
    $required=@('queue.preflight','queue.role_preflight','queue.worker_instruction','queue.worker_result','queue.verifier_result','queue.registry_mission','queue.kernel_state.s1','queue.transition_01','queue.transition_temp','queue.transition_backup','queue.recovery_marker','lifecycle.producer_registry','lifecycle.producer_registry_temp','preservation.manifest_temp','preservation.manifest_backup','receipt.admission','receipt.transaction','receipt.conflict','receipt.recovery')
    $missing=@($required|Where-Object{$candidate=$_;@($rows|Where-Object{$_.logical_type-eq$candidate}).Count-ne1})
    if($missing.Count){$budget.valid=$false;$budget.errors=@($budget.errors)+@("Complete path plan omits categories: $($missing -join ', ')")}
    [pscustomobject]@{schema_version='tsf_complete_runtime_path_plan_v1';created_before_mutation=$true;runtime_root=$root;mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;queue_plan=$q;lifecycle_plan=$l;adapter_plan=$a;preservation_plan=$p;registry_mission_path=$registryMissionPath;required_categories=$required;paths=@($rows);budget=$budget;maximum_path_length=$budget.maximum_path_length;maximum_logical_type=$budget.maximum_logical_type}
}

function Get-TsfProducerEvidenceContract { [pscustomobject]$script:TsfProducerEvidenceContract }

function New-TsfProducerEvidenceRegistry {
    param(
        [Parameter(Mandatory)][string]$RegistryPath,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$PolicyFingerprint,
        [Parameter(Mandatory)][string]$QueueDocumentSha256,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory)][string]$Worktree,
        [Parameter(Mandatory)][string]$OrchestratorInvocationIdentity,
        [string]$RunNonce=([guid]::NewGuid().ToString('N')),
        [switch]$TestOnly
    )
    $plan=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $MissionId $MissionRevision $RunId -Layout lifecycle_control
    if(![string]::Equals((Get-TsfKernelFullPath $RegistryPath),(Get-TsfKernelFullPath ([string]$plan.artifacts.producer_registry)),[StringComparison]::OrdinalIgnoreCase)){throw 'NONCANONICAL_PRODUCER_REGISTRY_PATH'}
    if($TestOnly-and!$OrchestratorInvocationIdentity.StartsWith('test-only-')){throw 'TEST_PRODUCER_REGISTRY_REQUIRES_EXPLICIT_TEST_INVOCATION'}
    if(Test-Path $RegistryPath -PathType Leaf){
        $existing=Read-TsfKernelJson $RegistryPath
        $repositoryFull=Get-TsfKernelFullPath $Repository;$worktreeFull=Get-TsfKernelFullPath $Worktree
        if([string]$existing.binding.mission_id-ne$MissionId-or[int]$existing.binding.mission_revision-ne$MissionRevision-or[string]$existing.binding.run_id-ne$RunId-or[string]$existing.binding.policy_fingerprint-ne$PolicyFingerprint-or[string]$existing.binding.queue_document_sha256-ne$QueueDocumentSha256-or![string]::Equals([string]$existing.binding.repository,$repositoryFull,[StringComparison]::OrdinalIgnoreCase)-or[string]$existing.binding.branch-ne$Branch-or![string]::Equals([string]$existing.binding.worktree,$worktreeFull,[StringComparison]::OrdinalIgnoreCase)-or[string]$existing.binding.orchestrator_invocation_identity-ne$OrchestratorInvocationIdentity-or[bool]$existing.test_only-ne[bool]$TestOnly){throw 'PRODUCER_EVIDENCE_REGISTRY_IMMUTABLE_CONFLICT'}
        return $existing
    }
    $binding=[pscustomobject][ordered]@{mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;policy_fingerprint=$PolicyFingerprint;queue_document_sha256=$QueueDocumentSha256;repository=Get-TsfKernelFullPath $Repository;branch=$Branch;worktree=Get-TsfKernelFullPath $Worktree;orchestrator_invocation_identity=$OrchestratorInvocationIdentity;run_nonce=$RunNonce}
    $registry=[pscustomobject][ordered]@{schema_version='tsf_producer_evidence_registry_v1';created_at=[datetimeoffset]::UtcNow.ToString('o');test_only=[bool]$TestOnly;binding=$binding;binding_identity_sha256=Get-TsfRuntimeSha256Text ($binding|ConvertTo-Json -Compress -Depth 20);next_sequence=1;artifacts=@()}
    Write-TsfKernelJson $registry $RegistryPath
    $registry
}

function Register-TsfProducerEvidence {
    param(
        [Parameter(Mandatory)][string]$RegistryPath,
        [Parameter(Mandatory)][ValidateSet('mission','queue_document','preflight','role_preflight','worker_instruction','worker_result','adapter_result','event_journal','usage','verifier_result','prompt','stderr')][string]$LogicalType,
        [Parameter(Mandatory)][string]$ArtifactPath,
        [Parameter(Mandatory)][string]$ProducerInvocationIdentity
    )
    $registry=Read-TsfKernelJson $RegistryPath
    if([string]$registry.schema_version-ne'tsf_producer_evidence_registry_v1'){throw 'INVALID_PRODUCER_EVIDENCE_REGISTRY'}
    $contract=$script:TsfProducerEvidenceContract[$LogicalType]
    $plan=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) ([string]$registry.binding.mission_id) ([int]$registry.binding.mission_revision) ([string]$registry.binding.run_id) -Layout ([string]$contract.layout)
    $expected=[string]$plan.artifacts.([string]$contract.artifact);$actual=Get-TsfKernelFullPath $ArtifactPath
    if(![string]::Equals($actual,(Get-TsfKernelFullPath $expected),[StringComparison]::OrdinalIgnoreCase)){throw "PRODUCER_EVIDENCE_PATH_MISMATCH: $LogicalType"}
    if(!(Test-Path -LiteralPath $actual -PathType Leaf)){throw "PRODUCER_EVIDENCE_MISSING: $LogicalType"}
    $runtimeRoot=(Get-TsfCanonicalRuntimeRoot).TrimEnd('\','/')
    if(!(Test-TsfKernelPathInside $actual $runtimeRoot)){throw "PRODUCER_EVIDENCE_OUTSIDE_CANONICAL_RUNTIME: $LogicalType"}
    $relative=$actual.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
    $existingRecord=@($registry.artifacts|Where-Object{[string]$_.logical_type-eq$LogicalType})
    if($existingRecord.Count){
        if($existingRecord.Count-eq1-and[string]$existingRecord[0].canonical_relative_path-eq$relative-and[string]$existingRecord[0].sha256-eq(Get-FileHash $actual -Algorithm SHA256).Hash.ToLowerInvariant()-and[long]$existingRecord[0].size-eq(Get-Item $actual).Length-and[string]$existingRecord[0].producer_invocation_identity-eq$ProducerInvocationIdentity){return $existingRecord[0]}
        throw "PRODUCER_EVIDENCE_CONFLICT: $LogicalType"
    }
    $record=[pscustomobject][ordered]@{logical_type=$LogicalType;canonical_relative_path=$relative;producer=[string]$contract.producer;evidence_classification=[string]$contract.classification;sha256=(Get-FileHash $actual -Algorithm SHA256).Hash.ToLowerInvariant();size=[long](Get-Item $actual).Length;created_at=[datetimeoffset]::UtcNow.ToString('o');creation_sequence=[int]$registry.next_sequence;producer_invocation_identity=$ProducerInvocationIdentity;binding_identity_sha256=[string]$registry.binding_identity_sha256}
    $registry.artifacts=@($registry.artifacts)+@($record);$registry.next_sequence=[int]$registry.next_sequence+1
    $temp=(New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) ([string]$registry.binding.mission_id) ([int]$registry.binding.mission_revision) ([string]$registry.binding.run_id) -Layout lifecycle_control).artifacts.producer_registry_temp
    Write-TsfKernelJson $registry $temp
    Move-Item -LiteralPath $temp -Destination $RegistryPath -Force
    $record
}

function Test-TsfProducerEvidenceRegistry {
    param(
        [Parameter(Mandatory)][string]$RegistryPath,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$PolicyFingerprint,
        [Parameter(Mandatory)][string]$QueueDocumentSha256,
        [switch]$AllowTestOnly
    )
    $registry=Read-TsfKernelJson $RegistryPath;$errors=[Collections.Generic.List[string]]::new()
    $schemaValidation=Test-TsfJsonContract $registry (Join-Path (Get-TsfKernelRoot) 'fleet\control\producer-evidence-registry.schema.v1.json')
    if(!$schemaValidation.valid){$errors.Add("Registry schema invalid: $($schemaValidation.errors -join '; ')")|Out-Null}
    if([string]$registry.schema_version-ne'tsf_producer_evidence_registry_v1'){$errors.Add('Registry schema mismatch.')|Out-Null}
    if([bool]$registry.test_only-and!$AllowTestOnly){$errors.Add('Test-only producer registry cannot enter normal preservation.')|Out-Null}
    $b=$registry.binding
    if([string]$b.mission_id-ne$MissionId-or[int]$b.mission_revision-ne$MissionRevision-or[string]$b.run_id-ne$RunId-or[string]$b.policy_fingerprint-ne$PolicyFingerprint-or[string]$b.queue_document_sha256-ne$QueueDocumentSha256){$errors.Add('Producer registry mission/run/policy/queue binding mismatch.')|Out-Null}
    if([string]$registry.binding_identity_sha256-ne(Get-TsfRuntimeSha256Text ($b|ConvertTo-Json -Compress -Depth 20))){$errors.Add('Producer registry binding identity mismatch.')|Out-Null}
    foreach($record in @($registry.artifacts)){
        $contract=$script:TsfProducerEvidenceContract[[string]$record.logical_type]
        if($null-eq$contract-or[string]$record.producer-ne[string]$contract.producer-or[string]$record.evidence_classification-ne[string]$contract.classification){$errors.Add("Producer contract mismatch: $($record.logical_type)")|Out-Null;continue}
        $path=Get-TsfKernelFullPath ([string]$record.canonical_relative_path) (Get-TsfCanonicalRuntimeRoot)
        if(!(Test-TsfKernelPathInside $path (Get-TsfCanonicalRuntimeRoot))-or!(Test-Path $path -PathType Leaf)){$errors.Add("Registered artifact missing/outside runtime: $($record.logical_type)")|Out-Null;continue}
        if((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()-ne[string]$record.sha256-or(Get-Item $path).Length-ne[long]$record.size){$errors.Add("Registered artifact bytes changed: $($record.logical_type)")|Out-Null}
    }
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors);registry=$registry}
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
