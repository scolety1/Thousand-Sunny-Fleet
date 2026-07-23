$script:MissionSchemaVersion = "tsf_mission_envelope_v1"
$script:ResultSchemaVersion = "tsf_result_envelope_v1"
$script:AdmissionSchemaVersion = "tsf_admission_decision_v1"
$script:PolicyManifestVersion = "tsf_policy_manifest_v1"
$script:TranslatorVersion = "tsf_durable_to_operational_v1"
$script:ResultMapperVersion = "tsf_runtime_evidence_to_result_v1"
$script:EvidenceClasses = @("NATIVE_OBSERVED", "ADAPTER_OBSERVED", "KERNEL_OBSERVED", "FILESYSTEM_OBSERVED", "VERIFIER_OBSERVED", "AGENT_REPORTED", "UNVERIFIED")
$script:ExactResponseContractSchema = Join-Path $script:TsfRoot 'fleet\control\exact-literal-response-contract.schema.v1.json'

function Get-TsfExactResponseLiteralSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-TsfExactResponseLiteralFromRequest {
    param([Parameter(Mandatory)][string]$NaturalRequest)

    $patterns = @(
        '(?im)\b(?:return|respond\s+with)\s+exactly\s+([A-Z][A-Z0-9_]{0,127})(?=$|[\r\n]|[.!?])',
        '(?im)\b(?:required\s+)?exact\s+(?:response|literal)\s*:\s*([A-Z][A-Z0-9_]{0,127})(?=$|[\r\n]|[.!?])'
    )
    $literalMatches = [Collections.Generic.List[string]]::new()
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($NaturalRequest, $pattern)) {
            $literalMatches.Add([string]$match.Groups[1].Value) | Out-Null
        }
    }
    $explicitMarker = $NaturalRequest -match '(?im)\b(?:return|respond\s+with)\s+exactly\b|\b(?:required\s+)?exact\s+(?:response|literal)\s*:'
    if ($literalMatches.Count -eq 0) {
        if ($explicitMarker) { throw 'EXACT_LITERAL_UNSAFE_OR_AMBIGUOUS' }
        return $null
    }
    $unique = @($literalMatches | Sort-Object -Unique -CaseSensitive)
    if ($unique.Count -ne 1) { throw 'CONFLICTING_EXACT_LITERAL_REQUIREMENTS' }
    $literal = [string]$unique[0]
    if ($literal.Length -gt 128 -or $literal -cnotmatch '^[A-Z][A-Z0-9_]{0,127}$') { throw 'EXACT_LITERAL_SAFE_GRAMMAR_REJECTED' }
    return $literal
}

function New-TsfExactResponseContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NaturalRequest,
        [Parameter(Mandatory)][string]$PreviewId,
        [string]$PreviewArtifactSha256 = '',
        [string]$MissionId = '',
        [int]$MissionRevision = 0
    )

    $literal = Get-TsfExactResponseLiteralFromRequest -NaturalRequest $NaturalRequest
    if ($null -eq $literal) { return $null }
    if ($PreviewId -notmatch '^hq-preview-[a-f0-9]{32}$') { throw 'EXACT_LITERAL_PREVIEW_IDENTITY_INVALID' }
    if ($PreviewArtifactSha256 -and $PreviewArtifactSha256 -notmatch '^[a-f0-9]{64}$') { throw 'EXACT_LITERAL_PREVIEW_ARTIFACT_HASH_INVALID' }
    if (($MissionId -and ($MissionId -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or $MissionRevision -lt 1)) -or (!$MissionId -and $MissionRevision -ne 0)) { throw 'EXACT_LITERAL_MISSION_BINDING_INVALID' }

    $sourceRequestSha256 = Get-TsfExactResponseLiteralSha256 $NaturalRequest
    $literalSha256 = Get-TsfExactResponseLiteralSha256 $literal
    $semantic = [pscustomobject][ordered]@{
        validation_mode = 'EXACT_LITERAL_V1'
        normalization_version = 'ASCII_TOKEN_IDENTITY_V1'
        expected_literal = $literal
        expected_literal_sha256 = $literalSha256
        case_sensitive = $true
        whitespace_sensitive = $true
        executable_interpretation = $false
        source_requirement_kind = 'EXPLICIT_RETURN_EXACTLY_V1'
        source_request_sha256 = $sourceRequestSha256
    }
    $semanticSha256 = Get-TsfContractJsonHash $semantic
    $previewIdentity = [pscustomobject][ordered]@{
        preview_id = $PreviewId
        source_request_sha256 = $sourceRequestSha256
        semantic_contract_sha256 = $semanticSha256
    }
    [pscustomobject][ordered]@{
        schema_version = 'tsf_exact_literal_response_contract_v1'
        validation_mode = 'EXACT_LITERAL_V1'
        normalization_version = 'ASCII_TOKEN_IDENTITY_V1'
        expected_literal = $literal
        expected_literal_sha256 = $literalSha256
        semantic_contract_sha256 = $semanticSha256
        case_sensitive = $true
        whitespace_sensitive = $true
        executable_interpretation = $false
        source_requirement = [pscustomobject][ordered]@{
            kind = 'EXPLICIT_RETURN_EXACTLY_V1'
            request_sha256 = $sourceRequestSha256
            natural_request_persisted_in_preview = $false
        }
        preview_binding = [pscustomobject][ordered]@{
            preview_id = $PreviewId
            preview_contract_sha256 = Get-TsfContractJsonHash $previewIdentity
            preview_artifact_sha256 = $(if ($PreviewArtifactSha256) { $PreviewArtifactSha256 } else { $null })
        }
        mission_binding = [pscustomobject][ordered]@{
            mission_id = $(if ($MissionId) { $MissionId } else { $null })
            mission_revision = $(if ($MissionId) { $MissionRevision } else { $null })
        }
    }
}

function Test-TsfExactResponseContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][string]$NaturalRequest,
        [Parameter(Mandatory)][string]$PreviewId,
        [string]$PreviewArtifactSha256 = '',
        [string]$MissionId = '',
        [int]$MissionRevision = 0
    )
    $errors = [Collections.Generic.List[string]]::new()
    $schema = Test-TsfJsonContract $Contract $script:ExactResponseContractSchema
    foreach ($error in @($schema.errors)) { $errors.Add([string]$error) | Out-Null }
    try {
        $expected = New-TsfExactResponseContract -NaturalRequest $NaturalRequest -PreviewId $PreviewId -PreviewArtifactSha256 $PreviewArtifactSha256 -MissionId $MissionId -MissionRevision $MissionRevision
        if ($null -eq $expected) { $errors.Add('Natural request does not require an exact literal.') | Out-Null }
        elseif ((Get-TsfContractJsonHash $Contract) -ne (Get-TsfContractJsonHash $expected)) { $errors.Add('Exact-response contract differs from independent recomputation.') | Out-Null }
    } catch { $errors.Add($_.Exception.Message) | Out-Null }
    [pscustomobject]@{ valid = $errors.Count -eq 0; errors = @($errors) }
}

. (Join-Path $script:TsfRoot 'tools\TsfJsonContract.ps1')
function Test-TsfMissionEnvelope {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\mission-envelope.schema.v1.json'))
    $r=Test-TsfJsonContract $Mission $SchemaPath
    $semanticContractRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Get-TsfKernelFullPath $SchemaPath)))
    $errors=[Collections.Generic.List[string]]::new()
    foreach($error in @($r.errors)){$errors.Add([string]$error)|Out-Null}
    if($Mission.PSObject.Properties.Name-contains'exact_response_contract'-and$null-ne$Mission.exact_response_contract){
        $contract=$Mission.exact_response_contract
        $contractCheck=Test-TsfExactResponseContract -Contract $contract -NaturalRequest ([string]$Mission.original_request) -PreviewId ([string]$contract.preview_binding.preview_id) -PreviewArtifactSha256 ([string]$contract.preview_binding.preview_artifact_sha256) -MissionId ([string]$Mission.mission_id) -MissionRevision ([int]$Mission.mission_revision)
        foreach($error in @($contractCheck.errors)){$errors.Add([string]$error)|Out-Null}
        $testHashes=@($Mission.required_tests|Where-Object{[string]$_.command-match'^exact-response-sha256:([a-f0-9]{64})$'}|ForEach-Object{([string]$_.command).Substring('exact-response-sha256:'.Length)})
        if($testHashes.Count-ne1-or[string]$testHashes[0]-ne[string]$contract.expected_literal_sha256){$errors.Add('Mission exact-response required test differs from the canonical response contract.')|Out-Null}
    }
    if($Mission.PSObject.Properties.Name-contains'result_validation_mode'){
        if([string]$Mission.result_validation_mode-eq'GENERAL_RESULT_V2'){
            foreach($spec in @(
                [pscustomobject]@{value=$Mission.original_operator_intent;schema='original-operator-intent.schema.v1.json';name='original intent'},
                [pscustomobject]@{value=$Mission.scope_transformation;schema='scope-transformation.schema.v1.json';name='scope transformation'},
                [pscustomobject]@{value=$Mission.task_completion_contract;schema='task-completion-contract.schema.v1.json';name='task completion'}
            )){$check=Test-TsfJsonContract $spec.value (Join-Path $semanticContractRoot "fleet\control\$($spec.schema)");foreach($error in @($check.errors)){$errors.Add("Mission $($spec.name) contract: $error")|Out-Null}}
            if($null-eq$Mission.original_operator_intent-or$null-eq$Mission.scope_transformation-or$null-eq$Mission.task_completion_contract){$errors.Add('GENERAL_RESULT_V2 requires intent, scope, and task-completion contracts.')|Out-Null}
            elseif([string]$Mission.scope_transformation.original_intent_identity_sha256-ne[string]$Mission.original_operator_intent.original_intent_identity_sha256-or[string]$Mission.task_completion_contract.original_intent_identity_sha256-ne[string]$Mission.original_operator_intent.original_intent_identity_sha256-or[string]$Mission.task_completion_contract.scope_transformation_identity_sha256-ne[string]$Mission.scope_transformation.scope_transformation_identity_sha256){$errors.Add('Mission semantic contract identity chain is inconsistent.')|Out-Null}
            elseif(![bool]$Mission.scope_transformation.queue_allowed-or[bool]$Mission.scope_transformation.operator_confirmation_required){$errors.Add('Mission scope transformation is not queueable.')|Out-Null}
            $generalTests=@($Mission.required_tests|Where-Object{[string]$_.command-match'^general-result-v2:([a-f0-9]{64})$'})
            if($generalTests.Count-ne1-or[string]$generalTests[0].command-ne"general-result-v2:$([string]$Mission.task_completion_contract.task_completion_contract_identity_sha256)"){$errors.Add('Mission general-result required test differs from the task-completion contract.')|Out-Null}
        }elseif([string]$Mission.result_validation_mode-eq'EXACT_LITERAL_V1'-and$null-eq$Mission.exact_response_contract){$errors.Add('EXACT_LITERAL_V1 mission lacks its exact-response contract.')|Out-Null}
    }
    [pscustomobject]@{schema_version='tsf_mission_envelope_validation_v1';valid=$errors.Count-eq0;errors=@($errors);coverage=$r.coverage}
}
function Test-TsfResultEnvelope { [CmdletBinding()] param([Parameter(Mandatory)][object]$Result,[string]$SchemaPath=(Join-Path $script:TsfRoot 'fleet\control\result-envelope.schema.v1.json')) $r=Test-TsfJsonContract $Result $SchemaPath; [pscustomobject]@{schema_version='tsf_result_envelope_validation_v1';valid=$r.valid;errors=$r.errors;coverage=$r.coverage} }

function Invoke-TsfContractGit { param([string]$Root,[string[]]$Arguments) $safe=$Root.Replace('\','/'); $output=@(& git -c "safe.directory=$safe" -C $Root @Arguments 2>&1); if($LASTEXITCODE -ne 0){throw "git $($Arguments -join ' ') failed: $($output -join ' ')"}; return @($output) }

function Get-TsfPolicyFingerprint {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ManifestPath,[string]$RepositoryRoot=$script:TsfRoot,[switch]$UnsupportedDevelopmentMode)
    $root=(Invoke-TsfContractGit $RepositoryRoot @('rev-parse','--show-toplevel')|Select-Object -First 1).Trim(); $head=(Invoke-TsfContractGit $root @('rev-parse','HEAD^{commit}')|Select-Object -First 1).Trim()
    $manifestFull=Get-TsfKernelFullPath $ManifestPath $root; if(!(Test-TsfKernelPathInside $manifestFull $root)){throw 'Policy manifest escapes repository.'}
    $manifest=Read-TsfKernelJson $manifestFull; if([string]$manifest.schema_version -ne $script:PolicyManifestVersion){throw 'Unsupported policy manifest version.'}
    $required=@(
        'tools/TsfJsonContract.ps1','tools/TsfRuntimeArtifactAddressing.ps1','tools/TsfLifecycleTerminalResult.ps1','tools/TsfLifecycleInvocationArguments.ps1','tools/TsfSemanticIntegrity.ps1','tools/TsfDurableContract.psm1','tools/TsfDurableContract.Canonical.ps1',
        'tools/codex-fleet-enforcement-kernel.ps1','tools/Move-TsfMissionState.ps1',
        'tools/Invoke-TsfMissionQueueForegroundExecutor.ps1','tools/Invoke-TsfMissionLifecycle.ps1',
        'tools/codex-fleet-runtime.ps1','tools/Test-TsfWorkerRolePermission.ps1','tools/Invoke-TsfCodexAppServerForeground.ps1',
        'tools/tsf-codex-app-server-adapter.mjs','tools/Get-TsfAdmissionDecision.ps1','tools/Repair-TsfSyntheticAdmissionFixture.ps1','tools/New-TsfCanonicalQueueMission.ps1',
        'projects.json','fleet/control/mission-envelope.schema.v1.json','fleet/control/canonical-queue-document.schema.v1.json','fleet/control/original-operator-intent.schema.v1.json','fleet/control/scope-transformation.schema.v1.json','fleet/control/task-completion-contract.schema.v1.json','fleet/control/general-result-v2.schema.v1.json',
        'fleet/control/result-envelope.schema.v1.json','fleet/control/exact-literal-response-contract.schema.v1.json','fleet/control/lifecycle-terminal-result.schema.v1.json','fleet/control/tim-required-request.schema.v1.json','fleet/control/tim-required-response.schema.v1.json','fleet/control/executor-invocation-failure-result.schema.v1.json','fleet/control/mission-preparation-result.schema.v1.json','fleet/control/self-hosted-audit-recovery-policy.v1.json','fleet/control/runtime-artifact-manifest.schema.v1.json','fleet/control/producer-evidence-registry.schema.v1.json','fleet/control/canonical-recovery-envelope.schema.v1.json','fleet/control/admission-decision.schema.v1.json',
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
function Test-TsfCanonicalBranchWorktreeContract {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission)
    $errors=[Collections.Generic.List[string]]::new()
    $branchPolicy=$Mission.branch_worktree_policy
    if([bool]$branchPolicy.branch_required){
        if([string]::IsNullOrWhiteSpace([string]$branchPolicy.expected_branch)){$errors.Add('A branch-required mission must bind one exact attached branch.')|Out-Null}
    }else{
        if($null-ne$branchPolicy.expected_branch){$errors.Add('A branch-not-applicable mission must represent expected_branch as null.')|Out-Null}
        if([string]$Mission.permission_mode-ne'READ_ONLY'-or@($Mission.allowed_writes).Count-ne0){$errors.Add('Detached workspace writes are unsafe; an attached approved branch is required.')|Out-Null}
        if(![bool]$branchPolicy.worktree_required-or[string]::IsNullOrWhiteSpace([string]$branchPolicy.expected_worktree)){$errors.Add('A detached read-only mission must bind one exact worktree.')|Out-Null}
        if([string]$branchPolicy.starting_head-notmatch'^[a-f0-9]{40,64}$'){$errors.Add('A detached read-only mission must bind one exact immutable HEAD commit.')|Out-Null}
        if([string]$Mission.worker_tool_network_policy-ne'DISABLED'){$errors.Add('A detached read-only mission must keep worker-tool network disabled.')|Out-Null}
    }
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors)}
}
function ConvertTo-TsfCanonicalExecutionArtifacts {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[string]$RepositoryRoot=$script:TsfRoot)
    $contractRoot=Get-TsfKernelFullPath $RepositoryRoot
    $translatorVersion='tsf_durable_to_operational_v1'
    $validation=Test-TsfMissionEnvelope $Mission (Join-Path $contractRoot 'fleet\control\mission-envelope.schema.v1.json'); if(!$validation.valid){throw "Invalid durable mission: $($validation.errors -join '; ')"}
    $branchContract=Test-TsfCanonicalBranchWorktreeContract $Mission; if(!$branchContract.valid){throw "Invalid canonical branch/worktree contract: $($branchContract.errors -join '; ')"}
    $roles=Read-TsfKernelJson (Join-Path $contractRoot 'fleet\control\worker-role-registry.v1.json'); $role=@($roles.roles|Where-Object{[string]$_.role_id -eq [string]$Mission.worker_role}); if($role.Count -ne 1){throw 'Worker role is absent or ambiguous in canonical registry.'}
    $profiles=Read-TsfKernelJson (Join-Path $contractRoot 'fleet\control\worker-permission-profiles.v1.json'); if(!(Test-TsfContractProperty $profiles.profiles ([string]$Mission.worker_role))){throw 'Permission profile is absent from canonical registry.'}; $profile=$profiles.profiles.([string]$Mission.worker_role)
    if(@($Mission.allowed_writes).Count -gt 0 -and ![bool]$profile.may_commit_locally){throw 'Durable writes conflict with canonical permission profile.'}
    $routing=Resolve-TsfModelRouting ([string]$Mission.model_policy_alias) ([string]$Mission.recommended_surface) (Join-Path $contractRoot 'fleet\control\model-routing-alias-policy.v1.json'); if([string]$Mission.resolved_model -and [string]$Mission.resolved_model -ne $routing.resolved_model){throw 'Durable resolved_model conflicts with canonical model routing.'};if([string]$Mission.reasoning_effort -ne [string]$routing.reasoning_effort){throw 'Durable reasoning_effort conflicts with canonical model routing.'}
    $repo=Resolve-TsfDurableRepository $Mission $RepositoryRoot; $forbidden=ConvertTo-TsfOperationalForbiddenActions (@($Mission.forbidden_actions)+@($profile.mandatory_forbidden_actions))
    $stops=@(); $n=0; foreach($text in @($Mission.stop_conditions)){$n++;$stops+=[pscustomobject]@{id=('durable-stop-{0:d3}' -f $n);check_type='manual';description=[string]$text}}
    $approvals=@()
    if($Mission.PSObject.Properties.Name-contains'approval_requirements'){
        $approvals+=@($Mission.approval_requirements|ForEach-Object{[pscustomobject]@{exact_action=[string]$_.exact_action;required=$true;reason=[string]$_.reason}})
    }
    $approvals+=@($Mission.approval_references|ForEach-Object{
        $item=[ordered]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;required=$true;reason='Required by canonical durable mission.'}
        foreach($name in @('request_id','request_evidence_sha256','source_mission_revision','source_run_id','source_result_id','response_id')){if($_.PSObject.Properties.Name-contains$name){$item[$name]=$_.$name}}
        [pscustomobject]$item
    })
    $clarifications=@();if($Mission.PSObject.Properties.Name-contains'clarification_requirements'){$clarifications=@($Mission.clarification_requirements)}
    $packetFields=[ordered]@{mission_id=[string]$Mission.mission_id;project_id=[string]$Mission.project_id;repo_path=$repo;lane='MASTER_TSF_CONTROL_PLANE';mission_type='tsf_infrastructure';exact_response_contract=if($Mission.PSObject.Properties.Name-contains'exact_response_contract'){$Mission.exact_response_contract}else{$null};result_validation_mode=if($Mission.PSObject.Properties.Name-contains'result_validation_mode'){[string]$Mission.result_validation_mode}else{$null};original_operator_intent=if($Mission.PSObject.Properties.Name-contains'original_operator_intent'){$Mission.original_operator_intent}else{$null};scope_transformation=if($Mission.PSObject.Properties.Name-contains'scope_transformation'){$Mission.scope_transformation}else{$null};task_completion_contract=if($Mission.PSObject.Properties.Name-contains'task_completion_contract'){$Mission.task_completion_contract}else{$null}}
    if([bool]$Mission.branch_worktree_policy.branch_required){$packetFields.required_branch=[string]$Mission.branch_worktree_policy.expected_branch}
    $packetFields.required_worktree=[string]$Mission.branch_worktree_policy.expected_worktree
    $packetFields.control_plane_service_network_policy=[string]$Mission.control_plane_service_network_policy
    $packetFields.worker_tool_network_policy=[string]$Mission.worker_tool_network_policy
    $packetFields.allowed_reads=@($Mission.allowed_reads);$packetFields.allowed_writes=@($Mission.allowed_writes);$packetFields.forbidden_reads=@($Mission.forbidden_sources);$packetFields.forbidden_writes=@($Mission.forbidden_repositories);$packetFields.forbidden_actions=$forbidden
    $packetFields.expected_artifacts=@($Mission.required_artifacts|ForEach-Object{[string]$_.path});$packetFields.required_preflight_checks=@('schema','repo_exists','path_scope','restricted_action_coverage','git_status_capture','approval_ledger','worker_role_permission','durable_source_binding');$packetFields.required_postrun_checks=@('mission_id_match','expected_artifacts_exist','restricted_actions_absent','forbidden_outputs_absent')+@($Mission.required_tests|Where-Object{$_.required}|ForEach-Object{"test:$($_.test_id)"})
    $packetFields.stop_conditions=$stops;$packetFields.approval_requirements=@($approvals);$packetFields.clarification_requirements=@($clarifications);$packetFields.hq_escalation_policy=[pscustomobject]@{default='local_only_no_api';escalate_on=@('RED','TIM_REQUIRED','approval_gap','scope_conflict');notes='Generated from canonical durable mission.'};$packetFields.created_by='TSF_DURABLE_TRANSLATOR';$packetFields.created_at=[string]$Mission.created_at
    $packet=[pscustomobject]$packetFields
    $roleExt=[pscustomobject][ordered]@{requested_by='TSF_DURABLE_MISSION';project_main_bot_id=[string]$Mission.project_id;worker_role=[string]$Mission.worker_role;translator_used=$true;lane_id='MASTER_TSF_CONTROL_PLANE';parent_mission_id=if($null -eq $Mission.parent_mission_id){''}else{[string]$Mission.parent_mission_id};sibling_lane_ids=@();role_permission_profile_id=[string]$profile.profile_id;role_output_contract=[string]$role[0].output_contract;verifier_role=if([bool]$profile.requires_verifier){'verifier_worker'}else{'NONE'};escalation_policy_id='canonical_durable_v1'}
    $worker=[pscustomobject][ordered]@{mission_id=[string]$Mission.mission_id;worker_role=[string]$Mission.worker_role;allowed_reads=@($Mission.allowed_reads);allowed_writes=@($Mission.allowed_writes);forbidden_actions=$forbidden;exact_task=[string]$Mission.normalized_goal;exact_response_contract=if($Mission.PSObject.Properties.Name-contains'exact_response_contract'){$Mission.exact_response_contract}else{$null};result_validation_mode=if($Mission.PSObject.Properties.Name-contains'result_validation_mode'){[string]$Mission.result_validation_mode}else{$null};original_operator_intent=if($Mission.PSObject.Properties.Name-contains'original_operator_intent'){$Mission.original_operator_intent}else{$null};scope_transformation=if($Mission.PSObject.Properties.Name-contains'scope_transformation'){$Mission.scope_transformation}else{$null};task_completion_contract=if($Mission.PSObject.Properties.Name-contains'task_completion_contract'){$Mission.task_completion_contract}else{$null};expected_artifacts=@($packet.expected_artifacts);stop_conditions=$stops;verifier_contract=[string]$Mission.required_verifier_independence;escalation_triggers=@('approval_gap','scope_conflict','validation_failure');do_not_exceed_role_authority=$true}
    foreach($contract in @(
        [pscustomobject]@{value=$packet;schema=(Join-Path $contractRoot 'docs\hq\enforcement_kernel\minimum_viable_local_tsf_enforcement_kernel_v1\mission_schema_v1.json');name='mission_packet'},
        [pscustomobject]@{value=$roleExt;schema=(Join-Path $contractRoot 'fleet\control\role-aware-mission-extension.v1.json');name='role_extension'},
        [pscustomobject]@{value=$worker;schema=(Join-Path $contractRoot 'fleet\control\worker-instruction-packet.schema.v1.json');name='worker_instruction_packet'}
    )){$check=Test-TsfJsonContract $contract.value $contract.schema;if(!$check.valid){throw "Generated $($contract.name) violates its canonical schema: $($check.errors -join '; ')"}}
    $hash=Get-TsfContractJsonHash $Mission; $binding=[pscustomobject][ordered]@{durable_mission_id=[string]$Mission.mission_id;durable_mission_revision=[int]$Mission.mission_revision;policy_fingerprint=[string]$Mission.policy.fingerprint;durable_mission_content_hash=$hash;translator_version=$translatorVersion;generated_at=[string]$Mission.created_at;mission_packet_sha256=Get-TsfContractJsonHash $packet;role_extension_sha256=Get-TsfContractJsonHash $roleExt;worker_instruction_sha256=Get-TsfContractJsonHash $worker;exact_response_contract_sha256=if($null-ne$packet.exact_response_contract){Get-TsfContractJsonHash $packet.exact_response_contract}else{$null};original_intent_identity_sha256=if($null-ne$packet.original_operator_intent){[string]$packet.original_operator_intent.original_intent_identity_sha256}else{$null};scope_transformation_identity_sha256=if($null-ne$packet.scope_transformation){[string]$packet.scope_transformation.scope_transformation_identity_sha256}else{$null};task_completion_contract_identity_sha256=if($null-ne$packet.task_completion_contract){[string]$packet.task_completion_contract.task_completion_contract_identity_sha256}else{$null};expected_repository=$repo;expected_branch=$Mission.branch_worktree_policy.expected_branch;expected_worktree=$Mission.branch_worktree_policy.expected_worktree;expected_role=[string]$Mission.worker_role;expected_permission_mode=[string]$Mission.permission_mode;expected_network_policy=[string]$Mission.network_policy;expected_control_plane_service_network_policy=[string]$Mission.control_plane_service_network_policy;expected_worker_tool_network_policy=[string]$Mission.worker_tool_network_policy;expected_surface=[string]$Mission.recommended_surface;expected_model=$Mission.resolved_model}
    $document=[pscustomobject][ordered]@{schema_version='tsf_canonical_queue_document_v1';compatibility_status='GENERATED_EXECUTION_PACKET';durable_mission=$Mission;source_binding=$binding;model_resolution=$routing;mission_packet=$packet;role_extension=$roleExt;worker_instruction_packet=$worker}
    $queueCheck=Test-TsfJsonContract $document (Join-Path $contractRoot 'fleet\control\canonical-queue-document.schema.v1.json');if(!$queueCheck.valid){throw "Generated canonical queue document is invalid: $($queueCheck.errors -join '; ')"};return $document
}

function Test-TsfCanonicalQueueDocument {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$QueueDocument,[object]$ExpectedMission,[string]$RepositoryRoot=$script:TsfRoot,[switch]$SkipRuntimeObservation)
    $contractRoot=Get-TsfKernelFullPath $RepositoryRoot
    $errors=[Collections.Generic.List[string]]::new();$schema=Test-TsfJsonContract $QueueDocument (Join-Path $contractRoot 'fleet\control\canonical-queue-document.schema.v1.json');if(!$schema.valid){@($schema.errors)|ForEach-Object{$errors.Add([string]$_)|Out-Null}}
    if($errors.Count -eq 0){
        $mission=$QueueDocument.durable_mission;$missionCheck=Test-TsfMissionEnvelope $mission (Join-Path $contractRoot 'fleet\control\mission-envelope.schema.v1.json');if(!$missionCheck.valid){@($missionCheck.errors)|ForEach-Object{$errors.Add([string]$_)|Out-Null}}
        if($null -ne $ExpectedMission -and (Get-TsfContractJsonHash $ExpectedMission) -ne (Get-TsfContractJsonHash $mission)){$errors.Add('Queue durable mission differs from the expected canonical mission.')|Out-Null}
        try{$regenerated=ConvertTo-TsfCanonicalExecutionArtifacts $mission $RepositoryRoot}catch{$errors.Add($_.Exception.Message)|Out-Null;$regenerated=$null}
        if($null -ne $regenerated){foreach($name in @('source_binding','model_resolution','mission_packet','role_extension','worker_instruction_packet')){if((Get-TsfContractJsonHash $QueueDocument.$name) -ne (Get-TsfContractJsonHash $regenerated.$name)){$errors.Add("Queue $name conflicts with deterministic translation.")|Out-Null}}}
        if(!$SkipRuntimeObservation -and $errors.Count -eq 0){$repo=[string]$QueueDocument.source_binding.expected_repository;$git=Get-TsfKernelGitState $repo;if(!$git.can_capture){$errors.Add('Queue repository Git state cannot be observed.')|Out-Null}else{if([bool]$mission.branch_worktree_policy.branch_required -and [string]$git.branch -ne [string]$QueueDocument.source_binding.expected_branch){$errors.Add('Queue branch does not match durable binding.')|Out-Null};if([string]$git.head-ne[string]$mission.branch_worktree_policy.starting_head){$errors.Add('Queue HEAD does not match durable binding.')|Out-Null};if([bool]$mission.branch_worktree_policy.worktree_required -and ![string]::Equals((Get-TsfKernelFullPath $repo).TrimEnd('\','/'),(Get-TsfKernelFullPath ([string]$QueueDocument.source_binding.expected_worktree)).TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Queue worktree does not match durable binding.')|Out-Null};if(!(Test-TsfKernelReparseContained $repo $repo)){$errors.Add('Queue repository root is a reparse point or cannot be contained.')|Out-Null}}}
    }
    $effective=$null;if($errors.Count -eq 0){$effective=$QueueDocument.mission_packet|ConvertTo-Json -Depth 100|ConvertFrom-Json;$effective|Add-Member -NotePropertyName role_extension -NotePropertyValue $QueueDocument.role_extension -Force;$effective|Add-Member -NotePropertyName durable_source_binding -NotePropertyValue $QueueDocument.source_binding -Force;$effective|Add-Member -NotePropertyName model_resolution -NotePropertyValue $QueueDocument.model_resolution -Force;$effective|Add-Member -NotePropertyName worker_instruction_contract -NotePropertyValue $QueueDocument.worker_instruction_packet -Force}
    [pscustomobject]@{valid=$errors.Count -eq 0;errors=@($errors);mission_id=if($null-ne$QueueDocument.source_binding){[string]$QueueDocument.source_binding.durable_mission_id}else{''};queue_document_sha256=Get-TsfContractJsonHash $QueueDocument;effective_mission=$effective}
}

function Test-TsfCanonicalQueueRecordFile {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$QueueRecordPath,
        [Parameter(Mandatory)][string]$QueueRoot,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ExpectedQueueState,
        [Parameter(Mandatory)][string]$ExpectedMissionId,
        [Parameter(Mandatory)][int]$ExpectedMissionRevision,
        [string]$RepositoryRoot=$script:TsfRoot,
        [switch]$TestOnlyAllowAlternateQueueRoot
    )

    $errors=[Collections.Generic.List[string]]::new()
    $document=$null
    $queueCheck=$null
    $recordPath=$null
    $queueRootPath=$null
    $expectedStatePath=$null
    try {
        $repositoryPath=Get-TsfKernelFullPath $RepositoryRoot
        $recordPath=Get-TsfKernelFullPath $QueueRecordPath
        $queueRootPath=Get-TsfKernelFullPath $QueueRoot
        $canonicalQueueRoot=Get-TsfCanonicalProductionQueueRoot
        if(![string]::Equals($repositoryPath,(Get-TsfKernelFullPath $script:TsfRoot),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('QUEUE_RECORD_REPOSITORY_ROOT_MISMATCH')|Out-Null}
        if(![string]::Equals($queueRootPath,$canonicalQueueRoot,[StringComparison]::OrdinalIgnoreCase)){
            $fixtureRoot=Get-TsfKernelFullPath (Join-Path $repositoryPath '.codex-local\fixtures')
            if(!$TestOnlyAllowAlternateQueueRoot){$errors.Add('QUEUE_RECORD_NONCANONICAL_QUEUE_ROOT')|Out-Null}
            elseif(!(Test-TsfKernelPathInside $queueRootPath $fixtureRoot)){$errors.Add('QUEUE_RECORD_TEST_ONLY_ROOT_OUTSIDE_FIXTURES')|Out-Null}
        }
        if(!(Test-TsfKernelPathInside $recordPath $queueRootPath)){$errors.Add('QUEUE_RECORD_PATH_OUTSIDE_CANONICAL_ROOT')|Out-Null}

        $statePolicy=Read-TsfKernelJson (Join-Path $repositoryPath 'fleet\control\mission-queue-state-policy.v1.json')
        if([string]$statePolicy.schema_version-ne'mission_queue_state_policy_v1'-or@($statePolicy.states|Where-Object{[string]$_-ceq$ExpectedQueueState}).Count-ne1){$errors.Add('QUEUE_RECORD_STATE_NOT_CANONICAL')|Out-Null}
        $expectedStatePath=Get-TsfKernelFullPath (Join-Path $queueRootPath $ExpectedQueueState)
        if(![string]::Equals((Split-Path -Parent $recordPath),$expectedStatePath,[StringComparison]::OrdinalIgnoreCase)){$errors.Add('QUEUE_RECORD_DIRECTORY_STATE_MISMATCH')|Out-Null}

        $leaf=Split-Path -Leaf $recordPath
        if($leaf-cnotmatch'^(?<mission>[A-Za-z0-9_-][A-Za-z0-9._-]{6,158})\.r(?<revision>[1-9][0-9]*)\.json$'){
            $errors.Add('QUEUE_RECORD_FILENAME_INVALID')|Out-Null
        } else {
            if(![string]::Equals([string]$Matches.mission,$ExpectedMissionId,[StringComparison]::Ordinal)){$errors.Add('QUEUE_RECORD_FILENAME_MISSION_ID_MISMATCH')|Out-Null}
            if([int]$Matches.revision-ne$ExpectedMissionRevision){$errors.Add('QUEUE_RECORD_FILENAME_REVISION_MISMATCH')|Out-Null}
        }
    } catch {
        $errors.Add("QUEUE_RECORD_PATH_VALIDATION_FAILED: $($_.Exception.Message)")|Out-Null
    }

    if($null-ne$recordPath-and$null-ne$queueRootPath-and(Test-TsfKernelPathInside $recordPath $queueRootPath)){
        $cursor=$recordPath
        while($true){
            try{$item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop}catch{$errors.Add("QUEUE_RECORD_UNREADABLE_ENTRY: $cursor")|Out-Null;break}
            if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){$errors.Add("QUEUE_RECORD_REPARSE_POINT_REJECTED: $cursor")|Out-Null;break}
            if([string]::Equals($cursor,$recordPath,[StringComparison]::OrdinalIgnoreCase)-and[bool]$item.PSIsContainer){$errors.Add('QUEUE_RECORD_NOT_REGULAR_FILE')|Out-Null;break}
            if([string]::Equals($cursor,$queueRootPath,[StringComparison]::OrdinalIgnoreCase)){break}
            $next=Split-Path -Parent $cursor
            if([string]::IsNullOrWhiteSpace($next)-or[string]::Equals($next,$cursor,[StringComparison]::OrdinalIgnoreCase)){$errors.Add('QUEUE_RECORD_PATH_ANCESTRY_INVALID')|Out-Null;break}
            $cursor=$next
        }
    }

    if($errors.Count-eq0){
        try{$document=Read-TsfKernelJson $recordPath}catch{$errors.Add("QUEUE_RECORD_JSON_INVALID: $($_.Exception.Message)")|Out-Null}
    }
    if($errors.Count-eq0){
        try{$queueCheck=Test-TsfCanonicalQueueDocument -QueueDocument $document -ExpectedMission $document.durable_mission -RepositoryRoot $RepositoryRoot}catch{$errors.Add("QUEUE_RECORD_CANONICAL_VALIDATOR_FAILED: $($_.Exception.Message)")|Out-Null}
        if($null-ne$queueCheck-and![bool]$queueCheck.valid){foreach($error in @($queueCheck.errors)){$errors.Add("QUEUE_RECORD_CANONICAL_DOCUMENT_INVALID: $error")|Out-Null}}
    }
    if($errors.Count-eq0){
        if(![string]::Equals([string]$document.durable_mission.mission_id,$ExpectedMissionId,[StringComparison]::Ordinal)-or[int]$document.durable_mission.mission_revision-ne$ExpectedMissionRevision){$errors.Add('QUEUE_RECORD_DURABLE_MISSION_IDENTITY_MISMATCH')|Out-Null}
        if(![string]::Equals([string]$document.source_binding.durable_mission_id,$ExpectedMissionId,[StringComparison]::Ordinal)-or[int]$document.source_binding.durable_mission_revision-ne$ExpectedMissionRevision){$errors.Add('QUEUE_RECORD_SOURCE_BINDING_IDENTITY_MISMATCH')|Out-Null}
    }

    [pscustomobject][ordered]@{
        valid=$errors.Count-eq0
        errors=@($errors)
        path=$recordPath
        queue_root=$queueRootPath
        queue_state=$ExpectedQueueState
        queue_state_authority='CANONICAL_PARENT_DIRECTORY_V1'
        mission_id=$ExpectedMissionId
        mission_revision=$ExpectedMissionRevision
        canonical_validator='Test-TsfCanonicalQueueDocument'
        queue_document_sha256=if($null-ne$queueCheck){[string]$queueCheck.queue_document_sha256}else{$null}
    }
}

function Test-TsfCanonicalVerifierIdentity {
    param(
        [Parameter(Mandatory)][object]$Verifier,
        [Parameter(Mandatory)][object]$Mission,
        [Parameter(Mandatory)][string]$ResultId
    )
    $errors=[Collections.Generic.List[string]]::new()
    if([string]$Verifier.mission_id-ne[string]$Mission.mission_id){$errors.Add('Verifier mission_id differs from the durable mission.')|Out-Null}
    if([string]$Verifier.mission_revision-ne[string][int]$Mission.mission_revision){$errors.Add('Verifier mission_revision differs from the durable mission.')|Out-Null}
    if([string]$Verifier.run_id-ne$ResultId){$errors.Add('Verifier run_id differs from the authenticated result identity.')|Out-Null}
    if([string]$Verifier.result_id-ne$ResultId){$errors.Add('Verifier result_id differs from the authenticated result identity.')|Out-Null}
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors)}
}

function ConvertTo-TsfDurableResultEnvelope {
    [CmdletBinding()] param([Parameter(Mandatory)][object]$Mission,[Parameter(Mandatory)][object]$RuntimeEvidence,[string]$RepositoryRoot=$script:TsfRoot,[switch]$TestOnlyAllowSyntheticProducerRegistry)
    if([string]$RuntimeEvidence.schema_version -ne 'tsf_authenticated_runtime_evidence_v1'){throw 'Runtime evidence is not an authenticated producer-binding packet.'}
    $translation=ConvertTo-TsfCanonicalExecutionArtifacts $Mission $RepositoryRoot;$repo=[string]$translation.mission_packet.repo_path;$git=Get-TsfKernelGitState $repo;if(!$git.can_capture){throw 'Canonical Git observation failed.'}
    $presPath=Get-TsfKernelFullPath ([string]$RuntimeEvidence.preservation_packet_path);$presDescriptor=Get-TsfPreservationPacketDescriptor $presPath ([string]$Mission.mission_id) ([int]$Mission.mission_revision)
    if([string]$presDescriptor.layout-ne'COMPACT_V1'){throw 'LEGACY_PACKET_WRITE_PROHIBITED'}
    $catalog=Get-TsfRuntimeArtifactCatalog
    $boundMission=Get-TsfManifestBoundArtifact $presDescriptor 'mission' $catalog.mission 'canonical_mission_translator' @('KERNEL_OBSERVED')
    $boundQueue=Get-TsfManifestBoundArtifact $presDescriptor 'queue_document' $catalog.queue_document 'canonical_queue_executor' @('KERNEL_OBSERVED')
    $boundAdapter=Get-TsfManifestBoundArtifact $presDescriptor 'adapter_result' $catalog.adapter_result 'codex_app_server_adapter' @('ADAPTER_OBSERVED')
    $boundPreflight=Get-TsfManifestBoundArtifact $presDescriptor 'preflight' $catalog.preflight 'enforcement_kernel' @('KERNEL_OBSERVED')
    $boundRole=Get-TsfManifestBoundArtifact $presDescriptor 'role_preflight' $catalog.role_preflight 'role_permission_preflight' @('KERNEL_OBSERVED')
    $boundInstruction=Get-TsfManifestBoundArtifact $presDescriptor 'worker_instruction' $catalog.worker_instruction 'enforcement_kernel' @('KERNEL_OBSERVED')
    $boundWorker=Get-TsfManifestBoundArtifact $presDescriptor 'worker_result' $catalog.worker_result 'mission_lifecycle' @('KERNEL_OBSERVED')
    $boundVerifier=Get-TsfManifestBoundArtifact $presDescriptor 'verifier_result' $catalog.verifier_result 'enforcement_kernel_verifier' @('VERIFIER_OBSERVED')
    $boundJournal=Get-TsfManifestBoundArtifact $presDescriptor 'event_journal' $catalog.event_journal 'codex_app_server_adapter' @('NATIVE_OBSERVED')
    $boundUsage=Get-TsfManifestBoundArtifact $presDescriptor 'usage' $catalog.usage 'codex_app_server_adapter' @('NATIVE_OBSERVED','UNVERIFIED')
    $boundPreservation=Get-TsfManifestBoundArtifact $presDescriptor 'preservation_packet' $catalog.preservation_packet 'canonical_preservation_writer' @('KERNEL_OBSERVED')
    $boundPrompt=Get-TsfManifestBoundArtifact $presDescriptor 'prompt' $catalog.prompt 'mission_lifecycle' @('KERNEL_OBSERVED')
    $boundStderr=Get-TsfManifestBoundArtifact $presDescriptor 'stderr' $catalog.stderr 'codex_app_server_diagnostic' @('UNVERIFIED')
    $boundRegistry=Get-TsfManifestBoundArtifact $presDescriptor 'producer_registry' $catalog.producer_registry 'mission_lifecycle_orchestrator' @('KERNEL_OBSERVED')
    foreach($binding in @(
        [pscustomobject]@{name='queue_document_path';path=$boundQueue.path},[pscustomobject]@{name='adapter_result_path';path=$boundAdapter.path},[pscustomobject]@{name='preflight_path';path=$boundPreflight.path},
        [pscustomobject]@{name='role_preflight_path';path=$boundRole.path},[pscustomobject]@{name='worker_result_path';path=$boundWorker.path},[pscustomobject]@{name='verifier_result_path';path=$boundVerifier.path},
        [pscustomobject]@{name='preservation_packet_path';path=$boundPreservation.path}
    )){if(![string]::Equals((Get-TsfKernelFullPath ([string]$RuntimeEvidence.($binding.name))),([string]$binding.path),[StringComparison]::OrdinalIgnoreCase)){throw "CALLER_EVIDENCE_PATH_NOT_MANIFEST_BOUND: $($binding.name)"}}
    $queueDocument=Read-TsfKernelJson $boundQueue.path;$queueCheck=Test-TsfCanonicalQueueDocument $queueDocument $Mission $RepositoryRoot;if(!$queueCheck.valid){throw "Queue producer binding failed: $($queueCheck.errors -join '; ')"}
    $registryCheck=Test-TsfProducerEvidenceRegistry $boundRegistry.path ([string]$Mission.mission_id) ([int]$Mission.mission_revision) ([string]$RuntimeEvidence.result_id) ([string]$Mission.policy.fingerprint) ([string]$queueCheck.queue_document_sha256) -AllowTestOnly:$TestOnlyAllowSyntheticProducerRegistry
    if(!$registryCheck.valid){throw "Producer registry binding failed: $($registryCheck.errors -join '; ')"}
    foreach($registered in @($registryCheck.registry.artifacts)){
        $manifestRecord=@($presDescriptor.manifest.artifacts|Where-Object{[string]$_.logical_type-eq[string]$registered.logical_type})
        if($manifestRecord.Count-ne1-or[string]$manifestRecord[0].producer-ne[string]$registered.producer-or[string]$manifestRecord[0].evidence_classification-ne[string]$registered.evidence_classification-or[string]$manifestRecord[0].sha256-ne[string]$registered.sha256){throw "Preservation manifest is not producer-registry bound: $($registered.logical_type)"}
    }
    $adapter=Read-TsfKernelJson $boundAdapter.path;$preflight=Read-TsfKernelJson $boundPreflight.path;$rolePreflight=Read-TsfKernelJson $boundRole.path;$worker=Read-TsfKernelJson $boundWorker.path;$verifierResult=Read-TsfKernelJson $boundVerifier.path;$preservation=Read-TsfKernelJson $boundPreservation.path
    foreach($producer in @($adapter,$preflight,$worker,$verifierResult,$preservation)){if([string]$producer.mission_id -ne [string]$Mission.mission_id){throw 'Observed producer mission identity mismatch.'}}
    $verifierIdentity=Test-TsfCanonicalVerifierIdentity -Verifier $verifierResult -Mission $Mission -ResultId ([string]$RuntimeEvidence.result_id)
    if(!$verifierIdentity.valid){throw "Verifier durable identity binding failed: $($verifierIdentity.errors -join '; ')"}
    if([string]$rolePreflight.role_id -ne [string]$Mission.worker_role -or ![bool]$rolePreflight.role_preflight_approved){throw 'Role preflight producer is unbound or not approved.'}
    if(![bool]$preflight.preflight_approved -or ![bool]$verifierResult.verified){throw 'Kernel producer evidence is not approved and verified.'}
    if([string]$adapter.mission_revision -ne [string]$Mission.mission_revision -or [string]$adapter.policy_fingerprint -ne [string]$Mission.policy.fingerprint -or [string]$adapter.queue_document_sha256 -ne [string]$queueCheck.queue_document_sha256){throw 'Adapter durable binding mismatch.'}
    if([string]$adapter.cwd -ne [string]$repo -or [string]$adapter.observed_model -ne [string]$translation.model_resolution.resolved_model){throw 'Adapter repository or model observation mismatch.'}
    if([string]$adapter.control_plane_service_network_policy -ne 'CODEX_SERVICE_ONLY' -or [string]$adapter.worker_tool_network_policy -ne 'DISABLED' -or ![bool]$adapter.codex_service_connection_used -or [bool]$adapter.direct_openai_api_called_by_tsf -or [bool]$adapter.external_api_called -or [bool]$adapter.worker_network_used){throw 'Adapter network-policy evidence is invalid.'}
    if(![bool]$adapter.child_exited -or ![bool]$adapter.no_orphan_process -or [string]::IsNullOrWhiteSpace([string]$adapter.thread_id) -or [string]::IsNullOrWhiteSpace([string]$adapter.turn_id)){throw 'Adapter native identity or cleanup evidence is incomplete.'}
    $expectedResponseSha256=Get-TsfExpectedResponseSha256 -Mission $Mission
    $boundExactResponseContract=if($Mission.PSObject.Properties.Name-contains'exact_response_contract'){$Mission.exact_response_contract}else{$null}
    $resultValidationMode=if($Mission.PSObject.Properties.Name-contains'result_validation_mode'){[string]$Mission.result_validation_mode}elseif($null-ne$boundExactResponseContract){'EXACT_LITERAL_V1'}else{'LEGACY_GENERAL_FAIL_CLOSED'}
    $boundTaskCompletionContract=if($Mission.PSObject.Properties.Name-contains'task_completion_contract'){$Mission.task_completion_contract}else{$null}
    $generalResultEvidence=$null
    if(![string]::IsNullOrWhiteSpace($expectedResponseSha256)){
        $canonicalResultId=[string]$RuntimeEvidence.result_id
        if([string]$adapter.run_id-ne$canonicalResultId-or[string]$adapter.result_id-ne$canonicalResultId){throw 'Adapter exact-response run or result identity mismatch.'}
        if(![bool]$adapter.final_response_observed){throw 'Adapter final response was not observed.'}
        $observedResponseSha256=Get-TsfRawTextSha256 ([string]$adapter.final_response)
        if([string]$adapter.expected_response_sha256-ne$expectedResponseSha256-or[string]$adapter.observed_response_sha256-ne$observedResponseSha256-or$observedResponseSha256-ne$expectedResponseSha256-or![bool]$adapter.transport_success-or![bool]$adapter.response_exact_match-or![bool]$adapter.semantic_response_success){throw 'Adapter exact-response evidence does not match the mission-bound response.'}
        $workerExact=$worker.exact_response_evidence;$verifierExact=$verifierResult.exact_response_evidence
        if($null-eq$workerExact-or$null-eq$verifierExact-or![bool]$verifierExact.independently_recomputed-or![bool]$verifierExact.exact_match){throw 'Independent exact-response verifier evidence is missing.'}
        foreach($evidence in @($workerExact,$verifierExact)){
            if([string]$evidence.mission_id-ne[string]$Mission.mission_id-or[int]$evidence.mission_revision-ne[int]$Mission.mission_revision-or[string]$evidence.run_id-ne$canonicalResultId-or[string]$evidence.result_id-ne$canonicalResultId-or[string]$evidence.thread_id-ne[string]$adapter.thread_id-or[string]$evidence.turn_id-ne[string]$adapter.turn_id-or[string]$evidence.expected_response_sha256-ne$expectedResponseSha256-or[string]$evidence.observed_response_sha256-ne$observedResponseSha256){throw 'Exact-response producer identity binding mismatch.'}
            if($null-ne$boundExactResponseContract-and([string]$evidence.semantic_contract_sha256-ne[string]$boundExactResponseContract.semantic_contract_sha256-or[string]$evidence.validation_mode-ne'EXACT_LITERAL_V1'-or[string]$evidence.expected_literal-ne[string]$boundExactResponseContract.expected_literal)){throw 'Exact-response semantic contract binding mismatch.'}
        }
        $exactTest=@($worker.tests|Where-Object{[string]$_.test_id-eq'hq-dispatch-read-only-exact-response'})
        if($exactTest.Count-ne1-or[string]$exactTest[0].status-ne'PASS'-or[string]$exactTest[0].evidence-ne$observedResponseSha256){throw 'Worker required-test PASS is not bound to exact observed response evidence.'}
    }elseif($resultValidationMode-eq'GENERAL_RESULT_V2'){
        if($null-eq$boundTaskCompletionContract){throw 'GENERAL_RESULT_V2 task-completion contract is missing.'}
        $generalResultEvidence=Get-TsfGeneralResultV2Evidence -MissionId ([string]$Mission.mission_id) -MissionRevision ([int]$Mission.mission_revision) -RunId ([string]$RuntimeEvidence.result_id) -Adapter $adapter -TaskCompletionContract $boundTaskCompletionContract
        $generalSchema=Test-TsfJsonContract $generalResultEvidence (Join-Path (Get-TsfKernelFullPath $RepositoryRoot) 'fleet\control\general-result-v2.schema.v1.json')
        if(!$generalSchema.valid){throw "Mapped general-result evidence violates schema: $($generalSchema.errors -join '; ')"}
        if($null-eq$worker.general_result_evidence-or$null-eq$verifierResult.general_result_evidence){throw 'Worker or independent verifier general-result evidence is missing.'}
        if((Get-TsfContractJsonHash $worker.general_result_evidence)-ne(Get-TsfContractJsonHash $generalResultEvidence)-or(Get-TsfContractJsonHash $verifierResult.general_result_evidence)-ne(Get-TsfContractJsonHash $generalResultEvidence)){throw 'General-result evidence is not reproducible across worker, verifier, and mapper.'}
        if(![bool]$generalResultEvidence.semantic_success-or![bool]$generalResultEvidence.admissible-or[string]$generalResultEvidence.semantic_status-ne'FULFILLED'){throw "General task was not fulfilled: $([string]$generalResultEvidence.outcome_disposition)"}
        $generalTest=@($worker.tests|Where-Object{[string]$_.test_id-eq'hq-dispatch-general-result-v2'})
        if($generalTest.Count-ne1-or[string]$generalTest[0].status-ne'PASS'-or[string]$generalTest[0].evidence-ne[string]$boundTaskCompletionContract.task_completion_contract_identity_sha256){throw 'Worker required-test PASS is not bound to the task-completion contract.'}
    }else{
        throw 'Legacy general result is not admissible without GENERAL_RESULT_V2.'
    }
    $observationClaims=if($worker.PSObject.Properties.Name-contains'observation_claims'){$worker.observation_claims}else{$null}
    if(![string]::IsNullOrWhiteSpace($expectedResponseSha256)-and$null-eq$observationClaims){throw 'HQ Dispatch observation claims are missing.'}
    if($null-ne$observationClaims){$observationCheck=Test-TsfObservationClaims -Claims $observationClaims -RunId ([string]$RuntimeEvidence.result_id);if(!$observationCheck.valid){throw "Observation claims are invalid: $($observationCheck.errors -join '; ')"}}
    $journalPath=[string]$boundJournal.path;$journalHash=[string]$boundJournal.sha256;if($journalHash -ne [string]$adapter.event_journal_sha256){throw 'Adapter event journal hash mismatch.'}
    $journalEntries=@(Get-Content -LiteralPath $journalPath|Where-Object{![string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_|ConvertFrom-Json})
    foreach($nativeEvent in @($adapter.native_reroute_or_override_events)){
        if((Get-TsfRawTextSha256 ([string]$nativeEvent.raw_payload_json))-ne[string]$nativeEvent.raw_payload_sha256){throw 'Adapter native effort-event payload hash mismatch.'}
        $rawPayload=[string]$nativeEvent.raw_payload_json|ConvertFrom-Json
        $bound=@($journalEntries|Where-Object{[int]$_.sequence-eq[int]$nativeEvent.sequence-and[string]$_.direction-eq'server_to_client'-and[string]$_.message.method-eq[string]$nativeEvent.method})
        if($bound.Count-ne1-or(Get-TsfContractJsonHash $bound[0].message.params)-ne(Get-TsfContractJsonHash $rawPayload)){throw 'Adapter native effort event is not bound to the event journal.'}
        if([string]$nativeEvent.thread_id-ne[string]$adapter.thread_id){throw 'Adapter native effort event thread binding mismatch.'}
        if(![string]::IsNullOrWhiteSpace([string]$nativeEvent.turn_id)-and[string]$nativeEvent.turn_id-ne[string]$adapter.turn_id){throw 'Adapter native effort event turn binding mismatch.'}
    }
    $presHash=[string]$boundPreservation.sha256;if([string]$preservation.mission_id -ne [string]$Mission.mission_id){throw 'Preservation mission binding mismatch.'};if([string]$presDescriptor.manifest.run_id-ne[string]$RuntimeEvidence.result_id-or[string]$presDescriptor.manifest.policy_fingerprint-ne[string]$Mission.policy.fingerprint-or[string]$presDescriptor.manifest.mission_content_hash-ne[string]$translation.source_binding.durable_mission_content_hash){throw 'Compact preservation manifest producer binding mismatch.'}
    if(![string]::Equals((Get-TsfKernelFullPath ([string]$presDescriptor.manifest.repository)),$repo,[StringComparison]::OrdinalIgnoreCase)-or![string]::Equals((Get-TsfKernelFullPath ([string]$presDescriptor.manifest.worktree)),$repo,[StringComparison]::OrdinalIgnoreCase)-or[string]$presDescriptor.manifest.branch-ne[string]$git.branch){throw 'Manifest repository, branch, or worktree binding mismatch.'}
    $effortEvidence=Get-TsfEffortEvidence -Mission $Mission -Adapter $adapter
    $usageEvidence=Read-TsfKernelJson $boundUsage.path
    if($null-eq$usageEvidence){throw 'Adapter usage evidence is missing.'}
    if((Get-TsfContractJsonHash $usageEvidence)-ne(Get-TsfContractJsonHash $adapter.turn_usage)){throw 'Manifest usage artifact differs from adapter usage evidence.'}
    if([string]$usageEvidence.evidence_classification-eq'NATIVE_OBSERVED'){
        $selected=@($journalEntries|Where-Object{[int]$_.sequence-eq[int]$usageEvidence.selected_sequence-and[string]$_.direction-eq'server_to_client'-and[string]$_.message.method-eq'thread/tokenUsage/updated'})
        if($selected.Count-ne1-or[string]$selected[0].message.params.threadId-ne[string]$adapter.thread_id-or[string]$selected[0].message.params.turnId-ne[string]$adapter.turn_id){throw 'Adapter usage evidence is not bound to the native thread and turn.'}
        $raw=($selected[0].message.params|ConvertTo-Json -Compress -Depth 100)
        if((Get-TsfRawTextSha256 $raw)-ne[string]$usageEvidence.raw_payload_sha256){throw 'Adapter usage evidence raw payload hash mismatch.'}
    }elseif([string]$usageEvidence.status-ne'NOT_EXPOSED'-or[string]$usageEvidence.evidence_classification-ne'UNVERIFIED'){throw 'Unavailable usage evidence was promoted without a native observation.'}
    $artifacts=@();foreach($claim in @($Mission.required_artifacts)){$path=[string]$claim.path;$scopes=if(@($Mission.allowed_writes).Count){@($Mission.allowed_writes)}else{@($Mission.allowed_reads)};if(!(Test-TsfKernelPathContained $path $repo $scopes)){throw "Unsafe artifact path: $path"};$full=Get-TsfKernelFullPath $path $repo;$exists=Test-Path -LiteralPath $full -PathType Leaf;$artifacts+=[pscustomobject]@{path=$path;sha256=if($exists){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null};exists=$exists;evidence_classification='FILESYSTEM_OBSERVED'}}
    $tests=@($worker.tests|ForEach-Object{[pscustomobject]@{test_id=[string]$_.test_id;status=[string]$_.status;observed=[string]$_.observed;evidence=[string]$_.evidence;evidence_classification='KERNEL_OBSERVED'}})
    $approvals=@($worker.approval_use|ForEach-Object{[pscustomobject]@{approval_id=[string]$_.approval_id;exact_action=[string]$_.exact_action;used=[bool]$_.used;evidence_classification='KERNEL_OBSERVED'}})
    $verifier=@([pscustomobject]@{verifier_id='canonical-kernel-postrun';verifier_role='verifier_worker';independence=[string]$Mission.required_verifier_independence;passed=[bool]$verifierResult.verified;evidence=[string]$boundVerifier.sha256;evidence_classification='VERIFIER_OBSERVED'})
    $effortBinding=if($effortEvidence.effective_effort-eq'UNKNOWN'){'UNVERIFIED'}else{'ADAPTER_OBSERVED'};$effortUncertainty=@();if($effortEvidence.effective_effort-eq'UNKNOWN'){$effortUncertainty=@('Stable app-server protocol did not expose an authoritative effective turn effort.')};$effortWarnings=@($effortEvidence.effort_conflicts)
    [object[]]$mappedObservedDeliverables=@();[object[]]$mappedMissingDeliverables=@();[object[]]$mappedOutcomeEvidence=@()
    if($null-ne$generalResultEvidence){
        $mappedObservedDeliverables=[object[]]@($generalResultEvidence.observed_deliverables)
        $mappedMissingDeliverables=[object[]]@($generalResultEvidence.missing_deliverables)
        $mappedOutcomeEvidence=[object[]]@($generalResultEvidence.outcome_evidence)
    }
    $mapped=[pscustomobject][ordered]@{schema_version=$script:ResultSchemaVersion;result_id=[string]$RuntimeEvidence.result_id;mission_id=[string]$Mission.mission_id;mission_revision=[int]$Mission.mission_revision;mission_content_hash=[string]$translation.source_binding.durable_mission_content_hash;parent_mission_id=$Mission.parent_mission_id;policy_fingerprint=[string]$Mission.policy.fingerprint;result_validation_mode=$resultValidationMode;original_intent_identity_sha256=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.original_intent_identity_sha256}else{$null});scope_transformation_identity_sha256=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.scope_transformation_identity_sha256}else{$null});task_completion_contract_identity_sha256=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.task_completion_contract_identity_sha256}else{$null});transport_status=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.transport_status}else{$null});semantic_status=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.semantic_status}else{$null});outcome_disposition=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.outcome_disposition}else{$null});worker_claim=$(if($null-ne$generalResultEvidence){$generalResultEvidence.worker_claim}else{$null});observed_deliverables=$mappedObservedDeliverables;missing_deliverables=$mappedMissingDeliverables;outcome_evidence=$mappedOutcomeEvidence;raw_worker_response_sha256=$(if($null-ne$generalResultEvidence){[string]$generalResultEvidence.raw_worker_response_sha256}else{$null});surface_used='CODEX_APP_SERVER';surface_task_identity=[string]$adapter.thread_id;actual_model=[string]$adapter.observed_model;actual_reasoning_effort=[string]$effortEvidence.effective_effort;model_assurance_level='ADAPTER_VERIFIED';effort_evidence=$effortEvidence;usage_evidence=$usageEvidence;actual_repository=$repo;actual_branch_worktree=[pscustomobject]@{branch=$git.branch;worktree=$repo};git_facts=[pscustomobject]@{starting_head=$RuntimeEvidence.starting_head;ending_head=$git.head;base_head=$RuntimeEvidence.base_head;dirty_before=$RuntimeEvidence.dirty_before;dirty_after=$git.dirty};files_inspected=@();files_changed=@($worker.files_touched);major_actions=@('Bound foreground Codex app-server turn completed.');network_activity=[pscustomobject]@{status=$(if($null-ne$observationClaims){'UNKNOWN'}else{'ADAPTER_VERIFIED'});used=$(if($null-ne$observationClaims){$null}else{$false});destinations=@();control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';codex_service_connection_used=$true;direct_openai_api_called_by_tsf=$(if($null-ne$observationClaims){$null}else{$false});external_api_called=$(if($null-ne$observationClaims){$null}else{$false});worker_network_used=$(if($null-ne$observationClaims){$null}else{$false})};artifacts=$artifacts;tests=$tests;verifier_evidence=$verifier;approval_use=$approvals;preservation_evidence=[pscustomobject]@{packet_path=$presPath;packet_sha256=$presHash;evidence_classification='KERNEL_OBSERVED'};evidence_bindings=[pscustomobject]@{mapper_version=$script:ResultMapperVersion;runtime_evidence_sha256=Get-TsfContractJsonHash $RuntimeEvidence;repository='FILESYSTEM_OBSERVED';git='KERNEL_OBSERVED';model='ADAPTER_OBSERVED';effort=$effortBinding;usage=[string]$usageEvidence.evidence_classification;files='FILESYSTEM_OBSERVED';native='NATIVE_OBSERVED';adapter='ADAPTER_OBSERVED';kernel='KERNEL_OBSERVED';verifier='VERIFIER_OBSERVED';preservation='KERNEL_OBSERVED'};deviations_from_mission=@();uncertainty=$effortUncertainty;security_or_scope_warnings=$effortWarnings;proposed_next_action=[string]$RuntimeEvidence.proposed_next_action;authority_statement='Observed evidence only; grants no approval, merge, or production authority.';grants_approval=$false;grants_merge_authority=$false;grants_production_authority=$false;created_at=[string]$RuntimeEvidence.created_at}
    if($null-ne$observationClaims){$mapped|Add-Member -NotePropertyName observation_claims -NotePropertyValue $observationClaims -Force;$mapped.uncertainty=@($mapped.uncertainty)+@('Product repository, plugin, credential, and external-network runtime use were not exposed by authoritative observation; policy and configuration remain separate from observation.')}
    $mappedValidation=Test-TsfResultEnvelope $mapped;if(!$mappedValidation.valid){throw "Mapped result violates canonical schema: $($mappedValidation.errors -join '; ')"};return $mapped
}

function Test-TsfCanonicalRelativePath { param([string]$Path,[string]$Repo,[object[]]$Scopes) return Test-TsfKernelPathContained -RelativePath $Path -RepositoryRoot $Repo -AllowedScopes $Scopes }
function Test-TsfObservationClaims {
    param([Parameter(Mandatory)][object]$Claims,[Parameter(Mandatory)][string]$RunId)
    $errors=[Collections.Generic.List[string]]::new();$allowed=@('POLICY_PROHIBITED','CONFIGURED_DISABLED','OBSERVED_NOT_USED','NOT_OBSERVED','UNKNOWN')
    foreach($property in @($Claims.PSObject.Properties)){$claim=$property.Value;if($allowed-notcontains[string]$claim.classification){$errors.Add("Unsupported observation classification: $($property.Name)")|Out-Null};if([string]::IsNullOrWhiteSpace([string]$claim.source)){$errors.Add("Observation source is missing: $($property.Name)")|Out-Null};if([string]$claim.run_id-ne$RunId){$errors.Add("Observation claim is cross-run: $($property.Name)")|Out-Null};if([string]$claim.classification-in@('NOT_OBSERVED','UNKNOWN')-and$null-ne$claim.value){$errors.Add("Unobserved claim must not carry a definitive value: $($property.Name)")|Out-Null}}
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors)}
}

function Test-TsfRequiredTestEvidence {
    param([Parameter(Mandatory)][object]$Mission,[Parameter(Mandatory)][object]$Result)
    $errors=[Collections.Generic.List[string]]::new()
    foreach($test in @($Mission.required_tests|Where-Object{$_.required})){
        $matched=@($Result.tests|Where-Object{$_.test_id-eq$test.test_id-and$_.status-eq'PASS'-and$_.evidence_classification-eq'KERNEL_OBSERVED'})
        if($matched.Count-ne1){$errors.Add("Required observed test is missing: $($test.test_id)")|Out-Null;continue}
        $command=[string]$test.command
        if($command-match'^exact-response-sha256:([a-f0-9]{64})$'-and[string]$matched[0].evidence-ne$Matches[1]){$errors.Add("Required exact-response evidence does not match the mission binding: $($test.test_id)")|Out-Null}
        if($command-match'^general-result-v2:([a-f0-9]{64})$'-and[string]$matched[0].evidence-ne$Matches[1]){$errors.Add("Required general-result evidence does not match the task-completion binding: $($test.test_id)")|Out-Null}
    }
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors)}
}

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
    param($Result,[string]$Hash,[string]$Status,$Reasons,$Caveats,$Now,[string]$From,[string]$To,[bool]$Applied,[string]$Transition,$Storage,[string]$PreservationPath,[string]$PreservationHash,[string]$QueueDocumentHash,[string]$TranslatorVersion,$QueueAuthority)
    $decision=[pscustomobject][ordered]@{result_sha256=$Hash;status=$Status;reasons=@($Reasons);caveats=@($Caveats);queue_state_from=$From;queue_state_to=$To;queue_transition_path=$Transition}
    [pscustomobject][ordered]@{
        schema_version=$script:AdmissionSchemaVersion
        receipt_id="admission-$($Storage.key.Substring(0,24))"
        result_id=[string]$Result.result_id
        mission_id=[string]$Result.mission_id
        mission_revision=[int]$Result.mission_revision
        mission_content_hash=[string]$Result.mission_content_hash
        policy_fingerprint=[string]$Result.policy_fingerprint
        result_validation_mode=[string]$Result.result_validation_mode
        original_intent_identity_sha256=$Result.original_intent_identity_sha256
        scope_transformation_identity_sha256=$Result.scope_transformation_identity_sha256
        task_completion_contract_identity_sha256=$Result.task_completion_contract_identity_sha256
        outcome_disposition=$Result.outcome_disposition
        queue_document_sha256=$QueueDocumentHash
        translator_version=$TranslatorVersion
        preservation_packet_path=$PreservationPath
        preservation_packet_sha256=$PreservationHash
        queue_authority_kind=[string]$QueueAuthority.kind
        queue_authority_root=[string]$QueueAuthority.root
        queue_authority_identity_sha256=[string]$QueueAuthority.identity_sha256
        production_admission=([string]$QueueAuthority.kind-eq'PRODUCTION')
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
    $transaction=[pscustomobject][ordered]@{
        schema_version='tsf_admission_transaction_v1'
        transaction_id="transaction-$($Storage.key.Substring(0,24))"
        receipt_identity_sha256=[string]$Storage.identity_sha256
        state=$State
        mission_id=[string]$Receipt.mission_id
        mission_revision=[int]$Receipt.mission_revision
        mission_content_hash=[string]$Receipt.mission_content_hash
        result_id=[string]$Receipt.result_id
        result_sha256=[string]$Receipt.result_sha256
        policy_fingerprint=[string]$Receipt.policy_fingerprint
        queue_document_sha256=[string]$Receipt.queue_document_sha256
        translator_version=[string]$Receipt.translator_version
        preservation_packet_sha256=[string]$Receipt.preservation_packet_sha256
        preservation_packet_path=[string]$Receipt.preservation_packet_path
        admission_status=[string]$Receipt.status
        admission_decision_sha256=[string]$Receipt.admission_decision_sha256
        queue_authority_kind=[string]$Receipt.queue_authority_kind
        queue_authority_root=[string]$Receipt.queue_authority_root
        queue_authority_identity_sha256=[string]$Receipt.queue_authority_identity_sha256
        admission_receipt_path=[string]$Storage.admission
        admission_receipt_sha256=$AdmissionHash
        queue_state_from='postrun_pending'
        queue_state_to=[string]$Receipt.queue_state_to
        source_path=$SourcePath
        destination_path=$DestinationPath
        history=@($History)
        updated_at=$Now.ToUniversalTime().ToString('o')
    }
    $stable=[pscustomobject][ordered]@{receipt_identity_sha256=$transaction.receipt_identity_sha256;mission_id=$transaction.mission_id;mission_revision=$transaction.mission_revision;mission_content_hash=$transaction.mission_content_hash;result_id=$transaction.result_id;result_sha256=$transaction.result_sha256;policy_fingerprint=$transaction.policy_fingerprint;queue_document_sha256=$transaction.queue_document_sha256;translator_version=$transaction.translator_version;preservation_packet_path=$transaction.preservation_packet_path;preservation_packet_sha256=$transaction.preservation_packet_sha256;admission_receipt_path=$transaction.admission_receipt_path;queue_state_from=$transaction.queue_state_from;queue_state_to=$transaction.queue_state_to;source_path=$transaction.source_path;destination_path=$transaction.destination_path;admission_status=$transaction.admission_status;admission_decision_sha256=$transaction.admission_decision_sha256;queue_authority_identity_sha256=$transaction.queue_authority_identity_sha256}
    $transaction|Add-Member -NotePropertyName transaction_identity_sha256 -NotePropertyValue (Get-TsfContractJsonHash $stable)
    $content=[pscustomobject][ordered]@{stable=$stable;state=$transaction.state;admission_receipt_sha256=$transaction.admission_receipt_sha256;history=@($transaction.history)}
    $transaction|Add-Member -NotePropertyName transaction_content_sha256 -NotePropertyValue (Get-TsfContractJsonHash $content)
    $transaction
}

function Get-TsfAdmissionDecisionIdentity {
    param([Parameter(Mandatory)][object]$Receipt)
    [pscustomobject][ordered]@{result_sha256=[string]$Receipt.result_sha256;status=[string]$Receipt.status;reasons=@($Receipt.reasons);caveats=@($Receipt.caveats);queue_state_from=[string]$Receipt.queue_state_from;queue_state_to=[string]$Receipt.queue_state_to;queue_transition_path=[string]$Receipt.queue_transition_path}
}

function Test-TsfAdmissionRelationship {
    param($Result,[string]$ResultHash,[string]$PreservationPath,[string]$PreservationHash,$Receipt,[string]$ReceiptPath,$Transaction,[string]$TransactionPath,$QueueDocument,[string]$QueueDocumentHash,$QueueAuthority,[string]$CanonicalReceiptPath='',[string]$ExpectedTransactionFileHash='',[string]$ActualQueueRecordPath='',[string]$RepositoryRoot=$script:TsfRoot)
    $errors=[Collections.Generic.List[string]]::new()
    if(!$CanonicalReceiptPath){$CanonicalReceiptPath=$ReceiptPath}
    $pairs=@(
        @([string]$Receipt.mission_id,[string]$Result.mission_id,'mission id'),@([string]$Receipt.mission_revision,[string]$Result.mission_revision,'mission revision'),
        @([string]$Receipt.mission_content_hash,[string]$Result.mission_content_hash,'mission content hash'),@([string]$Receipt.policy_fingerprint,[string]$Result.policy_fingerprint,'policy fingerprint'),
        @([string]$Receipt.result_validation_mode,[string]$Result.result_validation_mode,'result validation mode'),@([string]$Receipt.original_intent_identity_sha256,[string]$Result.original_intent_identity_sha256,'original intent identity'),
        @([string]$Receipt.scope_transformation_identity_sha256,[string]$Result.scope_transformation_identity_sha256,'scope transformation identity'),@([string]$Receipt.task_completion_contract_identity_sha256,[string]$Result.task_completion_contract_identity_sha256,'task completion identity'),@([string]$Receipt.outcome_disposition,[string]$Result.outcome_disposition,'outcome disposition'),
        @([string]$Receipt.result_id,[string]$Result.result_id,'result id'),@([string]$Receipt.result_sha256,$ResultHash,'result hash'),
        @([string]$Receipt.preservation_packet_path,(Get-TsfKernelFullPath $PreservationPath),'preservation path'),@([string]$Receipt.preservation_packet_sha256,$PreservationHash,'preservation hash'),
        @([string]$Receipt.queue_document_sha256,$QueueDocumentHash,'queue hash'),@([string]$Receipt.queue_authority_identity_sha256,[string]$QueueAuthority.identity_sha256,'queue authority'))
    foreach($pair in $pairs){$left=if($pair[2]-match'path'){Get-TsfKernelFullPath $pair[0]}else{$pair[0]};if([string]$left-ne[string]$pair[1]){$errors.Add("Admission relationship mismatch: $($pair[2])")|Out-Null}}
    if(![string]::Equals((Get-TsfKernelFullPath ([string]$Receipt.admission_receipt_path)),(Get-TsfKernelFullPath $CanonicalReceiptPath),[StringComparison]::OrdinalIgnoreCase)-or![string]::Equals((Get-TsfKernelFullPath ([string]$Receipt.transaction_receipt_path)),(Get-TsfKernelFullPath $TransactionPath),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Receipt path relationship mismatch.')|Out-Null}
    if([string]$Receipt.admission_decision_sha256-ne(Get-TsfContractJsonHash (Get-TsfAdmissionDecisionIdentity $Receipt))){$errors.Add('Admission decision hash mismatch.')|Out-Null}
    try{
        $queueCheck=Test-TsfCanonicalQueueDocument $QueueDocument -RepositoryRoot $RepositoryRoot
        if(!$queueCheck.valid){$errors.Add("Actual queue document canonical identity mismatch: $(@($queueCheck.errors)-join'; ')")|Out-Null}
        if([string]$queueCheck.queue_document_sha256-ne$QueueDocumentHash){$errors.Add('Actual queue document hash mismatch.')|Out-Null}
        $source=$QueueDocument.source_binding
        if([string]$source.durable_mission_id-ne[string]$Result.mission_id-or[int]$source.durable_mission_revision-ne[int]$Result.mission_revision-or[string]$source.durable_mission_content_hash-ne[string]$Result.mission_content_hash-or[string]$source.policy_fingerprint-ne[string]$Result.policy_fingerprint-or[string]$source.translator_version-ne[string]$Receipt.translator_version){$errors.Add('Queue source binding relationship mismatch.')|Out-Null}
    }catch{$errors.Add("Queue document validation failed: $($_.Exception.Message)")|Out-Null}
    if($null-ne$Transaction){
        foreach($field in @('receipt_identity_sha256','mission_id','mission_revision','mission_content_hash','result_id','result_sha256','policy_fingerprint','queue_document_sha256','translator_version','preservation_packet_path','preservation_packet_sha256','admission_receipt_path','queue_state_from','queue_state_to','admission_status','admission_decision_sha256','queue_authority_identity_sha256')){
            $receiptField=switch($field){'admission_status'{'status'}default{$field}}
            if([string]$Transaction.$field-ne[string]$Receipt.$receiptField){$errors.Add("Transaction/receipt mismatch: $field")|Out-Null}
        }
        if(Test-Path $ReceiptPath -PathType Leaf){
            $receiptHash=(Get-FileHash $ReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if([string]$Transaction.admission_receipt_sha256-ne$receiptHash){$errors.Add('Admission receipt file hash mismatch.')|Out-Null}
        }
        if($ActualQueueRecordPath-and![string]::Equals((Get-TsfKernelFullPath ([string]$Transaction.destination_path)),(Get-TsfKernelFullPath $ActualQueueRecordPath),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Actual destination queue record path mismatch.')|Out-Null}
        $stable=[pscustomobject][ordered]@{receipt_identity_sha256=$Transaction.receipt_identity_sha256;mission_id=$Transaction.mission_id;mission_revision=$Transaction.mission_revision;mission_content_hash=$Transaction.mission_content_hash;result_id=$Transaction.result_id;result_sha256=$Transaction.result_sha256;policy_fingerprint=$Transaction.policy_fingerprint;queue_document_sha256=$Transaction.queue_document_sha256;translator_version=$Transaction.translator_version;preservation_packet_path=$Transaction.preservation_packet_path;preservation_packet_sha256=$Transaction.preservation_packet_sha256;admission_receipt_path=$Transaction.admission_receipt_path;queue_state_from=$Transaction.queue_state_from;queue_state_to=$Transaction.queue_state_to;source_path=$Transaction.source_path;destination_path=$Transaction.destination_path;admission_status=$Transaction.admission_status;admission_decision_sha256=$Transaction.admission_decision_sha256;queue_authority_identity_sha256=$Transaction.queue_authority_identity_sha256}
        if([string]$Transaction.transaction_identity_sha256-ne(Get-TsfContractJsonHash $stable)){$errors.Add('Transaction identity hash mismatch.')|Out-Null}
        $content=[pscustomobject][ordered]@{stable=$stable;state=$Transaction.state;admission_receipt_sha256=$Transaction.admission_receipt_sha256;history=@($Transaction.history)}
        if([string]$Transaction.transaction_content_sha256-ne(Get-TsfContractJsonHash $content)){$errors.Add('Transaction content hash mismatch.')|Out-Null}
        if($ExpectedTransactionFileHash){
            if(!(Test-Path $TransactionPath -PathType Leaf)-or(Get-FileHash $TransactionPath -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ExpectedTransactionFileHash){$errors.Add('Transaction file hash mismatch.')|Out-Null}
        }
    }
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors);transaction_file_sha256=if($null-ne$Transaction-and(Test-Path $TransactionPath)){(Get-FileHash $TransactionPath -Algorithm SHA256).Hash.ToLowerInvariant()}else{''}}
}

function Get-TsfRecoveryEnvelopeIdentity {
    param([Parameter(Mandatory)][object]$Envelope)
    [pscustomobject][ordered]@{mission_id=[string]$Envelope.mission_id;mission_revision=[int]$Envelope.mission_revision;mission_content_hash=[string]$Envelope.mission_content_hash;policy_fingerprint=[string]$Envelope.policy_fingerprint;queue_document_sha256=[string]$Envelope.queue_document_sha256;translator_version=[string]$Envelope.translator_version;result_id=[string]$Envelope.result_id;result_path=[string]$Envelope.result_path;result_sha256=[string]$Envelope.result_sha256;preservation_packet_path=[string]$Envelope.preservation_packet_path;preservation_packet_sha256=[string]$Envelope.preservation_packet_sha256;admission_receipt_path=[string]$Envelope.admission_receipt_path;canonical_admission_receipt_path=[string]$Envelope.canonical_admission_receipt_path;admission_receipt_sha256=[string]$Envelope.admission_receipt_sha256;transaction_path=[string]$Envelope.transaction_path;transaction_sha256=[string]$Envelope.transaction_sha256;transaction_identity_sha256=[string]$Envelope.transaction_identity_sha256;transaction_content_sha256=[string]$Envelope.transaction_content_sha256;admission_status=[string]$Envelope.admission_status;admission_decision_sha256=[string]$Envelope.admission_decision_sha256;queue_authority_identity_sha256=[string]$Envelope.queue_authority_identity_sha256;expected_source_state=[string]$Envelope.expected_source_state;expected_destination_state=[string]$Envelope.expected_destination_state;actual_destination_queue_record_path=[string]$Envelope.actual_destination_queue_record_path;rollback_destination_path=[string]$Envelope.rollback_destination_path}
}

function New-TsfCanonicalRecoveryEnvelope {
    param([Parameter(Mandatory)][string]$ResultPath,[Parameter(Mandatory)][object]$Receipt,[Parameter(Mandatory)][string]$ReceiptFilePath,[Parameter(Mandatory)][string]$TransactionPath,[Parameter(Mandatory)][string]$QueueMissionPath,[Parameter(Mandatory)][string]$QueueRootPath,[Parameter(Mandatory)][object]$Storage,[Parameter(Mandatory)][string]$RepositoryRoot,[switch]$TestOnlyAllowAlternateQueueRoot)
    $result=Read-TsfKernelJson $ResultPath;$transaction=Read-TsfKernelJson $TransactionPath;$queueDocument=Read-TsfKernelJson $QueueMissionPath
    $resultHash=(Get-FileHash $ResultPath -Algorithm SHA256).Hash.ToLowerInvariant();$receiptHash=(Get-FileHash $ReceiptFilePath -Algorithm SHA256).Hash.ToLowerInvariant();$transactionHash=(Get-FileHash $TransactionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $presPath=Get-TsfKernelFullPath ([string]$Receipt.preservation_packet_path);$presHash=(Get-FileHash $presPath -Algorithm SHA256).Hash.ToLowerInvariant();$queueHash=Get-TsfContractJsonHash $queueDocument
    $queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRootPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
    $relationship=Test-TsfAdmissionRelationship $result $resultHash $presPath $presHash $Receipt $ReceiptFilePath $transaction $TransactionPath $queueDocument $queueHash $queueAuthority -CanonicalReceiptPath ([string]$Storage.admission) -ExpectedTransactionFileHash $transactionHash -ActualQueueRecordPath $QueueMissionPath -RepositoryRoot $RepositoryRoot
    if(!$relationship.valid){throw "RECOVERY_ENVELOPE_RELATIONSHIP_INVALID: $($relationship.errors -join '; ')"}
    if([string]$transaction.state-notin@('PREPARED','RECOVERY_REQUIRED')){throw 'RECOVERY_ENVELOPE_TRANSACTION_NOT_RECOVERABLE'}
    $envelope=[pscustomobject][ordered]@{schema_version='tsf_canonical_recovery_envelope_v1';created_at=[datetimeoffset]::UtcNow.ToString('o');mission_id=[string]$Receipt.mission_id;mission_revision=[int]$Receipt.mission_revision;mission_content_hash=[string]$Receipt.mission_content_hash;policy_fingerprint=[string]$Receipt.policy_fingerprint;queue_document_sha256=$queueHash;translator_version=[string]$Receipt.translator_version;result_id=[string]$Receipt.result_id;result_path=Get-TsfKernelFullPath $ResultPath;result_sha256=$resultHash;preservation_packet_path=$presPath;preservation_packet_sha256=$presHash;admission_receipt_path=Get-TsfKernelFullPath $ReceiptFilePath;canonical_admission_receipt_path=Get-TsfKernelFullPath ([string]$Storage.admission);admission_receipt_sha256=$receiptHash;transaction_path=Get-TsfKernelFullPath $TransactionPath;transaction_sha256=$transactionHash;transaction_identity_sha256=[string]$transaction.transaction_identity_sha256;transaction_content_sha256=[string]$transaction.transaction_content_sha256;admission_status=[string]$Receipt.status;admission_decision_sha256=[string]$Receipt.admission_decision_sha256;queue_authority_identity_sha256=[string]$queueAuthority.identity_sha256;expected_source_state=[string]$transaction.queue_state_to;expected_destination_state=[string]$transaction.queue_state_from;actual_destination_queue_record_path=Get-TsfKernelFullPath $QueueMissionPath;rollback_destination_path=Get-TsfKernelFullPath ([string]$transaction.source_path)}
    $envelope|Add-Member -NotePropertyName recovery_identity_sha256 -NotePropertyValue (Get-TsfContractJsonHash (Get-TsfRecoveryEnvelopeIdentity $envelope))
    $validation=Test-TsfJsonContract $envelope (Join-Path (Get-TsfKernelRoot) 'fleet\control\canonical-recovery-envelope.schema.v1.json');if(!$validation.valid){throw "Recovery envelope schema invalid: $($validation.errors -join '; ')"}
    if(Test-Path $Storage.recovery -PathType Leaf){$existing=Read-TsfKernelJson $Storage.recovery;if([string]$existing.recovery_identity_sha256-ne[string]$envelope.recovery_identity_sha256){throw 'IMMUTABLE_RECOVERY_ENVELOPE_CONFLICT'};return [pscustomobject]@{path=[string]$Storage.recovery;envelope=$existing;idempotent=$true}}
    Write-TsfAtomicJson $envelope $Storage.recovery $Storage.transaction_temp -NoReplace|Out-Null
    [pscustomobject]@{path=[string]$Storage.recovery;envelope=$envelope;idempotent=$false}
}

function Test-TsfCanonicalRecoveryEnvelope {
    param([Parameter(Mandatory)][string]$EnvelopePath,[Parameter(Mandatory)][string]$ExpectedMissionPath,[Parameter(Mandatory)][string]$ExpectedFromState,[Parameter(Mandatory)][string]$ExpectedToState,[Parameter(Mandatory)][string]$QueueRootPath,[Parameter(Mandatory)][string]$RepositoryRoot,[switch]$TestOnlyAllowAlternateQueueRoot)
    $errors=[Collections.Generic.List[string]]::new();$envelope=$null;$transaction=$null
    try{
        $envelope=Read-TsfKernelJson $EnvelopePath
        $schema=Test-TsfJsonContract $envelope (Join-Path (Get-TsfKernelFullPath $RepositoryRoot) 'fleet\control\canonical-recovery-envelope.schema.v1.json');if(!$schema.valid){$errors.Add("Recovery envelope schema invalid: $($schema.errors -join '; ')")|Out-Null}
        if([string]$envelope.recovery_identity_sha256-ne(Get-TsfContractJsonHash (Get-TsfRecoveryEnvelopeIdentity $envelope))){$errors.Add('Recovery envelope identity hash mismatch.')|Out-Null}
        $result=Read-TsfKernelJson ([string]$envelope.result_path);$receipt=Read-TsfKernelJson ([string]$envelope.admission_receipt_path);$transaction=Read-TsfKernelJson ([string]$envelope.transaction_path);$queueDocument=Read-TsfKernelJson ([string]$envelope.actual_destination_queue_record_path)
        $storage=Get-TsfAdmissionStorage $result ([string]$envelope.result_sha256) ([string]$envelope.preservation_packet_path) ([string]$envelope.preservation_packet_sha256)
        if(![string]::Equals((Get-TsfKernelFullPath $EnvelopePath),(Get-TsfKernelFullPath ([string]$storage.recovery)),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Recovery envelope path is not canonical for the transaction.')|Out-Null}
        $queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRootPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
        $relationship=Test-TsfAdmissionRelationship $result ([string]$envelope.result_sha256) ([string]$envelope.preservation_packet_path) ([string]$envelope.preservation_packet_sha256) $receipt ([string]$envelope.admission_receipt_path) $transaction ([string]$envelope.transaction_path) $queueDocument ([string]$envelope.queue_document_sha256) $queueAuthority -CanonicalReceiptPath ([string]$envelope.canonical_admission_receipt_path) -ExpectedTransactionFileHash ([string]$envelope.transaction_sha256) -ActualQueueRecordPath ([string]$envelope.actual_destination_queue_record_path) -RepositoryRoot $RepositoryRoot
        foreach($error in @($relationship.errors)){$errors.Add([string]$error)|Out-Null}
        foreach($pair in @(
            @([string]$envelope.mission_id,[string]$result.mission_id,'mission id'),
            @([string]$envelope.mission_revision,[string]$result.mission_revision,'mission revision'),
            @([string]$envelope.mission_content_hash,[string]$result.mission_content_hash,'mission content hash'),
            @([string]$envelope.policy_fingerprint,[string]$result.policy_fingerprint,'policy fingerprint'),
            @([string]$envelope.result_id,[string]$result.result_id,'result id'),
            @([string]$envelope.queue_document_sha256,[string]$receipt.queue_document_sha256,'queue document hash'),
            @([string]$envelope.translator_version,[string]$receipt.translator_version,'translator version'),
            @([string]$envelope.transaction_identity_sha256,[string]$transaction.transaction_identity_sha256,'transaction identity'),
            @([string]$envelope.transaction_content_sha256,[string]$transaction.transaction_content_sha256,'transaction content'),
            @([string]$envelope.admission_status,[string]$receipt.status,'admission status'),
            @([string]$envelope.admission_decision_sha256,[string]$receipt.admission_decision_sha256,'admission decision'),
            @([string]$envelope.queue_authority_identity_sha256,[string]$queueAuthority.identity_sha256,'queue authority identity')
        )){if([string]$pair[0]-ne[string]$pair[1]){$errors.Add("Recovery envelope/artifact mismatch: $($pair[2])")|Out-Null}}
        foreach($pair in @(
            @([string]$envelope.preservation_packet_path,[string]$receipt.preservation_packet_path,'preservation path'),
            @([string]$envelope.canonical_admission_receipt_path,[string]$receipt.admission_receipt_path,'canonical admission receipt path'),
            @([string]$envelope.transaction_path,[string]$receipt.transaction_receipt_path,'transaction path'),
            @([string]$envelope.actual_destination_queue_record_path,[string]$transaction.destination_path,'actual destination queue record path'),
            @([string]$envelope.rollback_destination_path,[string]$transaction.source_path,'rollback destination path')
        )){if(![string]::Equals((Get-TsfKernelFullPath $pair[0]),(Get-TsfKernelFullPath $pair[1]),[StringComparison]::OrdinalIgnoreCase)){$errors.Add("Recovery envelope/artifact mismatch: $($pair[2])")|Out-Null}}
        foreach($pair in @(@((Get-FileHash $envelope.result_path -Algorithm SHA256).Hash.ToLowerInvariant(),[string]$envelope.result_sha256,'result hash'),@((Get-FileHash $envelope.preservation_packet_path -Algorithm SHA256).Hash.ToLowerInvariant(),[string]$envelope.preservation_packet_sha256,'preservation hash'),@((Get-FileHash $envelope.admission_receipt_path -Algorithm SHA256).Hash.ToLowerInvariant(),[string]$envelope.admission_receipt_sha256,'receipt hash'),@((Get-FileHash $envelope.transaction_path -Algorithm SHA256).Hash.ToLowerInvariant(),[string]$envelope.transaction_sha256,'transaction hash'),@([string]$transaction.transaction_identity_sha256,[string]$envelope.transaction_identity_sha256,'transaction identity'),@([string]$transaction.transaction_content_sha256,[string]$envelope.transaction_content_sha256,'transaction content'),@([string]$receipt.admission_decision_sha256,[string]$envelope.admission_decision_sha256,'decision hash'),@([string]$receipt.status,[string]$envelope.admission_status,'admission status'),@([string]$queueAuthority.identity_sha256,[string]$envelope.queue_authority_identity_sha256,'queue authority'))){if([string]$pair[0]-ne[string]$pair[1]){$errors.Add("Recovery envelope mismatch: $($pair[2])")|Out-Null}}
        if([string]$envelope.expected_source_state-ne$ExpectedFromState-or[string]$envelope.expected_destination_state-ne$ExpectedToState-or[string]$transaction.queue_state_to-ne$ExpectedFromState-or[string]$transaction.queue_state_from-ne$ExpectedToState){$errors.Add('Recovery state relationship mismatch.')|Out-Null}
        if(![string]::Equals((Get-TsfKernelFullPath $ExpectedMissionPath),(Get-TsfKernelFullPath ([string]$envelope.actual_destination_queue_record_path)),[StringComparison]::OrdinalIgnoreCase)-or![string]::Equals((Get-TsfKernelFullPath ([string]$transaction.destination_path)),(Get-TsfKernelFullPath ([string]$envelope.actual_destination_queue_record_path)),[StringComparison]::OrdinalIgnoreCase)){$errors.Add('Recovery destination queue record mismatch.')|Out-Null}
        if([string]$transaction.state-notin@('PREPARED','RECOVERY_REQUIRED')){$errors.Add('Recovery transaction is not recoverable.')|Out-Null}
    }catch{$errors.Add("$($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]")|Out-Null}
    [pscustomobject]@{valid=$errors.Count-eq0;errors=@($errors);envelope=$envelope;transaction=$transaction}
}

function Write-TsfRecoveryConflictDiagnostic {
    param([Parameter(Mandatory)][string]$EnvelopePath,[Parameter(Mandatory)][string[]]$Errors)
    $full=Get-TsfKernelFullPath $EnvelopePath;$root=Get-TsfCanonicalRuntimeRoot
    if(!(Test-TsfKernelPathInside $full $root)){return $null}
    $parent=Split-Path -Parent $full;$sourceHash=if(Test-Path $full -PathType Leaf){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{Get-TsfRuntimeSha256Text $full};$key=ConvertTo-TsfRuntimeShortKey (Get-TsfRuntimeSha256Text "$full|$sourceHash|$($Errors -join '|')")
    $path=Join-Path $parent "k-$key.json";$temp=Join-Path $parent "y-$key.tmp"
    $diagnostic=[pscustomobject][ordered]@{schema_version='tsf_recovery_conflict_v1';recovery_envelope_path=$full;recovery_envelope_sha256=$sourceHash;errors=@($Errors);status='REJECTED_INVALID_EVIDENCE';recorded_at=[datetimeoffset]::UtcNow.ToString('o')}
    if(Test-Path $path -PathType Leaf){return $path};Write-TsfAtomicJson $diagnostic $path $temp -NoReplace|Out-Null;$path
}

function Get-TsfAdmissionDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResultPath,
        [Parameter(Mandatory)][string]$MissionRegistryPath,
        [Parameter(Mandatory)][string]$ActivePolicyManifestPath,
        [string]$ApprovalLedgerPath='',
        [Parameter(Mandatory)][string]$QueueMissionPath,
        [Parameter(Mandatory)][string]$QueueRootPath,
        [datetimeoffset]$CurrentTime=[datetimeoffset]::UtcNow,
        [switch]$UnsupportedDevelopmentMode,
        [switch]$TestOnlyAllowAlternateQueueRoot,
        [ValidateSet('NONE','TEMP_WRITE','QUEUE_TRANSITION','FINALIZE_ADMISSION','FINALIZE_TRANSACTION')][string]$TestFault='NONE'
    )

    $result=Read-TsfKernelJson $ResultPath
    $resultHash=(Get-FileHash -LiteralPath $ResultPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRootPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
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
    $queueDocument=Read-TsfKernelJson $QueueMissionPath;$queueCheck=Test-TsfCanonicalQueueDocument $queueDocument $mission;if(!$queueCheck.valid){throw "QUEUE_DOCUMENT_IDENTITY_MISMATCH: $($queueCheck.errors -join '; ')"}
    $queueDocumentHash=[string]$queueCheck.queue_document_sha256
    $translatorVersion=[string]$queueDocument.source_binding.translator_version
    $queueState=(Split-Path -Leaf (Split-Path -Parent (Get-TsfKernelFullPath $QueueMissionPath)))
    $storage=Get-TsfAdmissionStorage $result $resultHash $presPath ([string]$result.preservation_evidence.packet_sha256)
    if($TestFault-ne'NONE'){
        $fixtureRoot=Get-TsfKernelFullPath (Join-Path $script:TsfRoot '.codex-local\fixtures')
        if(!$UnsupportedDevelopmentMode-or![string]$result.mission_id.StartsWith('synthetic-')-or!(Test-TsfKernelPathInside (Get-TsfKernelFullPath $QueueRootPath) $fixtureRoot)){throw 'Admission test faults are restricted to synthetic .codex-local fixtures in unsupported development mode.'}
    }
    if(Test-Path -LiteralPath $storage.admission){
        $old=Read-TsfKernelJson $storage.admission
        if([string]$old.receipt_identity_sha256-ne[string]$storage.identity_sha256){throw 'Admission receipt short-key collision detected.'}
        if([string]$old.mission_content_hash-ne[string]$result.mission_content_hash-or[string]$old.policy_fingerprint-ne[string]$result.policy_fingerprint-or[string]$old.queue_document_sha256-ne$queueDocumentHash-or[string]$old.translator_version-ne$translatorVersion){throw 'REPLAY_QUEUE_IDENTITY_MISMATCH'}
        if(![string]::Equals((Get-TsfKernelFullPath $QueueMissionPath),(Get-TsfKernelFullPath ([string]$old.queue_transition_path)),[StringComparison]::OrdinalIgnoreCase)-or$queueState-ne[string]$old.queue_state_to){throw 'REPLAY_QUEUE_DESTINATION_MISMATCH'}
        if([string]$old.result_sha256-eq$resultHash){
            if(!(Test-Path -LiteralPath $storage.transaction)){throw 'Admission receipt exists without its mandatory transaction receipt.'}
            $transaction=Read-TsfKernelJson $storage.transaction
            $relationship=Test-TsfAdmissionRelationship $result $resultHash $presPath ([string]$result.preservation_evidence.packet_sha256) $old $storage.admission $transaction $storage.transaction $queueDocument $queueDocumentHash $queueAuthority -ActualQueueRecordPath $QueueMissionPath -RepositoryRoot $script:TsfRoot
            if(!$relationship.valid){throw "RECOVERY_QUEUE_IDENTITY_MISMATCH: $($relationship.errors -join '; ')"}
            if([string]$transaction.receipt_identity_sha256-ne[string]$storage.identity_sha256-or![string]::Equals((Get-TsfKernelFullPath ([string]$transaction.destination_path)),(Get-TsfKernelFullPath $QueueMissionPath),[StringComparison]::OrdinalIgnoreCase)){throw 'RECOVERY_QUEUE_IDENTITY_MISMATCH'}
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

    $repo=[string]$translation.mission_packet.repo_path;$git=Get-TsfKernelGitState $repo
    if(!$git.can_capture-or![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_repository)).TrimEnd('\','/'),$repo.TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add('Observed repository identity is unavailable or mismatched.')|Out-Null}
    if($status-eq'ADMITTED'-and![bool]$mission.branch_worktree_policy.branch_required-and([string]$result.git_facts.starting_head-ne[string]$mission.branch_worktree_policy.starting_head-or[string]$result.git_facts.ending_head-ne[string]$mission.branch_worktree_policy.starting_head-or[string]$git.head-ne[string]$mission.branch_worktree_policy.starting_head)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Detached read-only execution did not remain on the exact immutable HEAD commit.')|Out-Null}
    if($status-eq'ADMITTED'-and[bool]$mission.branch_worktree_policy.branch_required-and[string]$result.actual_branch_worktree.branch-ne[string]$mission.branch_worktree_policy.expected_branch){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed branch violates durable mission policy.')|Out-Null}
    if($status-eq'ADMITTED'-and[bool]$mission.branch_worktree_policy.worktree_required-and![string]::Equals((Get-TsfKernelFullPath ([string]$result.actual_branch_worktree.worktree)).TrimEnd('\','/'),(Get-TsfKernelFullPath ([string]$mission.branch_worktree_policy.expected_worktree)).TrimEnd('\','/'),[StringComparison]::OrdinalIgnoreCase)){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed worktree violates durable mission policy.')|Out-Null}
    if($status-eq'ADMITTED'){foreach($p in @($result.files_changed)){if(!(Test-TsfKernelPathContained $p $repo @($mission.allowed_writes))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Changed path is outside canonical allowed_writes: $p")|Out-Null;break}}}
    if($status-eq'ADMITTED'){foreach($p in @($result.files_inspected)){if(!(Test-TsfKernelPathContained $p $repo @($mission.allowed_reads))){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add("Inspected path is outside canonical allowed_reads: $p")|Out-Null;break}}}
    $networkObservationUnknown=$false
    if($status-eq'ADMITTED'){
        if([string]$result.network_activity.control_plane_service_network_policy-ne[string]$mission.control_plane_service_network_policy-or[string]$result.network_activity.worker_tool_network_policy-ne'DISABLED'-or$result.network_activity.worker_network_used-eq$true-or$result.network_activity.direct_openai_api_called_by_tsf-eq$true-or$result.network_activity.external_api_called-eq$true){$status='REJECTED_OUT_OF_SCOPE';$reasons.Add('Observed network policy evidence violates the durable mission.')|Out-Null}
        elseif($null-eq$result.network_activity.worker_network_used-or$null-eq$result.network_activity.direct_openai_api_called_by_tsf-or$null-eq$result.network_activity.external_api_called){$networkObservationUnknown=$true;$caveats.Add('Worker/external network non-use is configured and policy-prohibited but not promoted to an observed runtime fact.')|Out-Null}
    }
    if($status-eq'ADMITTED'){foreach($a in @($result.artifacts)){$scopes=if(@($mission.allowed_writes).Count){@($mission.allowed_writes)}else{@($mission.allowed_reads)};if($a.evidence_classification-ne'FILESYSTEM_OBSERVED'-or!(Test-TsfKernelPathContained $a.path $repo $scopes)){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact is not filesystem-bound: $($a.path)")|Out-Null;break};$full=Get-TsfKernelFullPath $a.path $repo;$observed=if(Test-Path $full -PathType Leaf){(Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()}else{''};if($observed-ne[string]$a.sha256){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("Artifact hash mismatch: $($a.path)")|Out-Null;break}}}
    if($status-eq'ADMITTED'){$testEvidenceCheck=Test-TsfRequiredTestEvidence -Mission $mission -Result $result;if(!$testEvidenceCheck.valid){$status='REJECTED_INVALID_EVIDENCE';foreach($error in $testEvidenceCheck.errors){$reasons.Add([string]$error)|Out-Null}}}
    if($status-eq'ADMITTED'-and[string]$mission.result_validation_mode-eq'GENERAL_RESULT_V2'){
        $generalAdmissionCheck=Test-TsfGeneralResultV2AdmissionEvidence -Mission $mission -Result $result
        if(!$generalAdmissionCheck.valid){$status='REJECTED_INVALID_EVIDENCE';$reasons.Add("GENERAL_RESULT_V2 admission evidence is invalid: $($generalAdmissionCheck.errors -join ', ')")|Out-Null}
    }
    if($status-eq'ADMITTED'-and![string]::IsNullOrWhiteSpace([string]$mission.expires_at)-and$CurrentTime-gt[datetimeoffset]::Parse([string]$mission.expires_at)){$status=if($mission.stale_state_behavior-eq'TIM_REQUIRED'){'TIM_REQUIRED'}elseif($mission.stale_state_behavior-eq'REJECT'){'REJECTED_INVALID_EVIDENCE'}else{'REVIEW_REQUIRED'};$reasons.Add('Durable mission expired before admission.')|Out-Null}

    $required=@($mission.approval_references);$used=@($result.approval_use|Where-Object{$_.used})
    if($required.Count-ne$used.Count){$status='TIM_REQUIRED';$reasons.Add('Every required approval must have exactly one observed use record.')|Out-Null}
    if($required.Count-or$used.Count){try{$ledger=Get-TsfKernelApprovalLedger $ApprovalLedgerPath;$native=@(Find-TsfKernelApprovalMatches $translation.mission_packet $ledger $ApprovalLedgerPath -CurrentTime $CurrentTime -RequireCanonicalUsageBinding -ExpectedConsumedRunId ([string]$result.result_id));foreach($r in $required){$u=@($used|Where-Object{$_.approval_id-eq$r.approval_id-and$_.exact_action-eq$r.exact_action});$m=@($native|Where-Object{$_.approval_id-eq$r.approval_id-and$_.exact_action-eq$r.exact_action-and$_.satisfied});if($u.Count-ne1-or$m.Count-ne1){$status='TIM_REQUIRED';$reasons.Add("Approval failed canonical resolution: $($r.approval_id)")|Out-Null}}}catch{$status='TIM_REQUIRED';$reasons.Add($_.Exception.Message)|Out-Null}}
    if($status-eq'ADMITTED'-and[string]$mission.required_verifier_independence-ne'NONE'-and@($result.verifier_evidence|Where-Object{$_.independence-eq$mission.required_verifier_independence-and$_.passed-and$_.evidence_classification-eq'VERIFIER_OBSERVED'}).Count-ne1){$status='REVIEW_REQUIRED';$reasons.Add('Canonical independent verifier evidence is missing.')|Out-Null}
    if($status-eq'ADMITTED'-and([string]$result.actual_model-ne[string]$translation.model_resolution.resolved_model-or[string]$result.model_assurance_level-ne'ADAPTER_VERIFIED')){$status='REVIEW_REQUIRED';$reasons.Add('Observed model does not match the canonical adapter-bound resolution.')|Out-Null}
    if($status-eq'ADMITTED'){
        $effortEffect=[string]$result.effort_evidence.effort_admission_effect
        if($effortEffect-ne'ADMITTED'){$status=$effortEffect}
        if($effortEffect-eq'ADMITTED_WITH_CAVEATS'){$caveats.Add('Effective turn effort was not exposed; the correct explicit turn request is admitted under RECOMMENDED_ONLY assurance.')|Out-Null}
        elseif($effortEffect-ne'ADMITTED'){$reasons.Add("Effort evidence admission effect: $effortEffect")|Out-Null}
        foreach($conflict in @($result.effort_evidence.effort_conflicts)){$caveats.Add([string]$conflict)|Out-Null}
    }
    if($status-eq'ADMITTED'-and$networkObservationUnknown){$status='ADMITTED_WITH_CAVEATS'}

    if($reasons.Count-eq0){$reasons.Add('Observed runtime evidence satisfied the canonical durable mission.')|Out-Null}
    $target=Get-TsfAdmissionQueueTarget $status
    $dryRun=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $QueueMissionPath -FromState 'postrun_pending' -ToState $target -QueueRoot $QueueRootPath -DryRun -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
    if([string]$dryRun.verdict-ne'GREEN'){throw "Canonical queue transition preflight failed: $($dryRun.blocked_reasons -join '; ')"}
    $receipt=New-TsfAdmissionReceipt $result $resultHash $status @($reasons) @($caveats) $CurrentTime 'postrun_pending' $target $true ([string]$dryRun.destination_path) $storage $presPath ([string]$result.preservation_evidence.packet_sha256) $queueDocumentHash $translatorVersion $queueAuthority
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
        $transition=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $QueueMissionPath -FromState 'postrun_pending' -ToState $target -QueueRoot $QueueRootPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
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
        $committedRelationship=Test-TsfAdmissionRelationship $result $resultHash $presPath ([string]$result.preservation_evidence.packet_sha256) $receipt $storage.admission $committed $storage.transaction $queueDocument $queueDocumentHash $queueAuthority -ActualQueueRecordPath ([string]$transition.destination_path) -RepositoryRoot $script:TsfRoot
        if([string]$committed.state-ne'COMMITTED'-or!(Test-Path -LiteralPath $storage.admission)-or!$committedRelationship.valid){throw "Admission transaction did not durably commit: $($committedRelationship.errors -join '; ')"}
        return $receipt
    }catch{
        $failure=$_.Exception.Message
        if($moved-and!$admissionFinalized){
            try{
                $recoveryEnvelope=New-TsfCanonicalRecoveryEnvelope -ResultPath $ResultPath -Receipt $receipt -ReceiptFilePath $storage.admission_temp -TransactionPath $storage.transaction -QueueMissionPath ([string]$dryRun.destination_path) -QueueRootPath $QueueRootPath -Storage $storage -RepositoryRoot $script:TsfRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
                $rollback=&(Join-Path $script:TsfRoot 'tools\Move-TsfMissionState.ps1') -MissionPath ([string]$dryRun.destination_path) -FromState $target -ToState 'postrun_pending' -QueueRoot $QueueRootPath -RecoveryEnvelopePath ([string]$recoveryEnvelope.path) -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
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
