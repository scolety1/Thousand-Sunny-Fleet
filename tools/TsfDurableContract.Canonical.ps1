$script:MissionSchemaVersion = "tsf_mission_envelope_v1"
$script:ResultSchemaVersion = "tsf_result_envelope_v1"
$script:AdmissionSchemaVersion = "tsf_admission_decision_v1"
$script:PolicyManifestVersion = "tsf_policy_manifest_v1"
$script:TranslatorVersion = "tsf_durable_to_operational_v1"
$script:ResultMapperVersion = "tsf_runtime_evidence_to_result_v1"
$script:EvidenceClasses = @("NATIVE_OBSERVED", "ADAPTER_OBSERVED", "KERNEL_OBSERVED", "FILESYSTEM_OBSERVED", "VERIFIER_OBSERVED", "AGENT_REPORTED", "UNVERIFIED")

. (Join-Path $script:TsfRoot 'tools\TsfJsonContract.ps1')
function Test-TsfMissionEnvelope { [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\mission-envelope.schema.v1.json')) $r=Test-TsfJsonContract $Mission $SchemaPath; [pscustomobject]@{schema_version='tsf_mission_envelope_validation_v1';valid=$r.valid;errors=$r.errors;coverage=$r.coverage} }
function Test-TsfResultEnvelope { [CmdletBinding()] param([Parameter(Mandatory)][object]$Result,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\result-envelope.schema.v1.json')) $r=Test-TsfJsonContract $Result $SchemaPath; [pscustomobject]@{schema_version='tsf_result_envelope_validation_v1';valid=$r.valid;errors=$r.errors;coverage=$r.coverage} }

function Invoke-TsfContractGit { param([string]$Root,[string[]]$Arguments) $safe=$Root.Replace('\','/'); $output=@(& git -c "safe.directory=$safe" -C $Root @Arguments 2>&1); if($LASTEXITCODE -ne 0){throw "git $($Arguments -join ' ') failed: $($output -join ' ')"}; return @($output) }

function Get-TsfPolicyFingerprint {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ManifestPath,[string]$RepositoryRoot=$script:TsfRoot,[switch]$UnsupportedDevelopmentMode)
    $root=(Invoke-TsfContractGit $RepositoryRoot @('rev-parse','--show-toplevel')|Select-Object -First 1).Trim(); $head=(Invoke-TsfContractGit $root @('rev-parse','HEAD^{commit}')|Select-Object -First 1).Trim()
    $manifestFull=Get-TsfKernelFullPath $ManifestPath $root; if(!(Test-TsfKernelPathInside $manifestFull $root)){throw 'Policy manifest escapes repository.'}
    $manifest=Read-TsfKernelJson $manifestFull; if([string]$manifest.schema_version -ne $script:PolicyManifestVersion){throw 'Unsupported policy manifest version.'}
    $required=@(
        'tools/TsfJsonContract.ps1','tools/TsfRuntimeArtifactAddressing.ps1','tools/TsfDurableContract.psm1','tools/TsfDurableContract.Canonical.ps1',
        'tools/codex-fleet-enforcement-kernel.ps1','tools/Move-TsfMissionState.ps1',
        'tools/Invoke-TsfMissionQueueForegroundExecutor.ps1','tools/Invoke-TsfMissionLifecycle.ps1',
        'tools/Test-TsfWorkerRolePermission.ps1','tools/Invoke-TsfCodexAppServerForeground.ps1',
        'tools/tsf-codex-app-server-adapter.mjs','tools/Get-TsfAdmissionDecision.ps1','tools/Repair-TsfSyntheticAdmissionFixture.ps1',
        'projects.json','fleet/control/mission-envelope.schema.v1.json','fleet/control/canonical-queue-document.schema.v1.json',
        'fleet/control/result-envelope.schema.v1.json','fleet/control/runtime-artifact-manifest.schema.v1.json','fleet/control/admission-decision.schema.v1.json',
        'fleet/control/model-routing-alias-policy.v1.json','fleet/control/worker-role-registry.v1.json',
        'fleet/control/worker-permission-profiles.v1.json','fleet/control/mission-queue-state-policy.v1.json',
        'fleet/control/mission-queue-foreground-executor-policy.v1.json','fleet/control/role-aware-mission-extension.v1.json',
        'fleet/control/worker-instruction-packet.schema.v1.json',
        'docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/mission_schema_v1.json',
        'docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/approval_ledger_schema_v1.json'
    )
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

function ConvertTo-TsfCanonicalEffortName {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'UNKNOWN' }
    switch (([string]$Value).Trim().ToUpperInvariant().Replace('-', '_')) {
        'LOW' { return 'LIGHT' }
        'LIGHT' { return 'LIGHT' }
        'MEDIUM' { return 'MEDIUM' }
        'HIGH' { return 'HIGH' }
        'XHIGH' { return 'EXTRA_HIGH' }
        'EXTRA_HIGH' { return 'EXTRA_HIGH' }
        'MAX' { return 'MAX' }
        'ULTRA' { return 'ULTRA' }
        'UNKNOWN' { return 'UNKNOWN' }
        default { throw "Unrecognized reasoning effort value: $Value" }
    }
}

function Get-TsfEffortEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Mission,
        [Parameter(Mandatory)][object]$Adapter
    )

    foreach ($field in @('mission_requested_effort','canonical_resolved_effort','thread_default_effort','turn_requested_effort','effective_effort','effective_effort_raw','effective_effort_source','effort_assurance','required_effort_assurance','turn_request_acknowledged','native_reroute_or_override_events')) {
        if (!($Adapter.PSObject.Properties.Name -contains $field)) { throw "Adapter effort evidence is missing $field." }
    }

    $missionRequestedRaw = [string]$Mission.reasoning_effort
    $missionRequested = ConvertTo-TsfCanonicalEffortName $missionRequestedRaw
    $adapterMissionRequested = ConvertTo-TsfCanonicalEffortName ([string]$Adapter.mission_requested_effort)
    $canonicalResolved = ConvertTo-TsfCanonicalEffortName ([string]$Adapter.canonical_resolved_effort)
    $threadDefaultRaw = if ($null -eq $Adapter.thread_default_effort) { $null } else { [string]$Adapter.thread_default_effort }
    $threadDefault = ConvertTo-TsfCanonicalEffortName $threadDefaultRaw
    $turnRequestedRaw = if ($null -eq $Adapter.turn_requested_effort) { $null } else { [string]$Adapter.turn_requested_effort }
    $turnRequested = ConvertTo-TsfCanonicalEffortName $turnRequestedRaw
    $effectiveRaw = if ($null -eq $Adapter.effective_effort_raw) { $null } else { [string]$Adapter.effective_effort_raw }
    $effectiveSource = [string]$Adapter.effective_effort_source
    $effective = if ($effectiveSource -eq 'NOT_EXPOSED') { 'UNKNOWN' } else { ConvertTo-TsfCanonicalEffortName $effectiveRaw }
    $nativeEvents = @($Adapter.native_reroute_or_override_events)
    $conflicts = [Collections.Generic.List[string]]::new()
    $effect = 'ADMITTED'

    if ($missionRequested -ne $adapterMissionRequested -or $canonicalResolved -ne $missionRequested) {
        $conflicts.Add('MISSION_OR_RESOLVER_EFFORT_BINDING_MISMATCH') | Out-Null
        $effect = 'REJECTED_INVALID_EVIDENCE'
    }
    if (![bool]$Adapter.turn_request_acknowledged -or $turnRequested -ne $canonicalResolved) {
        $conflicts.Add('TURN_REQUEST_DIFFERS_FROM_CANONICAL_RESOLUTION') | Out-Null
        $effect = 'REJECTED_INVALID_EVIDENCE'
    }
    if ($threadDefault -ne 'UNKNOWN' -and $turnRequested -ne 'UNKNOWN' -and $threadDefault -ne $turnRequested) {
        $conflicts.Add('THREAD_DEFAULT_DIFFERS_FROM_TURN_REQUEST') | Out-Null
    }
    if ($effectiveSource -eq 'NOT_EXPOSED' -and $null -ne $effectiveRaw) { throw 'Adapter supplied an effective effort value while declaring NOT_EXPOSED.' }
    if ($effectiveSource -ne 'NOT_EXPOSED' -and ($null -eq $effectiveRaw -or $effective -eq 'UNKNOWN')) { throw 'Adapter declared an authoritative effective source without an effective effort value.' }
    if ((ConvertTo-TsfCanonicalEffortName ([string]$Adapter.effective_effort)) -ne $effective) { throw 'Adapter normalized effective effort does not match its raw evidence.' }

    $hasReroute = @($nativeEvents | Where-Object { [string]$_.method -eq 'model/rerouted' }).Count -gt 0
    if ($hasReroute) { $conflicts.Add('NATIVE_MODEL_REROUTE_OBSERVED') | Out-Null }
    if ($effective -ne 'UNKNOWN' -and $effective -ne $canonicalResolved) {
        $conflicts.Add('EFFECTIVE_EFFORT_DIFFERS_FROM_CANONICAL_RESOLUTION') | Out-Null
        $effect = 'REJECTED_OUT_OF_SCOPE'
    }

    $observedAssurance = if ($effective -eq 'UNKNOWN') { 'RECOMMENDED_ONLY' } else { 'ADAPTER_VERIFIED' }
    if ([string]$Adapter.effort_assurance -ne $observedAssurance) { throw 'Adapter effort assurance overstates or conflicts with observed evidence.' }
    $requiredAssurance = [string]$Mission.model_selection_assurance
    if ([string]$Adapter.required_effort_assurance -ne $requiredAssurance) { throw 'Adapter required effort assurance is not bound to the durable mission.' }
    if ($effect -eq 'ADMITTED') {
        if ($effective -eq 'UNKNOWN') {
            $effect = switch ($requiredAssurance) {
                'RECOMMENDED_ONLY' { 'ADMITTED_WITH_CAVEATS' }
                'USER_CONFIRMED' { 'REVIEW_REQUIRED' }
                default { 'TIM_REQUIRED' }
            }
        } elseif ($requiredAssurance -eq 'TECHNICALLY_ENFORCED') {
            $effect = 'TIM_REQUIRED'
            $conflicts.Add('TECHNICALLY_ENFORCED_EFFORT_NOT_PROVEN') | Out-Null
        } elseif ($conflicts.Count -gt 0) {
            $effect = 'ADMITTED_WITH_CAVEATS'
        }
    }

    [pscustomobject][ordered]@{
        normalization_vocabulary = 'tsf_canonical_effort_v1'
        mission_requested_effort = $missionRequestedRaw
        canonical_resolved_effort = $canonicalResolved
        thread_default_effort = $threadDefaultRaw
        turn_requested_effort = $turnRequestedRaw
        effective_effort = $effective
        effective_effort_raw = $effectiveRaw
        effective_effort_source = $effectiveSource
        effort_assurance = $observedAssurance
        required_effort_assurance = $requiredAssurance
        turn_request_acknowledged = [bool]$Adapter.turn_request_acknowledged
        native_reroute_or_override_events = $nativeEvents
        effort_conflicts = @($conflicts)
        effort_admission_effect = $effect
    }
}

function Get-TsfRawTextSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text);$sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
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
    $routing=Resolve-TsfModelRouting ([string]$Mission.model_policy_alias) ([string]$Mission.recommended_surface); if([string]$Mission.resolved_model -and [string]$Mission.resolved_model -ne $routing.resolved_model){throw 'Durable resolved_model conflicts with canonical model routing.'};if([string]$Mission.reasoning_effort -ne [string]$routing.reasoning_effort){throw 'Durable reasoning_effort conflicts with canonical model routing.'}
    $repo=Resolve-TsfDurableRepository $Mission $RepositoryRoot; $forbidden=ConvertTo-TsfOperationalForbiddenActions (@($Mission.forbidden_actions)+@($profile.mandatory_forbidden_actions))
    $stops=@(); $n=0; foreach($text in @($Mission.stop_conditions)){$n++;$stops+=[pscustomobject]@{id=('durable-stop-{0:d3}' -f $n);check_type='manual';description=[string]$text}}
    $approvals=@($Mission.approval_references|ForEach-Object{[pscustomobject]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;required=$true;reason='Required by canonical durable mission.'}})
    $packet=[pscustomobject][ordered]@{mission_id=[string]$Mission.mission_id;project_id=[string]$Mission.project_id;repo_path=$repo;lane='MASTER_TSF_CONTROL_PLANE';mission_type='tsf_infrastructure';required_branch=[string]$Mission.branch_worktree_policy.expected_branch;required_worktree=[string]$Mission.branch_worktree_policy.expected_worktree;control_plane_service_network_policy=[string]$Mission.control_plane_service_network_policy;worker_tool_network_policy=[string]$Mission.worker_tool_network_policy;allowed_reads=@($Mission.allowed_reads);allowed_writes=@($Mission.allowed_writes);forbidden_reads=@($Mission.forbidden_sources);forbidden_writes=@($Mission.forbidden_repositories);forbidden_actions=$forbidden;expected_artifacts=@($Mission.required_artifacts|ForEach-Object{[string]$_.path});required_preflight_checks=@('schema','repo_exists','path_scope','restricted_action_coverage','git_status_capture','approval_ledger','worker_role_permission','durable_source_binding');required_postrun_checks=@('mission_id_match','expected_artifacts_exist','restricted_actions_absent','forbidden_outputs_absent')+@($Mission.required_tests|Where-Object{$_.required}|ForEach-Object{"test:$($_.test_id)"});stop_conditions=$stops;approval_requirements=$approvals;hq_escalation_policy=[pscustomobject]@{default='local_only_no_api';escalate_on=@('RED','TIM_REQUIRED','approval_gap','scope_conflict');notes='Generated from canonical durable mission.'};created_by='TSF_DURABLE_TRANSLATOR';created_at=[string]$Mission.created_at}
    $roleExt=[pscustomobject][ordered]@{requested_by='TSF_DURABLE_MISSION';project_main_bot_id=[string]$Mission.project_id;worker_role=[string]$Mission.worker_role;translator_used=$true;lane_id='MASTER_TSF_CONTROL_PLANE';parent_mission_id=if($null -eq $Mission.parent_mission_id){''}else{[string]$Mission.parent_mission_id};sibling_lane_ids=@();role_permission_profile_id=[string]$profile.profile_id;role_output_contract=[string]$role[0].output_contract;verifier_role=if([bool]$profile.requires_verifier){'verifier_worker'}else{'NONE'};escalation_policy_id='canonical_durable_v1'}
    $worker=[pscustomobject][ordered]@{mission_id=[string]$Mission.mission_id;worker_role=[string]$Mission.worker_role;allowed_reads=@($Mission.allowed_reads);allowed_writes=@($Mission.allowed_writes);forbidden_actions=$forbidden;exact_task=[string]$Mission.normalized_goal;expected_artifacts=@($packet.expected_artifacts);stop_conditions=$stops;verifier_contract=[string]$Mission.required_verifier_independence;escalation_triggers=@('approval_gap','scope_conflict','validation_failure');do_not_exceed_role_authority=$true}
    foreach($contract in @(
        [pscustomobject]@{value=$packet;schema=(Join-Path $script:TsfRoot 'docs\hq\enforcement_kernel\minimum_viable_local_tsf_enforcement_kernel_v1\mission_schema_v1.json');name='mission_packet'},
        [pscustomobject]@{value=$roleExt;schema=(Join-Path $script:TsfRoot 'fleet\control\role-aware-mission-extension.v1.json');name='role_extension'},
        [pscustomobject]@{value=$worker;schema=(Join-Path $script:TsfRoot 'fleet\control\worker-instruction-packet.schema.v1.json');name='worker_instruction_packet'}
    )){$check=Test-TsfJsonContract $contract.value $contract.schema;if(!$check.valid){throw "Generated $($contract.name) violates its canonical schema: $($check.errors -join '; ')"}}
    $hash=Get-TsfContractJsonHash $Mission; $binding=[pscustomobject][ordered]@{durable_mission_id=[string]$Mission.mission_id;durable_mission_revision=[int]$Mission.mission_revision;policy_fingerprint=[string]$Mission.policy.fingerprint;durable_mission_content_hash=$hash;translator_version=$script:TranslatorVersion;generated_at=[string]$Mission.created_at;mission_packet_sha256=Get-TsfContractJsonHash $packet;role_extension_sha256=Get-TsfContractJsonHash $roleExt;worker_instruction_sha256=Get-TsfContractJsonHash $worker;expected_repository=$repo;expected_branch=$Mission.branch_worktree_policy.expected_branch;expected_worktree=$Mission.branch_worktree_policy.expected_worktree;expected_role=[string]$Mission.worker_role}
    $document=[pscustomobject][ordered]@{schema_version='tsf_canonical_queue_document_v1';compatibility_status='GENERATED_EXECUTION_PACKET';durable_mission=$Mission;source_binding=$binding;model_resolution=$routing;mission_packet=$packet;role_extension=$roleExt;worker_instruction_packet=$worker}
    $queueCheck=Test-TsfJsonContract $document (Join-Path $script:TsfRoot 'fleet\control\canonical-queue-document.schema.v1.json');if(!$queueCheck.valid){throw "Generated canonical queue document is invalid: $($queueCheck.errors -join '; ')"};return $document
}

function Test-TsfCanonicalQueueDocument {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$QueueDocument,[object]$ExpectedMission,[string]$RepositoryRoot=$script:TsfRoot,[switch]$SkipRuntimeObservation)
    $errors=[Collections.Generic.List[string]]::new();$schema=Test-TsfJsonContract $QueueDocument (Join-Path $script:TsfRoot 'fleet\control\canonical-queue-document.schema.v1.json');if(!$schema.valid){@($schema.errors)|ForEach-Object{$errors.Add([string]$_)|Out-Null}}
    if($errors.Count -eq 0){
        $mission=$QueueDocument.durable_mission;$missionCheck=Test-TsfMissionEnvelope $mission;if(!$missionCheck.valid){@($missionCheck.errors)|ForEach-Object{$errors.Add([string]$_)|Out-Null}}
        if($null -ne $ExpectedMission -and (Get-TsfContractJsonHash $ExpectedMission) -ne (Get-TsfContractJsonHash $mission)){$errors.Add('Queue durable mission differs from the expected canonical mission.')|Out-Null}
        try{$regenerated=ConvertTo-TsfCanonicalExecutionArtifacts $mission $RepositoryRoot}catch{$errors.Add($_.Exception.Message)|Out-Null;$regenerated=$null}
        if($null -ne $regenerated){foreach($name in @('source_binding','model_resolution','mission_packet','role_extension','worker_instruction_packet')){if((Get-TsfContractJsonHash $QueueDocument.$name) -ne (Get-TsfContractJsonHash $regenerated.$name)){$errors.Add("Queue $name conflicts with deterministic translation.")|Out-Null}}}
        if(!$SkipRuntimeObservation -and $errors.Count -eq 0){$repo=[string]$QueueDocument.source_binding.expected_repository;$git=Get-TsfKernelGitState $repo;if(!$git.can_capture){$errors.Add('Queue repository Git state cannot be observed.')|Out-Null}else{if([bool]$mission.branch_worktree_policy.branch_required -and [string]$git.branch -ne [string]$QueueDocument.source_binding.expected_branch){$errors.Add('Queue branch does not match durable binding.')|Out-Null};if([bool]$mission.branch_worktree_policy.worktree_required -and ![string]::Equals((Get-TsfKernelFullPath $repo).TrimEnd('\','/'),(Get-TsfKernelFullPath ([string]$QueueDocument.source_binding.expected_worktree)).TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Queue worktree does not match durable binding.')|Out-Null};if(!(Test-TsfKernelReparseContained $repo $repo)){$errors.Add('Queue repository root is a reparse point or cannot be contained.')|Out-Null}}}
    }
    $effective=$null;if($errors.Count -eq 0){$effective=$QueueDocument.mission_packet|ConvertTo-Json -Depth 100|ConvertFrom-Json;$effective|Add-Member -NotePropertyName role_extension -NotePropertyValue $QueueDocument.role_extension -Force;$effective|Add-Member -NotePropertyName durable_source_binding -NotePropertyValue $QueueDocument.source_binding -Force;$effective|Add-Member -NotePropertyName model_resolution -NotePropertyValue $QueueDocument.model_resolution -Force;$effective|Add-Member -NotePropertyName worker_instruction_contract -NotePropertyValue $QueueDocument.worker_instruction_packet -Force}
    [pscustomobject]@{valid=$errors.Count -eq 0;errors=@($errors);mission_id=if($null-ne$QueueDocument.source_binding){[string]$QueueDocument.source_binding.durable_mission_id}else{''};queue_document_sha256=Get-TsfContractJsonHash $QueueDocument;effective_mission=$effective}
}

function ConvertTo-TsfDurableResultEnvelope {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[Parameter(Mandatory)][object]$RuntimeEvidence,[string]$RepositoryRoot=$script:TsfRoot)
    if([string]$RuntimeEvidence.schema_version -ne 'tsf_authenticated_runtime_evidence_v1'){throw 'Runtime evidence is not an authenticated producer-binding packet.'}
    $translation=ConvertTo-TsfCanonicalExecutionArtifacts $Mission $RepositoryRoot;$repo=[string]$translation.mission_packet.repo_path;$git=Get-TsfKernelGitState $repo;if(!$git.can_capture){throw 'Canonical Git observation failed.'}
    $queueDocument=Read-TsfKernelJson ([string]$RuntimeEvidence.queue_document_path);$queueCheck=Test-TsfCanonicalQueueDocument $queueDocument $Mission $RepositoryRoot;if(!$queueCheck.valid){throw "Queue producer binding failed: $($queueCheck.errors -join '; ')"}
    $adapter=Read-TsfKernelJson ([string]$RuntimeEvidence.adapter_result_path);$preflight=Read-TsfKernelJson ([string]$RuntimeEvidence.preflight_path);$rolePreflight=Read-TsfKernelJson ([string]$RuntimeEvidence.role_preflight_path);$worker=Read-TsfKernelJson ([string]$RuntimeEvidence.worker_result_path);$verifierResult=Read-TsfKernelJson ([string]$RuntimeEvidence.verifier_result_path);$presPath=Get-TsfKernelFullPath ([string]$RuntimeEvidence.preservation_packet_path);$presDescriptor=Get-TsfPreservationPacketDescriptor $presPath ([string]$Mission.mission_id) ([int]$Mission.mission_revision);$preservation=Read-TsfKernelJson $presPath
    foreach($producer in @($adapter,$preflight,$worker,$verifierResult,$preservation)){if([string]$producer.mission_id -ne [string]$Mission.mission_id){throw 'Observed producer mission identity mismatch.'}}
    if([string]$rolePreflight.role_id -ne [string]$Mission.worker_role -or ![bool]$rolePreflight.role_preflight_approved){throw 'Role preflight producer is unbound or not approved.'}
    if(![bool]$preflight.preflight_approved -or ![bool]$verifierResult.verified){throw 'Kernel producer evidence is not approved and verified.'}
    if([string]$adapter.mission_revision -ne [string]$Mission.mission_revision -or [string]$adapter.policy_fingerprint -ne [string]$Mission.policy.fingerprint -or [string]$adapter.queue_document_sha256 -ne [string]$queueCheck.queue_document_sha256){throw 'Adapter durable binding mismatch.'}
    if([string]$adapter.cwd -ne [string]$repo -or [string]$adapter.observed_model -ne [string]$translation.model_resolution.resolved_model){throw 'Adapter repository or model observation mismatch.'}
    if([string]$adapter.control_plane_service_network_policy -ne 'CODEX_SERVICE_ONLY' -or [string]$adapter.worker_tool_network_policy -ne 'DISABLED' -or ![bool]$adapter.codex_service_connection_used -or [bool]$adapter.direct_openai_api_called_by_tsf -or [bool]$adapter.external_api_called -or [bool]$adapter.worker_network_used){throw 'Adapter network-policy evidence is invalid.'}
    if(![bool]$adapter.child_exited -or ![bool]$adapter.no_orphan_process -or [string]::IsNullOrWhiteSpace([string]$adapter.thread_id) -or [string]::IsNullOrWhiteSpace([string]$adapter.turn_id)){throw 'Adapter native identity or cleanup evidence is incomplete.'}
    $journalPath=Get-TsfKernelFullPath ([string]$adapter.event_journal_path);if(!(Test-Path $journalPath -PathType Leaf)){throw 'Adapter event journal is missing.'};$journalHash=(Get-FileHash $journalPath -Algorithm SHA256).Hash.ToLowerInvariant();if($journalHash -ne [string]$adapter.event_journal_sha256){throw 'Adapter event journal hash mismatch.'}
    $journalEntries=@(Get-Content -LiteralPath $journalPath|Where-Object{![string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_|ConvertFrom-Json})
    foreach($nativeEvent in @($adapter.native_reroute_or_override_events)){
        if((Get-TsfRawTextSha256 ([string]$nativeEvent.raw_payload_json))-ne[string]$nativeEvent.raw_payload_sha256){throw 'Adapter native effort-event payload hash mismatch.'}
        $rawPayload=[string]$nativeEvent.raw_payload_json|ConvertFrom-Json
        $bound=@($journalEntries|Where-Object{[int]$_.sequence-eq[int]$nativeEvent.sequence-and[string]$_.direction-eq'server_to_client'-and[string]$_.message.method-eq[string]$nativeEvent.method})
        if($bound.Count-ne1-or(Get-TsfContractJsonHash $bound[0].message.params)-ne(Get-TsfContractJsonHash $rawPayload)){throw 'Adapter native effort event is not bound to the event journal.'}
        if([string]$nativeEvent.thread_id-ne[string]$adapter.thread_id){throw 'Adapter native effort event thread binding mismatch.'}
        if(![string]::IsNullOrWhiteSpace([string]$nativeEvent.turn_id)-and[string]$nativeEvent.turn_id-ne[string]$adapter.turn_id){throw 'Adapter native effort event turn binding mismatch.'}
    }
    $presHash=(Get-FileHash $presPath -Algorithm SHA256).Hash.ToLowerInvariant();if([string]$preservation.mission_id -ne [string]$Mission.mission_id){throw 'Preservation mission binding mismatch.'};if($presDescriptor.layout-eq'COMPACT_V1' -and ([string]$presDescriptor.manifest.run_id-ne[string]$RuntimeEvidence.result_id-or[string]$presDescriptor.manifest.policy_fingerprint-ne[string]$Mission.policy.fingerprint-or[string]$presDescriptor.manifest.mission_content_hash-ne[string]$translation.source_binding.durable_mission_content_hash)){throw 'Compact preservation manifest producer binding mismatch.'}
    $effortEvidence=Get-TsfEffortEvidence -Mission $Mission -Adapter $adapter
    $usageEvidence=$adapter.turn_usage
    if($null-eq$usageEvidence){throw 'Adapter usage evidence is missing.'}
    if([string]$usageEvidence.evidence_classification-eq'NATIVE_OBSERVED'){
        $selected=@($journalEntries|Where-Object{[int]$_.sequence-eq[int]$usageEvidence.selected_sequence-and[string]$_.direction-eq'server_to_client'-and[string]$_.message.method-eq'thread/tokenUsage/updated'})
        if($selected.Count-ne1-or[string]$selected[0].message.params.threadId-ne[string]$adapter.thread_id-or[string]$selected[0].message.params.turnId-ne[string]$adapter.turn_id){throw 'Adapter usage evidence is not bound to the native thread and turn.'}
        $raw=($selected[0].message.params|ConvertTo-Json -Compress -Depth 100)
        if((Get-TsfRawTextSha256 $raw)-ne[string]$usageEvidence.raw_payload_sha256){throw 'Adapter usage evidence raw payload hash mismatch.'}
    }elseif([string]$usageEvidence.status-ne'NOT_EXPOSED'-or[string]$usageEvidence.evidence_classification-ne'UNVERIFIED'){throw 'Unavailable usage evidence was promoted without a native observation.'}
    $artifacts=@();foreach($claim in @($Mission.required_artifacts)){$path=[string]$claim.path;$scopes=if(@($Mission.allowed_writes).Count){@($Mission.allowed_writes)}else{@($Mission.allowed_reads)};if(!(Test-TsfKernelPathContained $path $repo $scopes)){throw "Unsafe artifact path: $path"};$full=Get-TsfKernelFullPath $path $repo;$exists=Test-Path -LiteralPath $full -PathType Leaf;$artifacts+=[pscustomobject]@{path=$path;sha256=if($exists){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null};exists=$exists;evidence_classification='FILESYSTEM_OBSERVED'}}
    $tests=@($worker.tests|ForEach-Object{[pscustomobject]@{test_id=[string]$_.test_id;status=[string]$_.status;observed=[string]$_.observed;evidence=[string]$_.evidence;evidence_classification='KERNEL_OBSERVED'}})
    $approvals=@($worker.approval_use|ForEach-Object{[pscustomobject]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;used=[bool]$_.used;evidence_classification='KERNEL_OBSERVED'}})
    $verifier=@([pscustomobject]@{verifier_id='canonical-kernel-postrun';verifier_role='verifier_worker';independence=[string]$Mission.required_verifier_independence;passed=[bool]$verifierResult.verified;evidence=(Get-FileHash ([string]$RuntimeEvidence.verifier_result_path) -Algorithm SHA256).Hash.ToLowerInvariant();evidence_classification='VERIFIER_OBSERVED'})
    $effortBinding=if($effortEvidence.effective_effort-eq'UNKNOWN'){'UNVERIFIED'}else{'ADAPTER_OBSERVED'};$effortUncertainty=@();if($effortEvidence.effective_effort-eq'UNKNOWN'){$effortUncertainty=@('Stable app-server protocol did not expose an authoritative effective turn effort.')};$effortWarnings=@($effortEvidence.effort_conflicts)
    $mapped=[pscustomobject][ordered]@{schema_version=$script:ResultSchemaVersion;result_id=[string]$RuntimeEvidence.result_id;mission_id=[string]$Mission.mission_id;mission_revision=[int]$Mission.mission_revision;mission_content_hash=[string]$translation.source_binding.durable_mission_content_hash;parent_mission_id=$Mission.parent_mission_id;policy_fingerprint=[string]$Mission.policy.fingerprint;surface_used='CODEX_APP_SERVER';surface_task_identity=[string]$adapter.thread_id;actual_model=[string]$adapter.observed_model;actual_reasoning_effort=[string]$effortEvidence.effective_effort;model_assurance_level='ADAPTER_VERIFIED';effort_evidence=$effortEvidence;usage_evidence=$usageEvidence;actual_repository=$repo;actual_branch_worktree=[pscustomobject]@{branch=$git.branch;worktree=$repo};git_facts=[pscustomobject]@{starting_head=$RuntimeEvidence.starting_head;ending_head=$git.head;base_head=$RuntimeEvidence.base_head;dirty_before=$RuntimeEvidence.dirty_before;dirty_after=$git.dirty};files_inspected=@();files_changed=@($worker.files_touched);major_actions=@('Bound foreground Codex app-server turn completed.');network_activity=[pscustomobject]@{status='ADAPTER_VERIFIED';used=$false;destinations=@();control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';codex_service_connection_used=$true;direct_openai_api_called_by_tsf=$false;external_api_called=$false;worker_network_used=$false};artifacts=$artifacts;tests=$tests;verifier_evidence=$verifier;approval_use=$approvals;preservation_evidence=[pscustomobject]@{packet_path=$presPath;packet_sha256=$presHash;evidence_classification='KERNEL_OBSERVED'};evidence_bindings=[pscustomobject]@{mapper_version=$script:ResultMapperVersion;runtime_evidence_sha256=Get-TsfContractJsonHash $RuntimeEvidence;repository='FILESYSTEM_OBSERVED';git='KERNEL_OBSERVED';model='ADAPTER_OBSERVED';effort=$effortBinding;usage=[string]$usageEvidence.evidence_classification;files='FILESYSTEM_OBSERVED';native='NATIVE_OBSERVED';adapter='ADAPTER_OBSERVED';kernel='KERNEL_OBSERVED';verifier='VERIFIER_OBSERVED';preservation='KERNEL_OBSERVED'};deviations_from_mission=@();uncertainty=$effortUncertainty;security_or_scope_warnings=$effortWarnings;proposed_next_action=[string]$RuntimeEvidence.proposed_next_action;authority_statement='Observed evidence only; grants no approval, merge, or production authority.';grants_approval=$false;grants_merge_authority=$false;grants_production_authority=$false;created_at=[string]$RuntimeEvidence.created_at}
    $mappedValidation=Test-TsfResultEnvelope $mapped;if(!$mappedValidation.valid){throw "Mapped result violates canonical schema: $($mappedValidation.errors -join '; ')"};return $mapped
}

function Test-TsfCanonicalRelativePath { param([string]$Path,[string]$Repo,[object[]]$Scopes) return Test-TsfKernelPathContained -RelativePath $Path -RepositoryRoot $Repo -AllowedScopes $Scopes }
function Get-TsfAdmissionQueueTarget { param([string]$Status) if($Status -in @('ADMITTED','ADMITTED_WITH_CAVEATS')){return 'complete_ready_for_gate'};if($Status -eq 'TIM_REQUIRED'){return 'blocked_needs_tim'};return 'complete_review_only' }
function Get-TsfAdmissionStorage {
    param($Result,[string]$ResultHash,[string]$PreservationPacketPath,[string]$PreservationHash)
    Get-TsfRuntimeReceiptPlan -Result $Result -ResultHash $ResultHash -PreservationPacketPath $PreservationPacketPath -PreservationHash $PreservationHash
}

function Write-TsfAtomicJson {
    param($Value,[string]$FinalPath,[string]$TemporaryPath,[string]$BackupPath='',[switch]$NoReplace)
    $parent=Split-Path -Parent $FinalPath
    New-Item -ItemType Directory -Force -Path $parent|Out-Null
    if(Test-Path -LiteralPath $TemporaryPath){Remove-Item -LiteralPath $TemporaryPath -Force}
    Write-TsfKernelJson $Value $TemporaryPath
    $parsed=Read-TsfKernelJson $TemporaryPath
    if((Get-TsfContractJsonHash $parsed)-ne(Get-TsfContractJsonHash $Value)){throw 'Staged receipt parse/hash verification failed.'}
    if(Test-Path -LiteralPath $FinalPath){
        if($NoReplace){throw "Immutable receipt already exists: $FinalPath"}
        if([string]::IsNullOrWhiteSpace($BackupPath)){throw 'Atomic receipt replacement requires a precomputed backup path.'}
        if(Test-Path -LiteralPath $BackupPath){Remove-Item -LiteralPath $BackupPath -Force}
        [IO.File]::Replace($TemporaryPath,$FinalPath,$BackupPath)
    }else{
        Move-Item -LiteralPath $TemporaryPath -Destination $FinalPath
    }
    if(!(Test-Path -LiteralPath $FinalPath -PathType Leaf)){throw "Receipt finalization failed: $FinalPath"}
    if($BackupPath-and(Test-Path -LiteralPath $BackupPath)){Remove-Item -LiteralPath $BackupPath -Force}
    (Get-FileHash -LiteralPath $FinalPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function New-TsfAdmissionReceipt {
    param($Result,[string]$Hash,[string]$Status,$Reasons,$Caveats,$Now,[string]$From,[string]$To,[bool]$Applied,[string]$Transition,$Storage,[string]$PreservationHash)
    $decision=[pscustomobject][ordered]@{result_sha256=$Hash;status=$Status;reasons=@($Reasons);caveats=@($Caveats);queue_state_from=$From;queue_state_to=$To;queue_transition_path=$Transition}
    [pscustomobject][ordered]@{
        schema_version=$script:AdmissionSchemaVersion
        receipt_id="admission-$($Storage.key.Substring(0,24))"
        result_id=[string]$Result.result_id
        mission_id=[string]$Result.mission_id
        mission_revision=[int]$Result.mission_revision
        policy_fingerprint=[string]$Result.policy_fingerprint
        preservation_packet_sha256=$PreservationHash
        receipt_identity_sha256=[string]$Storage.identity_sha256
        admission_decision_sha256=Get-TsfContractJsonHash $decision
        admission_receipt_path=[string]$Storage.admission
        transaction_receipt_path=[string]$Storage.transaction
        result_sha256=$Hash
        status=$Status
        reasons=@($Reasons)
        caveats=@($Caveats)
        duplicate_submission=$false
        idempotent_replay=$false
        decided_at=$Now.ToUniversalTime().ToString('o')
        queue_state_from=$From
        queue_state_to=$To
        queue_transition_applied=$Applied
        queue_transition_path=$Transition
        grants_approval=$false
        grants_merge_authority=$false
        grants_production_authority=$false
    }
}

function New-TsfAdmissionTransaction {
    param($Receipt,$Storage,[string]$State,[string]$SourcePath,[string]$DestinationPath,[string]$AdmissionHash,$Now,$History)
    [pscustomobject][ordered]@{
        schema_version='tsf_admission_transaction_v1'
        transaction_id="transaction-$($Storage.key.Substring(0,24))"
        receipt_identity_sha256=[string]$Storage.identity_sha256
        state=$State
        mission_id=[string]$Receipt.mission_id
        mission_revision=[int]$Receipt.mission_revision
        result_id=[string]$Receipt.result_id
        result_sha256=[string]$Receipt.result_sha256
        policy_fingerprint=[string]$Receipt.policy_fingerprint
        preservation_packet_sha256=[string]$Receipt.preservation_packet_sha256
        admission_receipt_path=[string]$Storage.admission
        admission_receipt_sha256=$AdmissionHash
        queue_state_from='postrun_pending'
        queue_state_to=[string]$Receipt.queue_state_to
        source_path=$SourcePath
        destination_path=$DestinationPath
        history=@($History)
        updated_at=$Now.ToUniversalTime().ToString('o')
    }
}

function Get-TsfAdmissionDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultPath,
        [Parameter(Mandatory)][string]$MissionRegistryPath,
        [Parameter(Mandatory)][string]$ActivePolicyManifestPath,
        [Parameter(Mandatory)][string]$ApprovalLedgerPath,
        [Parameter(Mandatory)][string]$QueueMissionPath,
        [Parameter(Mandatory)][string]$QueueRootPath,
        [datetimeoffset]$CurrentTime=[datetimeoffset]::UtcNow,
        [switch]$UnsupportedDevelopmentMode,
        [ValidateSet('NONE','TEMP_WRITE','QUEUE_TRANSITION','FINALIZE_ADMISSION','FINALIZE_TRANSACTION')][string]$TestFault='NONE'
    )

    $result=Read-TsfKernelJson $ResultPath
    $resultHash=(Get-FileHash -LiteralPath $ResultPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $matches=@()
    Get-ChildItem -LiteralPath $MissionRegistryPath -Filter '*.json' -File -Recurse | Sort-Object FullName | ForEach-Object {
        try {$candidate=Read-TsfKernelJson $_.FullName;if([string]$candidate.mission_id -eq [string]$result.mission_id){$matches+=[pscustomobject]@{path=$_.FullName;mission=$candidate}}} catch {}
    }
    if([string]::IsNullOrWhiteSpace([string]$result.mission_id)-or$matches.Count-ne1){throw "Canonical durable mission lookup returned $($matches.Count) matches; exactly one is required."}
    $mission=$matches[0].mission
    $rv=Test-TsfResultEnvelope $result;$mv=Test-TsfMissionEnvelope $mission;if(!$rv.valid-or!$mv.valid){throw "Admission schema validation failed: $(@($rv.errors)+@($mv.errors)-join '; ')"}
    $translation=ConvertTo-TsfCanonicalExecutionArtifacts $mission
    $active=Get-TsfPolicyFingerprint $ActivePolicyManifestPath $script:TsfRoot -UnsupportedDevelopmentMode:$UnsupportedDevelopmentMode
    $status='ADMITTED';$reasons=[Collections.Generic.List[string]]::new();$caveats=[Collections.Generic.List[string]]::new()
    if($active.fingerprint-ne[string]$mission.policy.fingerprint-or[string]$result.policy_fingerprint-ne[string]$mission.policy.fingerprint){$status='REJECTED_POLICY_MISMATCH';$reasons.Add('Active, mission, and result policy fingerprints are not identical.')|Out-Null}
    if($status-eq'ADMITTED'-and([int]$result.mission_revision-ne[int]$mission.mission_revision-or[string]$result.mission_content_hash-ne(Get-TsfContractJsonHash $mission))){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Durable mission revision or content hash binding is invalid.')|Out-Null}
    if([bool]$result.grants_approval-or[bool]$result.grants_merge_authority-or[bool]$result.grants_production_authority){$status='TIM_REQUIRED';$reasons.Add('Result attempted to grant authority.')|Out-Null}

    $presPath=Get-TsfKernelFullPath ([string]$result.preservation_evidence.packet_path)
    if(!(Test-Path -LiteralPath $presPath -PathType Leaf)-or(Get-FileHash -LiteralPath $presPath -Algorithm SHA256).Hash.ToLowerInvariant()-ne[string]$result.preservation_evidence.packet_sha256){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Preservation packet observation or hash is invalid.')|Out-Null}
    $preservation=if(Test-Path -LiteralPath $presPath -PathType Leaf){Read-TsfKernelJson $presPath}else{$null}
    if($null-eq$preservation-or[string]$preservation.mission_id-ne[string]$mission.mission_id){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Preservation packet mission binding is invalid.')|Out-Null}
    $storage=Get-TsfAdmissionStorage $result $resultHash $presPath ([string]$result.preservation_evidence.packet_sha256)
    if($TestFault-ne'NONE'){
        $fixtureRoot=Get-TsfKernelFullPath (Join-Path $script:TsfRoot '.codex-local\fixtures')
        if(!$UnsupportedDevelopmentMode-or![string]$result.mission_id.StartsWith('synthetic-')-or!(Test-TsfKernelPathInside (Get-TsfKernelFullPath $QueueRootPath) $fixtureRoot)){throw 'Admission test faults are restricted to synthetic .codex-local fixtures in unsupported development mode.'}
    }
    if(Test-Path -LiteralPath $storage.admission){
        $old=Read-TsfKernelJson $storage.admission
        if([string]$old.receipt_identity_sha256-ne[string]$storage.identity_sha256){throw 'Admission receipt short-key collision detected.'}
        if([string]$old.result_sha256-eq$resultHash){
            if(!(Test-Path -LiteralPath $storage.transaction)){throw 'Admission receipt exists without its mandatory transaction receipt.'}
            $transaction=Read-TsfKernelJson $storage.transaction
            if([string]$transaction.receipt_identity_sha256-ne[string]$storage.identity_sha256){throw 'Transaction receipt short-key collision detected.'}
            if([string]$transaction.state-ne'COMMITTED'){
                if([string]$transaction.state-notin@('PREPARED','RECOVERY_REQUIRED')-or!(Test-Path -LiteralPath ([string]$old.queue_transition_path))){throw "Admission transaction requires reconciliation: $($transaction.state)"}
                $history=[Collections.Generic.List[object]]::new();foreach($event in @($transaction.history)){$history.Add($event)|Out-Null};$history.Add([pscustomobject]@{state='COMMITTED';at=$CurrentTime.ToUniversalTime().ToString('o');detail='Idempotent retry reconciled an advanced queue record with its preserved admission receipt.'})|Out-Null
                $transaction=New-TsfAdmissionTransaction $old $storage 'COMMITTED' ([string]$transaction.source_path) ([string]$transaction.destination_path) ((Get-FileHash -LiteralPath $storage.admission -Algorithm SHA256).Hash.ToLowerInvariant()) $CurrentTime $history
                Write-TsfAtomicJson $transaction $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null
            }
            $old.duplicate_submission=$true;$old.idempotent_replay=$true;return $old
        }
        $conflictLeaf=[IO.Path]::GetFileNameWithoutExtension([string]$storage.conflict)
        $conflict=[pscustomobject][ordered]@{schema_version='tsf_admission_conflict_v1';conflict_id="conflict-$($conflictLeaf.Substring(2,24))";receipt_identity_sha256=[string]$storage.identity_sha256;conflict_identity_sha256=[string]$storage.conflict_identity_sha256;mission_id=[string]$result.mission_id;mission_revision=[int]$result.mission_revision;result_id=[string]$result.result_id;original_result_sha256=[string]$old.result_sha256;conflicting_result_sha256=$resultHash;original_admission_receipt_path=[string]$storage.admission;original_admission_receipt_sha256=(Get-FileHash -LiteralPath $storage.admission -Algorithm SHA256).Hash.ToLowerInvariant();conflict_receipt_path=[string]$storage.conflict;status='REJECTED_INVALID_EVIDENCE';reason='result_id was reused with different content; original receipt preserved.';recorded_at=$CurrentTime.ToUniversalTime().ToString('o')}
        if(Test-Path -LiteralPath $storage.conflict){$existing=Read-TsfKernelJson $storage.conflict;if([string]$existing.conflicting_result_sha256-ne$resultHash-or[string]$existing.conflict_identity_sha256-ne[string]$storage.conflict_identity_sha256){throw 'Admission conflict short-key collision detected.'}}else{Write-TsfAtomicJson $conflict $storage.conflict $storage.admission_temp -NoReplace|Out-Null}
        return $conflict
    }
    if(!$storage.durable_result_bound){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Compact preservation manifest does not bind the submitted durable-result bytes.')|Out-Null}

    $queueDocument=Read-TsfKernelJson $QueueMissionPath;$queueCheck=Test-TsfCanonicalQueueDocument $queueDocument $mission;if(!$queueCheck.valid){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Queue record is not the canonical durable translation: $($queueCheck.errors -join '; ')")|Out-Null}
    $repo=[string]$translation.mission_packet.repo_path;$git=Get-TsfKernelGitState $repo
    if(!$git.can_capture-or![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_repository)).TrimEnd('\','/'),$repo.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Observed repository identity is unavailable or mismatched.')|Out-Null}
    if($status-eq'ADMITTED'-and[bool]$mission.branch_worktree_policy.branch_required-and[string]$result.actual_branch_worktree.branch-ne[string]$mission.branch_worktree_policy.expected_branch){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed branch violates durable mission policy.')|Out-Null}
    if($status-eq'ADMITTED'-and[bool]$mission.branch_worktree_policy.worktree_required-and![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_branch_worktree.worktree)).TrimEnd('\','/'),(Get-TsfKernelFullPath ([string]$mission.branch_worktree_policy.expected_worktree)).TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed worktree violates durable mission policy.')|Out-Null}
    if($status-eq'ADMITTED'){foreach($p in @($result.files_changed)){if(!(Test-TsfKernelPathContained $p $repo @($mission.allowed_writes))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Changed path is outside canonical allowed_writes: $p")|Out-Null;break}}}
    if($status-eq'ADMITTED'){foreach($p in @($result.files_inspected)){if(!(Test-TsfKernelPathContained $p $repo @($mission.allowed_reads))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Inspected path is outside canonical allowed_reads: $p")|Out-Null;break}}}
    if($status-eq'ADMITTED'-and([string]$result.network_activity.control_plane_service_network_policy-ne[string]$mission.control_plane_service_network_policy-or[string]$result.network_activity.worker_tool_network_policy-ne'DISABLED'-or[bool]$result.network_activity.worker_network_used-or[bool]$result.network_activity.direct_openai_api_called_by_tsf-or[bool]$result.network_activity.external_api_called)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed network policy evidence violates the durable mission.')|Out-Null}
    if($status-eq'ADMITTED'){foreach($a in @($result.artifacts)){$scopes=if(@($mission.allowed_writes).Count){@($mission.allowed_writes)}else{@($mission.allowed_reads)};if($a.evidence_classification-ne'FILESYSTEM_OBSERVED'-or!(Test-TsfKernelPathContained $a.path $repo $scopes)){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact is not filesystem-bound: $($a.path)")|Out-Null;break};$full=Get-TsfKernelFullPath $a.path $repo;$observed=if(Test-Path $full -PathType Leaf){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{''};if($observed-ne[string]$a.sha256){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact hash mismatch: $($a.path)")|Out-Null;break}}}
    if($status-eq'ADMITTED'){foreach($t in @($mission.required_tests|Where-Object{$_.required})){if(@($result.tests|Where-Object{$_.test_id-eq$t.test_id-and$_.status-eq'PASS'-and$_.evidence_classification-eq'KERNEL_OBSERVED'}).Count-ne1){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Required observed test is missing: $($t.test_id)")|Out-Null;break}}}
    if($status-eq'ADMITTED'-and![string]::IsNullOrWhiteSpace([string]$mission.expires_at)-and$CurrentTime-gt[datetimeoffset]::Parse([string]$mission.expires_at)){$status=if($mission.stale_state_behavior-eq'TIM_REQUIRED'){'TIM_REQUIRED'}elseif($mission.stale_state_behavior-eq'REJECT'){'REJECTED_INVALID_EVIDENCE'}else{'REVIEW_REQUIRED'};$reasons.Add('Durable mission expired before admission.')|Out-Null}

    $required=@($mission.approval_references);$used=@($result.approval_use|Where-Object{$_.used})
    if($required.Count-ne$used.Count){$status='TIM_REQUIRED';$reasons.Add('Every required approval must have exactly one observed use record.')|Out-Null}
    if($required.Count-or$used.Count){try{$ledger=Get-TsfKernelApprovalLedger $ApprovalLedgerPath;$native=@(Find-TsfKernelApprovalMatches $translation.mission_packet $ledger $ApprovalLedgerPath -CurrentTime $CurrentTime -RequireCanonicalUsageBinding);foreach($r in $required){$u=@($used|Where-Object{$_.approval_id-eq$r.approval_id-and$_.exact_action-eq$r.exact_action});$m=@($native|Where-Object{$_.approval_id-eq$r.approval_id-and$_.exact_action-eq$r.exact_action-and$_.satisfied});if($u.Count-ne1-or$m.Count-ne1){$status='TIM_REQUIRED';$reasons.Add("Approval failed canonical resolution: $($r.approval_id)")|Out-Null}};$status='TIM_REQUIRED';$reasons.Add('Safe approval consumption is not implemented; approval-requiring missions fail closed.')|Out-Null}catch{$status='TIM_REQUIRED';$reasons.Add($_.Exception.Message)|Out-Null}}
    if($status-eq'ADMITTED'-and[string]$mission.required_verifier_independence-ne'NONE'-and@($result.verifier_evidence|Where-Object{$_.independence-eq$mission.required_verifier_independence-and$_.passed-and$_.evidence_classification-eq'VERIFIER_OBSERVED'}).Count-ne1){$status='REVIEW_REQUIRED';$reasons.Add('Canonical independent verifier evidence is missing.')|Out-Null}
    if($status-eq'ADMITTED'-and([string]$result.actual_model-ne[string]$translation.model_resolution.resolved_model-or[string]$result.model_assurance_level-ne'ADAPTER_VERIFIED')){$status='REVIEW_REQUIRED';$reasons.Add('Observed model does not match the canonical adapter-bound resolution.')|Out-Null}
    if($status-eq'ADMITTED'){
        $effortEffect=[string]$result.effort_evidence.effort_admission_effect
        if($effortEffect-ne'ADMITTED'){$status=$effortEffect}
        if($effortEffect-eq'ADMITTED_WITH_CAVEATS'){$caveats.Add('Effective turn effort was not exposed; the correct explicit turn request is admitted under RECOMMENDED_ONLY assurance.')|Out-Null}
        elseif($effortEffect-ne'ADMITTED'){$reasons.Add("Effort evidence admission effect: $effortEffect")|Out-Null}
        foreach($conflict in @($result.effort_evidence.effort_conflicts)){$caveats.Add([string]$conflict)|Out-Null}
    }

    if($reasons.Count-eq0){$reasons.Add('Observed runtime evidence satisfied the canonical durable mission.')|Out-Null}
    $target=Get-TsfAdmissionQueueTarget $status
    $dryRun=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $QueueMissionPath -FromState 'postrun_pending' -ToState $target -QueueRoot $QueueRootPath -DryRun
    if([string]$dryRun.verdict-ne'GREEN'){throw "Canonical queue transition preflight failed: $($dryRun.blocked_reasons -join '; ')"}
    $receipt=New-TsfAdmissionReceipt $result $resultHash $status @($reasons) @($caveats) $CurrentTime 'postrun_pending' $target $true ([string]$dryRun.destination_path) $storage ([string]$result.preservation_evidence.packet_sha256)
    $receiptValidation=Test-TsfJsonContract $receipt (Join-Path $script:TsfRoot 'fleet\control\admission-decision.schema.v1.json')
    if(!$receiptValidation.valid){throw "Prepared admission receipt violates schema: $($receiptValidation.errors -join '; ')"}
    $history=[Collections.Generic.List[object]]::new();$history.Add([pscustomobject]@{state='PREPARED';at=$CurrentTime.ToUniversalTime().ToString('o');detail='Receipt staged and queue transition preflight passed.'})|Out-Null
    $moved=$false;$admissionFinalized=$false
    try{
        New-Item -ItemType Directory -Force -Path $storage.root|Out-Null
        if($TestFault-eq'TEMP_WRITE'){throw 'Simulated temporary receipt write failure.'}
        Write-TsfKernelJson $receipt $storage.admission_temp
        $staged=Read-TsfKernelJson $storage.admission_temp
        if((Get-TsfContractJsonHash $staged)-ne(Get-TsfContractJsonHash $receipt)){throw 'Staged admission receipt failed parse/hash verification.'}
        $stagedHash=(Get-FileHash -LiteralPath $storage.admission_temp -Algorithm SHA256).Hash.ToLowerInvariant()
        $transaction=New-TsfAdmissionTransaction $receipt $storage 'PREPARED' ([string]$dryRun.mission_path) ([string]$dryRun.destination_path) $stagedHash $CurrentTime $history
        Write-TsfAtomicJson $transaction $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null
        if($TestFault-eq'QUEUE_TRANSITION'){throw 'Simulated queue transition failure.'}
        $transition=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $QueueMissionPath -FromState 'postrun_pending' -ToState $target -QueueRoot $QueueRootPath
        if([string]$transition.verdict-ne'GREEN'){throw "Canonical queue transition failed: $($transition.blocked_reasons -join '; ')"}
        $moved=$true
        if($TestFault-eq'FINALIZE_ADMISSION'){throw 'Simulated final admission receipt rename failure.'}
        Move-Item -LiteralPath $storage.admission_temp -Destination $storage.admission
        $admissionFinalized=$true
        $admissionHash=(Get-FileHash -LiteralPath $storage.admission -Algorithm SHA256).Hash.ToLowerInvariant()
        $history.Add([pscustomobject]@{state='QUEUE_MOVED';at=[datetimeoffset]::UtcNow.ToString('o');detail=[string]$transition.destination_path})|Out-Null
        $history.Add([pscustomobject]@{state='COMMITTED';at=[datetimeoffset]::UtcNow.ToString('o');detail='Admission and queue state verified.'})|Out-Null
        $transaction=New-TsfAdmissionTransaction $receipt $storage 'COMMITTED' ([string]$transition.mission_path) ([string]$transition.destination_path) $admissionHash ([datetimeoffset]::UtcNow) $history
        if($TestFault-eq'FINALIZE_TRANSACTION'){throw 'Simulated final transaction receipt write failure.'}
        Write-TsfAtomicJson $transaction $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null
        $committed=Read-TsfKernelJson $storage.transaction
        if([string]$committed.state-ne'COMMITTED'-or!(Test-Path -LiteralPath $storage.admission)){throw 'Admission transaction did not durably commit.'}
        return $receipt
    }catch{
        $failure=$_.Exception.Message
        if($moved-and!$admissionFinalized){
            try{
                $rollback=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath ([string]$dryRun.destination_path) -FromState $target -ToState 'postrun_pending' -QueueRoot $QueueRootPath -RecoveryTransactionPath $storage.transaction
                if([string]$rollback.verdict-ne'GREEN'){throw ($rollback.blocked_reasons -join '; ')}
                $history.Add([pscustomobject]@{state='ROLLED_BACK';at=[datetimeoffset]::UtcNow.ToString('o');detail=$failure})|Out-Null
                $rolled=New-TsfAdmissionTransaction $receipt $storage 'ROLLED_BACK' ([string]$dryRun.mission_path) ([string]$dryRun.destination_path) '' ([datetimeoffset]::UtcNow) $history
                Write-TsfAtomicJson $rolled $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null
            }catch{
                $history.Add([pscustomobject]@{state='RECOVERY_REQUIRED';at=[datetimeoffset]::UtcNow.ToString('o');detail="$failure | rollback failed: $($_.Exception.Message)"})|Out-Null
                $recovery=New-TsfAdmissionTransaction $receipt $storage 'RECOVERY_REQUIRED' ([string]$dryRun.mission_path) ([string]$dryRun.destination_path) '' ([datetimeoffset]::UtcNow) $history
                try{Write-TsfAtomicJson $recovery $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null}catch{}
            }
        }elseif(Test-Path -LiteralPath $storage.transaction){
            $state=if($moved){'RECOVERY_REQUIRED'}else{'ROLLED_BACK'}
            $history.Add([pscustomobject]@{state=$state;at=[datetimeoffset]::UtcNow.ToString('o');detail=$failure})|Out-Null
            $recoveryAdmissionHash=if($admissionFinalized){(Get-FileHash -LiteralPath $storage.admission -Algorithm SHA256).Hash.ToLowerInvariant()}else{''}
            $recovery=New-TsfAdmissionTransaction $receipt $storage $state ([string]$dryRun.mission_path) ([string]$dryRun.destination_path) $recoveryAdmissionHash ([datetimeoffset]::UtcNow) $history
            try{Write-TsfAtomicJson $recovery $storage.transaction $storage.transaction_temp $storage.transaction_backup|Out-Null}catch{}
        }
        throw $failure
    }
}
