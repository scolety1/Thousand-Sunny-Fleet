$script:MissionSchemaVersion = "tsf_mission_envelope_v1"
$script:ResultSchemaVersion = "tsf_result_envelope_v1"
$script:AdmissionSchemaVersion = "tsf_admission_decision_v1"
$script:PolicyManifestVersion = "tsf_policy_manifest_v1"
$script:TranslatorVersion = "tsf_durable_to_operational_v1"
$script:ResultMapperVersion = "tsf_runtime_evidence_to_result_v1"
$script:EvidenceClasses = @("NATIVE_OBSERVED", "ADAPTER_OBSERVED", "KERNEL_OBSERVED", "FILESYSTEM_OBSERVED", "VERIFIER_OBSERVED", "AGENT_REPORTED", "UNVERIFIED")

function Test-TsfContractProperty { param([object]$Object,[string]$Name) $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name }
function ConvertTo-TsfContractArray { param([AllowNull()][object]$Value) if ($null -eq $Value) { return @() }; if ($Value -is [array]) { return @($Value) }; return @($Value) }
function Get-TsfContractJsonHash {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 100 -Compress
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-TsfTextHash { param([string]$Text) Get-TsfContractJsonHash -Value ([pscustomobject]@{ text = $Text }) }

function Test-TsfJsonType {
    param([AllowNull()][object]$Value,[string]$Type)
    switch ($Type) {
        "null" { return $null -eq $Value }
        "object" { return $null -ne $Value -and $Value -isnot [string] -and $Value -isnot [array] -and $Value.PSObject.Properties.Count -ge 0 }
        "array" { return $Value -is [array] }
        "string" { return $Value -is [string] }
        "boolean" { return $Value -is [bool] }
        "integer" { return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] }
        "number" { return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal] }
    }
    return $false
}

function Resolve-TsfSchemaRef {
    param([object]$Root,[string]$Reference)
    if ($Reference -notmatch '^#/(.+)$') { throw "Only local JSON Schema references are supported: $Reference" }
    $node = $Root
    foreach ($segment in ($Matches[1] -split '/')) {
        $name = $segment.Replace('~1','/').Replace('~0','~')
        if (!(Test-TsfContractProperty $node $name)) { throw "Unresolved JSON Schema reference: $Reference" }
        $node = $node.$name
    }
    return $node
}

function Test-TsfSchemaNode {
    param([AllowNull()][object]$Value,[object]$Schema,[object]$Root,[string]$Path,[Collections.Generic.List[string]]$Errors)
    if (Test-TsfContractProperty $Schema '$ref') { Test-TsfSchemaNode $Value (Resolve-TsfSchemaRef $Root ([string]$Schema.'$ref')) $Root $Path $Errors; return }
    if (Test-TsfContractProperty $Schema 'const') {
        $actual = $Value | ConvertTo-Json -Compress -Depth 20; $expected = $Schema.const | ConvertTo-Json -Compress -Depth 20
        if ($actual -cne $expected) { $Errors.Add("$Path must equal schema const.") | Out-Null; return }
    }
    if (Test-TsfContractProperty $Schema 'enum') {
        $match = @($Schema.enum | Where-Object { ($_ | ConvertTo-Json -Compress) -ceq ($Value | ConvertTo-Json -Compress) }).Count -gt 0
        if (!$match) { $Errors.Add("$Path is not an allowed enum value.") | Out-Null; return }
    }
    if (Test-TsfContractProperty $Schema 'type') {
        $types = @(ConvertTo-TsfContractArray $Schema.type)
        if (@($types | Where-Object { Test-TsfJsonType $Value ([string]$_) }).Count -eq 0) { $Errors.Add("$Path has the wrong type; expected $($types -join '|').") | Out-Null; return }
    }
    if ($null -eq $Value) { return }
    if ($Value -is [string]) {
        if ((Test-TsfContractProperty $Schema 'minLength') -and $Value.Length -lt [int]$Schema.minLength) { $Errors.Add("$Path is shorter than minLength.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maxLength') -and $Value.Length -gt [int]$Schema.maxLength) { $Errors.Add("$Path is longer than maxLength.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'pattern') -and $Value -cnotmatch [string]$Schema.pattern) { $Errors.Add("$Path does not match the required pattern.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'format') -and [string]$Schema.format -eq 'date-time') { $dt=[datetimeoffset]::MinValue; if (![datetimeoffset]::TryParse($Value,[ref]$dt)) { $Errors.Add("$Path is not a date-time.") | Out-Null } }
    }
    if (Test-TsfJsonType $Value 'number') {
        if ((Test-TsfContractProperty $Schema 'minimum') -and $Value -lt $Schema.minimum) { $Errors.Add("$Path is below minimum.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maximum') -and $Value -gt $Schema.maximum) { $Errors.Add("$Path is above maximum.") | Out-Null }
    }
    if ($Value -is [array]) {
        if ((Test-TsfContractProperty $Schema 'minItems') -and $Value.Count -lt [int]$Schema.minItems) { $Errors.Add("$Path has fewer than minItems.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'maxItems') -and $Value.Count -gt [int]$Schema.maxItems) { $Errors.Add("$Path has more than maxItems.") | Out-Null }
        if ((Test-TsfContractProperty $Schema 'uniqueItems') -and [bool]$Schema.uniqueItems) { $items=@($Value|ForEach-Object { $_|ConvertTo-Json -Compress -Depth 30 }); if (@($items|Select-Object -Unique).Count -ne $items.Count) { $Errors.Add("$Path contains duplicate items.") | Out-Null } }
        if (Test-TsfContractProperty $Schema 'items') { for($i=0;$i -lt $Value.Count;$i++){ Test-TsfSchemaNode $Value[$i] $Schema.items $Root "$Path[$i]" $Errors } }
    }
    if ((Test-TsfJsonType $Value 'object') -and (Test-TsfContractProperty $Schema 'properties')) {
        foreach($required in @(ConvertTo-TsfContractArray $Schema.required)){ if(!(Test-TsfContractProperty $Value ([string]$required))){$Errors.Add("$Path.$required is required.")|Out-Null} }
        $allowed=@($Schema.properties.PSObject.Properties.Name)
        if ((Test-TsfContractProperty $Schema 'additionalProperties') -and $Schema.additionalProperties -eq $false) { foreach($name in @($Value.PSObject.Properties.Name)){if($allowed -notcontains $name){$Errors.Add("$Path.$name is an additional property.")|Out-Null}} }
        foreach($property in $Schema.properties.PSObject.Properties){ if(Test-TsfContractProperty $Value $property.Name){ Test-TsfSchemaNode $Value.($property.Name) $property.Value $Root "$Path.$($property.Name)" $Errors } }
    }
}

function Test-TsfJsonContract {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Value,[Parameter(Mandatory)][string]$SchemaPath)
    $schema=Read-TsfKernelJson $SchemaPath; $errors=[Collections.Generic.List[string]]::new(); Test-TsfSchemaNode $Value $schema $schema '$' $errors
    [pscustomobject]@{ valid=$errors.Count -eq 0; errors=@($errors); coverage='required,type,nested,array,enum,const,min/max,pattern,additionalProperties,nullability,uniqueItems,date-time,local-$ref' }
}
function Test-TsfMissionEnvelope { [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\mission-envelope.schema.v1.json')) $r=Test-TsfJsonContract $Mission $SchemaPath; [pscustomobject]@{schema_version='tsf_mission_envelope_validation_v1';valid=$r.valid;errors=$r.errors;coverage=$r.coverage} }
function Test-TsfResultEnvelope { [CmdletBinding()] param([Parameter(Mandatory)][object]$Result,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\result-envelope.schema.v1.json')) $r=Test-TsfJsonContract $Result $SchemaPath; [pscustomobject]@{schema_version='tsf_result_envelope_validation_v1';valid=$r.valid;errors=$r.errors;coverage=$r.coverage} }

function Invoke-TsfContractGit { param([string]$Root,[string[]]$Arguments) $safe=$Root.Replace('\','/'); $output=@(& git -c "safe.directory=$safe" -C $Root @Arguments 2>&1); if($LASTEXITCODE -ne 0){throw "git $($Arguments -join ' ') failed: $($output -join ' ')"}; return @($output) }

function Get-TsfPolicyFingerprint {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ManifestPath,[string]$RepositoryRoot=$script:TsfRoot,[switch]$UnsupportedDevelopmentMode)
    $root=(Invoke-TsfContractGit $RepositoryRoot @('rev-parse','--show-toplevel')|Select-Object -First 1).Trim(); $head=(Invoke-TsfContractGit $root @('rev-parse','HEAD^{commit}')|Select-Object -First 1).Trim()
    $manifestFull=Get-TsfKernelFullPath $ManifestPath $root; if(!(Test-TsfKernelPathInside $manifestFull $root)){throw 'Policy manifest escapes repository.'}
    $manifest=Read-TsfKernelJson $manifestFull; if([string]$manifest.schema_version -ne $script:PolicyManifestVersion){throw 'Unsupported policy manifest version.'}
    $required=@('tools/TsfDurableContract.psm1','tools/TsfDurableContract.Canonical.ps1','tools/codex-fleet-enforcement-kernel.ps1','tools/Move-TsfMissionState.ps1','fleet/control/mission-envelope.schema.v1.json','fleet/control/result-envelope.schema.v1.json','fleet/control/admission-decision.schema.v1.json','fleet/control/model-routing-alias-policy.v1.json','fleet/control/worker-role-registry.v1.json','fleet/control/worker-permission-profiles.v1.json','fleet/control/mission-queue-state-policy.v1.json','fleet/control/role-aware-mission-extension.v1.json','fleet/control/worker-instruction-packet.schema.v1.json','docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/mission_schema_v1.json','docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/approval_ledger_schema_v1.json')
    $declared=@($manifest.governing_files|ForEach-Object{([string]$_).Replace('\','/')}); $missing=@($required|Where-Object{$declared -notcontains $_}); if($missing.Count){throw "Policy manifest omits executable governing sources: $($missing -join ', ')"}
    $manifestRel=($manifestFull.Substring($root.Length).TrimStart('\','/')).Replace('\','/'); $all=@($manifestRel)+$declared; $dirty=@(Invoke-TsfContractGit $root (@('status','--porcelain','--')+$all)); $dirty=@($dirty|Where-Object{![string]::IsNullOrWhiteSpace($_)})
    if($dirty.Count -and !$UnsupportedDevelopmentMode){throw 'Governing policy state is dirty; fingerprint requires committed clean HEAD.'}
    $entries=[Collections.Generic.List[object]]::new(); foreach($path in $all){if([IO.Path]::IsPathRooted($path)-or $path -match '(^|/)\.\.(/|$)'){throw "Unsafe policy path: $path"}; if($UnsupportedDevelopmentMode -and $dirty.Count){$text=Get-Content -LiteralPath (Join-Path $root $path) -Raw}else{$text=(Invoke-TsfContractGit $root @('show',"$head`:$path"))-join "`n"}; $entries.Add([pscustomobject]@{path=$path;sha256=Get-TsfTextHash $text})|Out-Null}
    $source=if($dirty.Count){'WORKING_TREE_UNSUPPORTED_DEVELOPMENT'}else{'VERIFIED_COMMIT_BLOBS'}; $canonical=[ordered]@{manifest_version=[string]$manifest.schema_version;policy_commit=$head;content_source=$source;schema_versions=$manifest.schema_versions;files=@($entries)}
    [pscustomobject]@{schema_version='tsf_policy_fingerprint_v1';policy_manifest_version=[string]$manifest.schema_version;policy_commit=$head;fingerprint=Get-TsfContractJsonHash ([pscustomobject]$canonical);governing_file_count=$entries.Count;governing_files=@($entries);schema_versions=$manifest.schema_versions;content_source=$source;development_mode=[bool]($dirty.Count);contains_secrets=$false}
}

function Resolve-TsfModelRouting {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Alias,[Parameter(Mandatory)][string]$Surface,[string]$PolicyPath=(Join-Path $script:TsfRoot 'fleet\control\model-routing-alias-policy.v1.json'))
    $policy=Read-TsfKernelJson $PolicyPath; $requested=$Alias; $legacy=$false
    if(Test-TsfContractProperty $policy.legacy_alias_map $Alias){$Alias=[string]$policy.legacy_alias_map.$Alias;$legacy=$true}
    if(!(Test-TsfContractProperty $policy.aliases $Alias)){throw "Unresolved model alias: $requested"}; if(!(Test-TsfContractProperty $policy.surface_resolutions $Surface)){throw "Unsupported model surface: $Surface"}
    $surfacePolicy=$policy.surface_resolutions.$Surface; if(!(Test-TsfContractProperty $surfacePolicy $Alias)){throw "Alias $Alias has no $Surface resolution."}
    [pscustomobject]@{requested_alias=$requested;stable_alias=$Alias;legacy_compatibility_input=$legacy;resolved_model=[string]$surfacePolicy.$Alias;reasoning_effort=[string]$policy.aliases.$Alias.default_reasoning_effort;assurance='RECOMMENDED_ONLY'}
}

function Resolve-TsfDurableRepository {
    param([object]$Mission,[string]$Root)
    $values=@($Mission.repository_allowlist); if($values.Count -ne 1){throw 'Durable-to-operational translation requires exactly one repository.'}; $value=[string]$values[0]
    if($value -eq 'TSF_CONTROL_PLANE'){return Get-TsfKernelFullPath $Root}; if(![IO.Path]::IsPathRooted($value)){throw "Repository identity is not an absolute canonical path: $value"}; return Get-TsfKernelFullPath $value
}
function ConvertTo-TsfOperationalForbiddenActions {
    param([object[]]$Actions)
    $mapped = [Collections.Generic.List[string]]::new()
    foreach ($raw in $Actions) {
        $value = ([string]$raw).Trim().ToLowerInvariant().Replace(' ', '_').Replace('-', '_')
        switch -Regex ($value) {
            '^install$' { $mapped.Add('install_packages') | Out-Null; continue }
            '^network$' { $mapped.Add('api_bridge') | Out-Null; $mapped.Add('open_network_port') | Out-Null; continue }
            '^outside_allowed_writes$' { continue }
            '^app/model/ranking/source_truth_promotion$' { $mapped.Add('ranking_formula_source_truth_promotion') | Out-Null; continue }
        }
        if ($script:TsfKernelRestrictedActions -contains $value) { $mapped.Add($value) | Out-Null }
    }
    return @($mapped | Sort-Object -Unique)
}
function ConvertTo-TsfCanonicalExecutionArtifacts {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[string]$RepositoryRoot=$script:TsfRoot)
    $validation=Test-TsfMissionEnvelope $Mission; if(!$validation.valid){throw "Invalid durable mission: $($validation.errors -join '; ')"}
    $roles=Read-TsfKernelJson (Join-Path $script:TsfRoot 'fleet\control\worker-role-registry.v1.json'); $role=@($roles.roles|Where-Object{[string]$_.role_id -eq [string]$Mission.worker_role}); if($role.Count -ne 1){throw 'Worker role is absent or ambiguous in canonical registry.'}
    $profiles=Read-TsfKernelJson (Join-Path $script:TsfRoot 'fleet\control\worker-permission-profiles.v1.json'); if(!(Test-TsfContractProperty $profiles.profiles ([string]$Mission.worker_role))){throw 'Permission profile is absent from canonical registry.'}; $profile=$profiles.profiles.([string]$Mission.worker_role)
    if(@($Mission.allowed_writes).Count -gt 0 -and ![bool]$profile.may_commit_locally){throw 'Durable writes conflict with canonical permission profile.'}
    $routing=Resolve-TsfModelRouting ([string]$Mission.model_policy_alias) ([string]$Mission.recommended_surface); if([string]$Mission.resolved_model -and [string]$Mission.resolved_model -ne $routing.resolved_model){throw 'Durable resolved_model conflicts with canonical model routing.'}
    $repo=Resolve-TsfDurableRepository $Mission $RepositoryRoot; $forbidden=ConvertTo-TsfOperationalForbiddenActions (@($Mission.forbidden_actions)+@($profile.mandatory_forbidden_actions))
    $stops=@(); $n=0; foreach($text in @($Mission.stop_conditions)){$n++;$stops+=[pscustomobject]@{id=('durable-stop-{0:d3}' -f $n);check_type='manual';description=[string]$text}}
    $approvals=@($Mission.approval_references|ForEach-Object{[pscustomobject]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;required=$true;reason='Required by canonical durable mission.'}})
    $packet=[pscustomobject][ordered]@{mission_id=[string]$Mission.mission_id;project_id=[string]$Mission.project_id;repo_path=$repo;lane='MASTER_TSF_CONTROL_PLANE';mission_type='tsf_infrastructure';allowed_reads=@($Mission.allowed_reads);allowed_writes=@($Mission.allowed_writes);forbidden_reads=@($Mission.forbidden_sources);forbidden_writes=@($Mission.forbidden_repositories);forbidden_actions=$forbidden;expected_artifacts=@($Mission.required_artifacts|ForEach-Object{[string]$_.path});required_preflight_checks=@('schema','repo_exists','path_scope','restricted_action_coverage','git_status_capture','approval_ledger');required_postrun_checks=@('mission_id_match','expected_artifacts_exist','restricted_actions_absent','forbidden_outputs_absent')+@($Mission.required_tests|Where-Object{$_.required}|ForEach-Object{"test:$($_.test_id)"});stop_conditions=$stops;approval_requirements=$approvals;hq_escalation_policy=[pscustomobject]@{default='local_only_no_api';escalate_on=@('RED','TIM_REQUIRED','approval_gap','scope_conflict');notes='Generated from canonical durable mission.'};created_by='TSF_DURABLE_TRANSLATOR';created_at=[string]$Mission.created_at}
    $roleExt=[pscustomobject][ordered]@{requested_by='TSF_DURABLE_MISSION';project_main_bot_id=[string]$Mission.project_id;worker_role=[string]$Mission.worker_role;translator_used=$true;parent_mission_id=if($null -eq $Mission.parent_mission_id){''}else{[string]$Mission.parent_mission_id};role_permission_profile_id=[string]$profile.profile_id;role_output_contract=[string]$role[0].output_contract;verifier_role=if([bool]$profile.requires_verifier){'verifier_worker'}else{'NONE'};escalation_policy_id='canonical_durable_v1'}
    $worker=[pscustomobject][ordered]@{mission_id=[string]$Mission.mission_id;worker_role=[string]$Mission.worker_role;allowed_reads=@($Mission.allowed_reads);allowed_writes=@($Mission.allowed_writes);forbidden_actions=$forbidden;exact_task=[string]$Mission.normalized_goal;expected_artifacts=@($packet.expected_artifacts);stop_conditions=$stops;verifier_contract=[string]$Mission.required_verifier_independence;escalation_triggers=@('approval_gap','scope_conflict','validation_failure');do_not_exceed_role_authority=$true}
    foreach($contract in @(
        [pscustomobject]@{value=$packet;schema=(Join-Path $script:TsfRoot 'docs\hq\enforcement_kernel\minimum_viable_local_tsf_enforcement_kernel_v1\mission_schema_v1.json');name='mission_packet'},
        [pscustomobject]@{value=$roleExt;schema=(Join-Path $script:TsfRoot 'fleet\control\role-aware-mission-extension.v1.json');name='role_extension'},
        [pscustomobject]@{value=$worker;schema=(Join-Path $script:TsfRoot 'fleet\control\worker-instruction-packet.schema.v1.json');name='worker_instruction_packet'}
    )){$check=Test-TsfJsonContract $contract.value $contract.schema;if(!$check.valid){throw "Generated $($contract.name) violates its canonical schema: $($check.errors -join '; ')"}}
    $hash=Get-TsfContractJsonHash $Mission; $binding=[pscustomobject][ordered]@{durable_mission_id=[string]$Mission.mission_id;durable_mission_revision=[int]$Mission.mission_revision;policy_fingerprint=[string]$Mission.policy.fingerprint;durable_mission_content_hash=$hash;translator_version=$script:TranslatorVersion;generated_at=[string]$Mission.created_at}
    [pscustomobject][ordered]@{compatibility_status='GENERATED_EXECUTION_PACKET';source_binding=$binding;model_resolution=$routing;mission_packet=$packet;role_extension=$roleExt;worker_instruction_packet=$worker}
}

function ConvertTo-TsfDurableResultEnvelope {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[Parameter(Mandatory)][object]$RuntimeEvidence,[string]$RepositoryRoot=$script:TsfRoot)
    $translation=ConvertTo-TsfCanonicalExecutionArtifacts $Mission $RepositoryRoot; $repo=[string]$translation.mission_packet.repo_path; $git=Get-TsfKernelGitState $repo; if(!$git.can_capture){throw 'Canonical Git observation failed.'}
    $artifacts=@(); foreach($claim in @(ConvertTo-TsfContractArray $RuntimeEvidence.artifacts)){if(!(Test-TsfKernelPathTokenSafe ([string]$claim.path)) -or [IO.Path]::IsPathRooted([string]$claim.path)){throw "Unsafe artifact path: $($claim.path)"};$full=Get-TsfKernelFullPath ([string]$claim.path) $repo;if(!(Test-TsfKernelPathInside $full $repo)){throw 'Artifact escapes repository.'};$exists=Test-Path -LiteralPath $full -PathType Leaf;$artifacts+=[pscustomobject]@{path=[string]$claim.path;sha256=if($exists){(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null};exists=$exists;evidence_classification='FILESYSTEM_OBSERVED'}}
    $verifier=@(); if($RuntimeEvidence.verifier_result){$v=$RuntimeEvidence.verifier_result;$verifier+=[pscustomobject]@{verifier_id=[string]$v.verifier_id;verifier_role=[string]$v.verifier_role;independence=[string]$v.independence;passed=[bool]$v.passed;evidence=[string]$v.evidence;evidence_classification='VERIFIER_OBSERVED'}}
    $tests=@($RuntimeEvidence.test_records|ForEach-Object{[pscustomobject]@{test_id=[string]$_.test_id;status=[string]$_.status;observed=[string]$_.observed;evidence=[string]$_.evidence;evidence_classification='KERNEL_OBSERVED'}})
    $approvals=@($RuntimeEvidence.approval_usage|ForEach-Object{[pscustomobject]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;used=[bool]$_.used;evidence_classification='KERNEL_OBSERVED'}})
    $mapped=[pscustomobject][ordered]@{schema_version=$script:ResultSchemaVersion;result_id=[string]$RuntimeEvidence.result_id;mission_id=[string]$Mission.mission_id;mission_revision=[int]$Mission.mission_revision;mission_content_hash=[string]$translation.source_binding.durable_mission_content_hash;parent_mission_id=$Mission.parent_mission_id;policy_fingerprint=[string]$Mission.policy.fingerprint;surface_used=[string]$RuntimeEvidence.surface_used;surface_task_identity=$RuntimeEvidence.surface_task_identity;actual_model=$RuntimeEvidence.observed_model;actual_reasoning_effort=if($RuntimeEvidence.observed_reasoning_effort){[string]$RuntimeEvidence.observed_reasoning_effort}else{'UNKNOWN'};model_assurance_level=if($RuntimeEvidence.model_assurance_level){[string]$RuntimeEvidence.model_assurance_level}else{'RECOMMENDED_ONLY'};actual_repository=$repo;actual_branch_worktree=[pscustomobject]@{branch=$git.branch;worktree=$repo};git_facts=[pscustomobject]@{starting_head=$RuntimeEvidence.starting_head;ending_head=$git.head;base_head=$RuntimeEvidence.base_head;dirty_before=$RuntimeEvidence.dirty_before;dirty_after=$git.dirty};files_inspected=@($RuntimeEvidence.filesystem_files_inspected);files_changed=@($RuntimeEvidence.filesystem_files_changed);major_actions=@($RuntimeEvidence.worker_result.major_actions);network_activity=$RuntimeEvidence.network_observation;artifacts=$artifacts;tests=$tests;verifier_evidence=$verifier;approval_use=$approvals;preservation_evidence=[pscustomobject]@{packet_path=[string]$RuntimeEvidence.preservation_packet_path;packet_sha256=[string]$RuntimeEvidence.preservation_packet_sha256;evidence_classification='KERNEL_OBSERVED'};evidence_bindings=[pscustomobject]@{mapper_version=$script:ResultMapperVersion;runtime_evidence_sha256=Get-TsfContractJsonHash $RuntimeEvidence;repository='FILESYSTEM_OBSERVED';git='KERNEL_OBSERVED';model=if($RuntimeEvidence.model_assurance_level -in @('ADAPTER_VERIFIED','TECHNICALLY_ENFORCED')){'ADAPTER_OBSERVED'}else{'UNVERIFIED'};files='FILESYSTEM_OBSERVED'};deviations_from_mission=@($RuntimeEvidence.deviations);uncertainty=@($RuntimeEvidence.uncertainty);security_or_scope_warnings=@($RuntimeEvidence.warnings);proposed_next_action=[string]$RuntimeEvidence.proposed_next_action;authority_statement='Observed evidence only; grants no approval, merge, or production authority.';grants_approval=$false;grants_merge_authority=$false;grants_production_authority=$false;created_at=[string]$RuntimeEvidence.created_at}
    $mappedValidation=Test-TsfResultEnvelope $mapped;if(!$mappedValidation.valid){throw "Mapped result violates canonical schema: $($mappedValidation.errors -join '; ')"};return $mapped
}

function Test-TsfReparsePathContained {
    param([string]$FullPath,[string]$Repo)
    $cursor=$FullPath
    while((Test-TsfKernelPathInside $cursor $Repo) -and ![string]::Equals($cursor.TrimEnd('\','/'),$Repo.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){
        if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){$target=[string]$item.Target;if([string]::IsNullOrWhiteSpace($target)){return $false};if(![IO.Path]::IsPathRooted($target)){$target=Get-TsfKernelFullPath $target (Split-Path -Parent $cursor)};if(!(Test-TsfKernelPathInside $target $Repo)){return $false}}};$cursor=Split-Path -Parent $cursor
    }
    return $true
}
function Test-TsfCanonicalRelativePath { param([string]$Path,[string]$Repo,[object[]]$Scopes) if([IO.Path]::IsPathRooted($Path)-or !(Test-TsfKernelPathTokenSafe $Path)){return $false};$full=Get-TsfKernelFullPath $Path $Repo;if(!(Test-TsfKernelPathInside $full $Repo)-or !(Test-TsfReparsePathContained $full $Repo)){return $false};foreach($scope in $Scopes){if([IO.Path]::IsPathRooted([string]$scope)){continue};$root=Get-TsfKernelFullPath ([string]$scope) $Repo;if((Test-TsfKernelPathInside $root $Repo)-and(Test-TsfKernelPathInside $full $root)){return $true}};return $false }
function Get-TsfAdmissionQueueTarget { param([string]$Status) if($Status -eq 'ADMITTED'){return 'complete_ready_for_gate'};if($Status -eq 'TIM_REQUIRED'){return 'blocked_needs_tim'};return 'complete_review_only' }
function New-TsfAdmissionReceipt { param($Result,$Hash,$Status,$Reasons,$Caveats,$Now,$From,$To,$Applied,$Transition) [pscustomobject][ordered]@{schema_version=$script:AdmissionSchemaVersion;receipt_id="admission-$($Result.result_id)-$($Hash.Substring(0,12))";result_id=[string]$Result.result_id;mission_id=$Result.mission_id;result_sha256=$Hash;status=$Status;reasons=@($Reasons);caveats=@($Caveats);duplicate_submission=$false;idempotent_replay=$false;decided_at=$Now.ToUniversalTime().ToString('o');queue_state_from=$From;queue_state_to=$To;queue_transition_applied=$Applied;queue_transition_path=$Transition;grants_approval=$false;grants_merge_authority=$false;grants_production_authority=$false} }

function Get-TsfAdmissionDecision {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ResultPath,[Parameter(Mandatory)][string]$MissionRegistryPath,[Parameter(Mandatory)][string]$ActivePolicyManifestPath,[Parameter(Mandatory)][string]$ApprovalLedgerPath,[Parameter(Mandatory)][string]$PreservationPacketPath,[Parameter(Mandatory)][string]$QueueMissionPath,[Parameter(Mandatory)][string]$QueueRootPath,[datetimeoffset]$CurrentTime=[datetimeoffset]::UtcNow,[switch]$UnsupportedDevelopmentMode)
    $result=Read-TsfKernelJson $ResultPath;$hash=(Get-FileHash -LiteralPath $ResultPath -Algorithm SHA256).Hash.ToLowerInvariant();$presDir=if(Test-Path $PreservationPacketPath -PathType Container){Get-TsfKernelFullPath $PreservationPacketPath}else{Split-Path -Parent (Get-TsfKernelFullPath $PreservationPacketPath)};$receiptDir=Join-Path $presDir 'admission';New-Item -ItemType Directory -Force $receiptDir|Out-Null;$safe=([string]$result.result_id)-replace '[^A-Za-z0-9._-]','_';$receiptPath=Join-Path $receiptDir "$safe.admission.json"
    if(Test-Path $receiptPath){$old=Read-TsfKernelJson $receiptPath;if([string]$old.result_sha256 -eq $hash){$old.duplicate_submission=$true;$old.idempotent_replay=$true;return $old};$conflict=New-TsfAdmissionReceipt $result $hash 'REJECTED_INVALID_EVIDENCE' @('result_id was reused with different content.') @() $CurrentTime 'postrun_pending' 'complete_review_only' $false '';Write-TsfKernelJson $conflict $receiptPath;return $conflict}
    $matches=@();Get-ChildItem -LiteralPath $MissionRegistryPath -Filter '*.json' -File -Recurse|Sort-Object FullName|ForEach-Object{try{$m=Read-TsfKernelJson $_.FullName;if([string]$m.mission_id -eq [string]$result.mission_id){$matches+=[pscustomobject]@{path=$_.FullName;mission=$m}}}catch{}}
    $status='ADMITTED';$reasons=[Collections.Generic.List[string]]::new();$caveats=[Collections.Generic.List[string]]::new();$mission=$null
    if([string]::IsNullOrWhiteSpace([string]$result.mission_id)){$status='UNTRUSTED_NOT_TSF_GOVERNED';$reasons.Add('Result has no durable mission identity.')|Out-Null}elseif($matches.Count -ne 1){$status=if($matches.Count -eq 0){'UNTRUSTED_NOT_TSF_GOVERNED'}else{'REJECTED_INVALID_EVIDENCE'};$reasons.Add("Durable mission lookup returned $($matches.Count) matches; exactly one is required.")|Out-Null}else{$mission=$matches[0].mission}
    if($status -eq 'ADMITTED'){ $rv=Test-TsfResultEnvelope $result;$mv=Test-TsfMissionEnvelope $mission;if(!$rv.valid-or!$mv.valid){$status='REJECTED_INVALID_EVIDENCE';@($rv.errors)+@($mv.errors)|ForEach-Object{$reasons.Add([string]$_)|Out-Null}} }
    $translation=$null;if($status -eq 'ADMITTED'){try{$translation=ConvertTo-TsfCanonicalExecutionArtifacts $mission}catch{$status='REJECTED_INVALID_EVIDENCE';$reasons.Add($_.Exception.Message)|Out-Null}}
    if($status -eq 'ADMITTED'){$active=Get-TsfPolicyFingerprint $ActivePolicyManifestPath $script:TsfRoot -UnsupportedDevelopmentMode:$UnsupportedDevelopmentMode;if($active.fingerprint -ne [string]$mission.policy.fingerprint -or [string]$result.policy_fingerprint -ne [string]$mission.policy.fingerprint){$status='REJECTED_POLICY_MISMATCH';$reasons.Add('Active, mission, and result policy fingerprints are not identical.')|Out-Null}}
    if($status -eq 'ADMITTED' -and ([int]$result.mission_revision -ne [int]$mission.mission_revision -or [string]$result.mission_content_hash -ne (Get-TsfContractJsonHash $mission))){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Durable mission revision or content hash binding is invalid.')|Out-Null}
    if($status -eq 'ADMITTED' -and ([bool]$result.grants_approval-or[bool]$result.grants_merge_authority-or[bool]$result.grants_production_authority)){$status='TIM_REQUIRED';$reasons.Add('Result attempted to grant authority.')|Out-Null}
    if($status -eq 'ADMITTED'){$presPath=[string]$result.preservation_evidence.packet_path;if(!(Test-Path -LiteralPath $presPath -PathType Leaf)-or (Get-FileHash -LiteralPath $presPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$result.preservation_evidence.packet_sha256){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Preservation packet observation or hash is invalid.')|Out-Null}}
    if($status -eq 'ADMITTED'){$repo=[string]$translation.mission_packet.repo_path;$git=Get-TsfKernelGitState $repo;if(!$git.can_capture-or ![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_repository)).TrimEnd('\','/'),$repo.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Observed repository identity is unavailable or mismatched.')|Out-Null}else{if([bool]$mission.branch_worktree_policy.branch_required -and [string]$result.actual_branch_worktree.branch -ne [string]$mission.branch_worktree_policy.expected_branch){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed branch violates durable mission policy.')|Out-Null};if([bool]$mission.branch_worktree_policy.worktree_required -and ![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_branch_worktree.worktree)).TrimEnd('\','/'),(Get-TsfKernelFullPath ([string]$mission.branch_worktree_policy.expected_worktree)).TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed worktree violates durable mission policy.')|Out-Null};foreach($p in @($result.files_changed)){if(!(Test-TsfCanonicalRelativePath $p $repo @($mission.allowed_writes))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Changed path is outside canonical allowed_writes: $p")|Out-Null;break}};foreach($p in @($result.files_inspected)){if(!(Test-TsfCanonicalRelativePath $p $repo @($mission.allowed_reads))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Inspected path is outside canonical allowed_reads: $p")|Out-Null;break}}}}
    if($status -eq 'ADMITTED' -and [string]$mission.network_policy -eq 'PROHIBITED' -and ($result.network_activity.used -eq $true -or @($result.network_activity.destinations).Count -gt 0)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed network activity violates PROHIBITED policy.')|Out-Null}
    if($status -eq 'ADMITTED'){foreach($a in @($result.artifacts)){if($a.evidence_classification -ne 'FILESYSTEM_OBSERVED' -or !(Test-TsfCanonicalRelativePath $a.path ([string]$translation.mission_packet.repo_path) @($mission.allowed_writes))){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact is not filesystem-bound: $($a.path)")|Out-Null;break};$full=Get-TsfKernelFullPath $a.path ([string]$translation.mission_packet.repo_path);$observed=if(Test-Path $full -PathType Leaf){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{''};if($observed -ne [string]$a.sha256){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact hash mismatch: $($a.path)")|Out-Null;break}}}
    if($status -eq 'ADMITTED'){foreach($t in @($mission.required_tests|Where-Object{$_.required})){if(@($result.tests|Where-Object{$_.test_id -eq $t.test_id -and $_.status -eq 'PASS' -and $_.evidence_classification -in @('KERNEL_OBSERVED','VERIFIER_OBSERVED')}).Count -ne 1){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Required observed test is missing: $($t.test_id)")|Out-Null;break}}}
    if($status -eq 'ADMITTED' -and ![string]::IsNullOrWhiteSpace([string]$mission.expires_at) -and $CurrentTime -gt [datetimeoffset]::Parse([string]$mission.expires_at)){$status=if($mission.stale_state_behavior -eq 'TIM_REQUIRED'){'TIM_REQUIRED'}elseif($mission.stale_state_behavior -eq 'REJECT'){'REJECTED_INVALID_EVIDENCE'}else{'REVIEW_REQUIRED'};$reasons.Add('Durable mission expired before admission.')|Out-Null}
    if($status -eq 'ADMITTED' -and [string]$mission.required_verifier_independence -ne 'NONE'){if(@($result.verifier_evidence|Where-Object{$_.independence -eq $mission.required_verifier_independence -and $_.passed -and $_.evidence_classification -eq 'VERIFIER_OBSERVED'}).Count -ne 1){$status='REVIEW_REQUIRED';$reasons.Add('Canonical independent verifier evidence is missing.')|Out-Null}}
    $used=@($result.approval_use|Where-Object{$_.used});if($used.Count){$ledger=Get-TsfKernelApprovalLedger $ApprovalLedgerPath;$native=@(Find-TsfKernelApprovalMatches $translation.mission_packet $ledger $ApprovalLedgerPath -AllowFixtureApprovalsForTests);foreach($u in $used){$m=@($native|Where-Object{$_.approval_id -eq $u.approval_id -and $_.exact_action -eq $u.exact_action -and $_.satisfied});if($m.Count -ne 1){$status='TIM_REQUIRED';$reasons.Add("Approval usage failed canonical exact-action ledger resolution: $($u.approval_id)")|Out-Null}}}
    if($status -eq 'ADMITTED' -and $result.actual_model -and $mission.resolved_model -and $result.actual_model -ne $mission.resolved_model){$status='REVIEW_REQUIRED';$reasons.Add('Observed model differs from mission resolution.')|Out-Null};if($status -eq 'ADMITTED' -and $result.actual_reasoning_effort -ne 'UNKNOWN' -and $result.actual_reasoning_effort -ne $mission.reasoning_effort){$status='REVIEW_REQUIRED';$reasons.Add('Observed reasoning effort differs from mission request.')|Out-Null}
    if($reasons.Count -eq 0){$reasons.Add('Observed runtime evidence satisfied the canonical durable mission.')|Out-Null};$target=Get-TsfAdmissionQueueTarget $status;$transitionFile=Join-Path $receiptDir "$safe.queue-transition.json";$transition=& (Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $QueueMissionPath -FromState 'postrun_pending' -ToState $target -QueueRoot $QueueRootPath -OutFile $transitionFile;if([string]$transition.verdict -ne 'GREEN'){throw "Canonical queue transition failed: $($transition.blocked_reasons -join '; ')"}
    $receipt=New-TsfAdmissionReceipt $result $hash $status @($reasons) @($caveats) $CurrentTime 'postrun_pending' $target $true ([string]$transition.destination_path);Write-TsfKernelJson $receipt $receiptPath;return $receipt
}
