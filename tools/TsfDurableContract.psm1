$ErrorActionPreference = "Stop"

$script:TsfRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $script:TsfRoot "tools\codex-fleet-enforcement-kernel.ps1")

$script:MissionSchemaVersion = "tsf_mission_envelope_v1"
$script:ResultSchemaVersion = "tsf_result_envelope_v1"
$script:AdmissionSchemaVersion = "tsf_admission_decision_v1"
$script:PolicyManifestVersion = "tsf_policy_manifest_v1"
$script:ModelAliases = @("FAST", "BALANCED", "DEEP", "MAX_SINGLE", "PARALLEL")
$script:AssuranceLevels = @("RECOMMENDED_ONLY", "USER_CONFIRMED", "ADAPTER_VERIFIED", "TECHNICALLY_ENFORCED")
$script:AdmissionStatuses = @("ADMITTED", "ADMITTED_WITH_CAVEATS", "REVIEW_REQUIRED", "REJECTED_OUT_OF_SCOPE", "REJECTED_POLICY_MISMATCH", "REJECTED_INVALID_EVIDENCE", "UNTRUSTED_NOT_TSF_GOVERNED", "TIM_REQUIRED")

function Test-TsfContractProperty {
    param([object]$Object, [string]$Name)
    return ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name)
}

function ConvertTo-TsfContractArray {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [System.Collections.IDictionary]) { return @($Value) }
    return @($Value)
}

function Get-TsfContractJsonHash {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 100 -Compress
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Test-TsfContractDateTime {
    param([AllowNull()][object]$Value, [switch]$AllowNull)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return [bool]$AllowNull }
    $parsed = [datetimeoffset]::MinValue
    return [datetimeoffset]::TryParse([string]$Value, [ref]$parsed)
}

function Test-TsfContractSha256 {
    param([AllowNull()][object]$Value, [switch]$AllowNull)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return [bool]$AllowNull }
    return ([string]$Value -cmatch '^[a-f0-9]{64}$')
}

function Test-TsfContractStringArray {
    param([AllowNull()][object]$Value, [string]$Field, [bool]$RequireNonEmpty, [System.Collections.Generic.List[string]]$Errors)
    if ($null -eq $Value) { $Errors.Add("$Field must be an array.") | Out-Null; return }
    $items = @(ConvertTo-TsfContractArray -Value $Value)
    if ($RequireNonEmpty -and $items.Count -eq 0) { $Errors.Add("$Field must not be empty.") | Out-Null }
    foreach ($item in $items) {
        if ([string]::IsNullOrWhiteSpace([string]$item)) { $Errors.Add("$Field contains an empty value.") | Out-Null }
    }
    $normalized = @($items | ForEach-Object { [string]$_ })
    if (@($normalized | Select-Object -Unique).Count -ne $normalized.Count) { $Errors.Add("$Field contains duplicate values.") | Out-Null }
}

function Get-TsfPolicyFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [string]$RepositoryRoot = $script:TsfRoot,
        [string]$GitCommit = ""
    )

    $root = Get-TsfKernelFullPath -Path $RepositoryRoot
    $manifestFull = Get-TsfKernelFullPath -Path $ManifestPath -BasePath $root
    if (!(Test-TsfKernelPathInside -Child $manifestFull -Parent $root)) { throw "Policy manifest must be inside the repository root." }
    $manifest = Read-TsfKernelJson -Path $manifestFull
    if ([string]$manifest.schema_version -ne $script:PolicyManifestVersion) { throw "Unsupported policy manifest version: $($manifest.schema_version)" }
    if (!(Test-TsfContractProperty -Object $manifest -Name "governing_files") -or @($manifest.governing_files).Count -eq 0) { throw "Policy manifest must declare governing_files." }
    if ([string]::IsNullOrWhiteSpace($GitCommit)) {
        $GitCommit = (& git -C $root rev-parse HEAD 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($GitCommit)) { throw "Could not resolve repository Git commit." }
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    foreach ($relativePathValue in @($manifest.governing_files)) {
        $relativePath = ([string]$relativePathValue).Replace("\", "/").Trim()
        if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|/)\.\.(/|$)') {
            throw "Unsafe governing policy path: $relativePath"
        }
        if ($seen.ContainsKey($relativePath.ToLowerInvariant())) { throw "Duplicate governing policy path: $relativePath" }
        $seen[$relativePath.ToLowerInvariant()] = $true
        $fullPath = Get-TsfKernelFullPath -Path $relativePath -BasePath $root
        if (!(Test-TsfKernelPathInside -Child $fullPath -Parent $root)) { throw "Governing policy path escapes repository: $relativePath" }
        if (!(Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Governing policy file is missing: $relativePath" }
        $entries.Add([pscustomobject]@{ path = $relativePath; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant() }) | Out-Null
    }

    $schemaVersions = [ordered]@{}
    foreach ($property in $manifest.schema_versions.PSObject.Properties) { $schemaVersions[$property.Name] = [string]$property.Value }
    $canonical = [ordered]@{
        policy_manifest_version = [string]$manifest.schema_version
        git_commit = $GitCommit
        schema_versions = $schemaVersions
        files = @($entries)
    }
    $canonicalJson = $canonical | ConvertTo-Json -Depth 30 -Compress
    $fingerprint = Get-TsfContractJsonHash -Value ([pscustomobject]$canonical)
    return [pscustomobject]@{
        schema_version = "tsf_policy_fingerprint_v1"
        policy_manifest_version = [string]$manifest.schema_version
        policy_commit = $GitCommit
        fingerprint = $fingerprint
        governing_file_count = $entries.Count
        governing_files = @($entries)
        schema_versions = [pscustomobject]$schemaVersions
        canonical_input = $canonicalJson
        contains_secrets = $false
    }
}

function Test-TsfMissionEnvelope {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Mission)
    $errors = [System.Collections.Generic.List[string]]::new()
    $required = @(
        "schema_version", "mission_id", "parent_mission_id", "project_id", "original_request", "normalized_goal", "mission_type", "worker_role",
        "recommended_surface", "model_policy_alias", "resolved_model", "reasoning_effort", "model_selection_assurance", "permission_mode", "network_policy",
        "repository_allowlist", "forbidden_repositories", "source_allowlist", "forbidden_sources", "branch_worktree_policy", "allowed_reads", "allowed_writes",
        "forbidden_actions", "completion_criteria", "required_tests", "required_artifacts", "required_verifier_independence", "stop_conditions", "approval_references",
        "policy", "created_at", "expires_at", "stale_state_behavior", "required_result_envelope_version"
    )
    foreach ($field in $required) { if (!(Test-TsfContractProperty -Object $Mission -Name $field)) { $errors.Add("Missing required field: $field") | Out-Null } }
    if ($errors.Count -eq 0) {
        if ([string]$Mission.schema_version -ne $script:MissionSchemaVersion) { $errors.Add("Unsupported mission schema_version.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace([string]$Mission.mission_id) -or [string]$Mission.mission_id -notmatch '^[A-Za-z0-9._:-]{8,160}$') { $errors.Add("mission_id is invalid.") | Out-Null }
        foreach ($field in @("project_id", "original_request", "normalized_goal", "mission_type", "worker_role", "recommended_surface")) {
            if ([string]::IsNullOrWhiteSpace([string]$Mission.$field)) { $errors.Add("$field must not be empty.") | Out-Null }
        }
        if ($script:ModelAliases -notcontains [string]$Mission.model_policy_alias) { $errors.Add("model_policy_alias is not a stable V1 alias.") | Out-Null }
        if ($script:AssuranceLevels -notcontains [string]$Mission.model_selection_assurance) { $errors.Add("model_selection_assurance is invalid.") | Out-Null }
        if (@("UNKNOWN", "LIGHT", "MEDIUM", "HIGH", "EXTRA_HIGH", "MAX", "ULTRA") -notcontains [string]$Mission.reasoning_effort) { $errors.Add("reasoning_effort is invalid.") | Out-Null }
        if (@("READ_ONLY", "WORKSPACE_WRITE", "APPROVAL_REQUIRED", "EXACT_ELEVATED_ACTION", "CUSTOM") -notcontains [string]$Mission.permission_mode) { $errors.Add("permission_mode is invalid.") | Out-Null }
        if (@("PROHIBITED", "PUBLIC_READ_ONLY", "ALLOWLISTED", "APPROVAL_REQUIRED") -notcontains [string]$Mission.network_policy) { $errors.Add("network_policy is invalid.") | Out-Null }
        Test-TsfContractStringArray -Value $Mission.repository_allowlist -Field "repository_allowlist" -RequireNonEmpty $true -Errors $errors
        Test-TsfContractStringArray -Value $Mission.forbidden_repositories -Field "forbidden_repositories" -RequireNonEmpty $false -Errors $errors
        Test-TsfContractStringArray -Value $Mission.source_allowlist -Field "source_allowlist" -RequireNonEmpty $false -Errors $errors
        Test-TsfContractStringArray -Value $Mission.forbidden_sources -Field "forbidden_sources" -RequireNonEmpty $false -Errors $errors
        Test-TsfContractStringArray -Value $Mission.allowed_reads -Field "allowed_reads" -RequireNonEmpty $true -Errors $errors
        Test-TsfContractStringArray -Value $Mission.allowed_writes -Field "allowed_writes" -RequireNonEmpty $false -Errors $errors
        Test-TsfContractStringArray -Value $Mission.forbidden_actions -Field "forbidden_actions" -RequireNonEmpty $true -Errors $errors
        Test-TsfContractStringArray -Value $Mission.completion_criteria -Field "completion_criteria" -RequireNonEmpty $true -Errors $errors
        Test-TsfContractStringArray -Value $Mission.stop_conditions -Field "stop_conditions" -RequireNonEmpty $true -Errors $errors
        if (!(Test-TsfContractDateTime -Value $Mission.created_at)) { $errors.Add("created_at is not a valid timestamp.") | Out-Null }
        if (!(Test-TsfContractDateTime -Value $Mission.expires_at -AllowNull)) { $errors.Add("expires_at is not null or a valid timestamp.") | Out-Null }
        if (@("REVIEW_REQUIRED", "TIM_REQUIRED", "REJECT") -notcontains [string]$Mission.stale_state_behavior) { $errors.Add("stale_state_behavior is invalid.") | Out-Null }
        if ([string]$Mission.required_result_envelope_version -ne $script:ResultSchemaVersion) { $errors.Add("required_result_envelope_version is unsupported.") | Out-Null }
        $branch = $Mission.branch_worktree_policy
        foreach ($field in @("branch_required", "worktree_required", "expected_branch", "expected_worktree", "starting_head", "unexpected_advance_behavior")) {
            if (!(Test-TsfContractProperty -Object $branch -Name $field)) { $errors.Add("branch_worktree_policy missing $field.") | Out-Null }
        }
        if ([bool]$branch.branch_required -and [string]::IsNullOrWhiteSpace([string]$branch.expected_branch)) { $errors.Add("expected_branch is required by branch policy.") | Out-Null }
        if ([bool]$branch.worktree_required -and [string]::IsNullOrWhiteSpace([string]$branch.expected_worktree)) { $errors.Add("expected_worktree is required by worktree policy.") | Out-Null }
        $policy = $Mission.policy
        foreach ($field in @("policy_commit", "manifest_version", "fingerprint", "mission_schema_version", "expected_result_schema_version")) {
            if (!(Test-TsfContractProperty -Object $policy -Name $field)) { $errors.Add("policy missing $field.") | Out-Null }
        }
        if (!(Test-TsfContractSha256 -Value $policy.fingerprint)) { $errors.Add("policy fingerprint must be lowercase SHA-256.") | Out-Null }
        if ([string]$policy.manifest_version -ne $script:PolicyManifestVersion -or [string]$policy.mission_schema_version -ne $script:MissionSchemaVersion -or [string]$policy.expected_result_schema_version -ne $script:ResultSchemaVersion) { $errors.Add("policy schema version linkage is invalid.") | Out-Null }
        foreach ($test in @(ConvertTo-TsfContractArray -Value $Mission.required_tests)) {
            if ([string]::IsNullOrWhiteSpace([string]$test.test_id) -or !(Test-TsfContractProperty -Object $test -Name "required")) { $errors.Add("required_tests entry is invalid.") | Out-Null }
        }
        foreach ($artifact in @(ConvertTo-TsfContractArray -Value $Mission.required_artifacts)) {
            if ([string]::IsNullOrWhiteSpace([string]$artifact.path) -or !(Test-TsfContractProperty -Object $artifact -Name "hash_required")) { $errors.Add("required_artifacts entry is invalid.") | Out-Null }
        }
        if (@("NONE", "SEPARATE_TASK", "SEPARATE_ROLE", "INDEPENDENT_HUMAN") -notcontains [string]$Mission.required_verifier_independence) { $errors.Add("required_verifier_independence is invalid.") | Out-Null }
    }
    return [pscustomobject]@{ schema_version = "tsf_mission_envelope_validation_v1"; valid = ($errors.Count -eq 0); errors = @($errors) }
}

function Test-TsfResultEnvelope {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Result)
    $errors = [System.Collections.Generic.List[string]]::new()
    $required = @(
        "schema_version", "result_id", "mission_id", "parent_mission_id", "policy_fingerprint", "surface_used", "surface_task_identity", "actual_model",
        "actual_reasoning_effort", "model_assurance_level", "actual_repository", "actual_branch_worktree", "git_facts", "files_inspected", "files_changed",
        "major_actions", "network_activity", "artifacts", "tests", "verifier_evidence", "approval_use", "deviations_from_mission", "uncertainty",
        "security_or_scope_warnings", "proposed_next_action", "authority_statement", "grants_approval", "grants_merge_authority", "grants_production_authority", "created_at"
    )
    foreach ($field in $required) { if (!(Test-TsfContractProperty -Object $Result -Name $field)) { $errors.Add("Missing required field: $field") | Out-Null } }
    if ($errors.Count -eq 0) {
        if ([string]$Result.schema_version -ne $script:ResultSchemaVersion) { $errors.Add("Unsupported result schema_version.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace([string]$Result.result_id) -or [string]$Result.result_id -notmatch '^[A-Za-z0-9._:-]{8,160}$') { $errors.Add("result_id is invalid.") | Out-Null }
        if (![string]::IsNullOrWhiteSpace([string]$Result.policy_fingerprint) -and !(Test-TsfContractSha256 -Value $Result.policy_fingerprint)) { $errors.Add("policy_fingerprint must be null or lowercase SHA-256.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace([string]$Result.surface_used)) { $errors.Add("surface_used must not be empty.") | Out-Null }
        if ($script:AssuranceLevels -notcontains [string]$Result.model_assurance_level) { $errors.Add("model_assurance_level is invalid.") | Out-Null }
        if (@("UNKNOWN", "LIGHT", "MEDIUM", "HIGH", "EXTRA_HIGH", "MAX", "ULTRA") -notcontains [string]$Result.actual_reasoning_effort) { $errors.Add("actual_reasoning_effort is invalid.") | Out-Null }
        foreach ($field in @("files_inspected", "files_changed", "major_actions", "deviations_from_mission", "uncertainty", "security_or_scope_warnings")) {
            Test-TsfContractStringArray -Value $Result.$field -Field $field -RequireNonEmpty $false -Errors $errors
        }
        if (!(Test-TsfContractDateTime -Value $Result.created_at)) { $errors.Add("created_at is not a valid timestamp.") | Out-Null }
        foreach ($field in @("branch", "worktree")) { if (!(Test-TsfContractProperty -Object $Result.actual_branch_worktree -Name $field)) { $errors.Add("actual_branch_worktree missing $field.") | Out-Null } }
        foreach ($field in @("starting_head", "ending_head", "base_head", "dirty_before", "dirty_after")) { if (!(Test-TsfContractProperty -Object $Result.git_facts -Name $field)) { $errors.Add("git_facts missing $field.") | Out-Null } }
        foreach ($field in @("status", "used", "destinations")) { if (!(Test-TsfContractProperty -Object $Result.network_activity -Name $field)) { $errors.Add("network_activity missing $field.") | Out-Null } }
        foreach ($artifact in @(ConvertTo-TsfContractArray -Value $Result.artifacts)) {
            foreach ($field in @("path", "sha256", "exists")) { if (!(Test-TsfContractProperty -Object $artifact -Name $field)) { $errors.Add("artifact entry missing $field.") | Out-Null } }
            if (![string]::IsNullOrWhiteSpace([string]$artifact.sha256) -and !(Test-TsfContractSha256 -Value $artifact.sha256)) { $errors.Add("artifact hash is invalid.") | Out-Null }
        }
        foreach ($test in @(ConvertTo-TsfContractArray -Value $Result.tests)) {
            if ([string]::IsNullOrWhiteSpace([string]$test.test_id) -or @("PASS", "FAIL", "NOT_RUN", "UNKNOWN") -notcontains [string]$test.status) { $errors.Add("test evidence entry is invalid.") | Out-Null }
        }
        foreach ($verifier in @(ConvertTo-TsfContractArray -Value $Result.verifier_evidence)) {
            if ([string]::IsNullOrWhiteSpace([string]$verifier.verifier_id) -or @("NONE", "SEPARATE_TASK", "SEPARATE_ROLE", "INDEPENDENT_HUMAN") -notcontains [string]$verifier.independence -or !(Test-TsfContractProperty -Object $verifier -Name "passed")) { $errors.Add("verifier evidence entry is invalid.") | Out-Null }
        }
        if ([string]::IsNullOrWhiteSpace([string]$Result.proposed_next_action) -or [string]::IsNullOrWhiteSpace([string]$Result.authority_statement)) { $errors.Add("proposed_next_action and authority_statement must not be empty.") | Out-Null }
    }
    return [pscustomobject]@{ schema_version = "tsf_result_envelope_validation_v1"; valid = ($errors.Count -eq 0); errors = @($errors) }
}

function Normalize-TsfScopePath {
    param([string]$Value)
    return ([string]$Value).Replace("\", "/").Trim().TrimEnd("/").ToLowerInvariant()
}

function Test-TsfValueInScope {
    param([string]$Value, [object[]]$Scopes)
    $candidate = Normalize-TsfScopePath -Value $Value
    foreach ($scopeValue in @($Scopes)) {
        $scope = Normalize-TsfScopePath -Value ([string]$scopeValue)
        if ($candidate -eq $scope -or $candidate.StartsWith($scope + "/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function New-TsfAdmissionReceiptObject {
    param([object]$Result, [string]$ResultHash, [string]$Status, [string[]]$Reasons, [string[]]$Caveats, [datetimeoffset]$Now)
    $resultId = if (Test-TsfContractProperty -Object $Result -Name "result_id") { [string]$Result.result_id } else { "unknown-result" }
    $missionId = if (Test-TsfContractProperty -Object $Result -Name "mission_id") { $Result.mission_id } else { $null }
    return [pscustomobject][ordered]@{
        schema_version = $script:AdmissionSchemaVersion
        receipt_id = "admission-$($resultId)-$($ResultHash.Substring(0, 12))"
        result_id = $resultId
        mission_id = $missionId
        result_sha256 = $ResultHash
        status = $Status
        reasons = @($Reasons)
        caveats = @($Caveats)
        duplicate_submission = $false
        idempotent_replay = $false
        decided_at = $Now.ToUniversalTime().ToString("o")
        grants_approval = $false
        grants_merge_authority = $false
        grants_production_authority = $false
    }
}

function Write-TsfAdmissionReceiptIfRequested {
    param([object]$Receipt, [string]$ReceiptDirectory)
    if ([string]::IsNullOrWhiteSpace($ReceiptDirectory)) { return }
    New-Item -ItemType Directory -Path $ReceiptDirectory -Force | Out-Null
    $safeResultId = ([string]$Receipt.result_id) -replace '[^A-Za-z0-9._-]', '_'
    Write-TsfKernelJson -Value $Receipt -Path (Join-Path $ReceiptDirectory "$safeResultId.admission.json")
}

function Get-TsfAdmissionDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ResultPath,
        [Parameter(Mandatory = $true)][string]$MissionRegistryPath,
        [string]$ActivePolicyFingerprint = "",
        [string]$ReceiptDirectory = "",
        [datetimeoffset]$CurrentTime = [datetimeoffset]::UtcNow
    )
    $result = Read-TsfKernelJson -Path $ResultPath
    $resultHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ResultPath).Hash.ToLowerInvariant()
    $resultValidation = Test-TsfResultEnvelope -Result $result
    $status = "ADMITTED"
    $reasons = [System.Collections.Generic.List[string]]::new()
    $caveats = [System.Collections.Generic.List[string]]::new()

    if (!(Test-TsfContractProperty -Object $result -Name "mission_id") -or [string]::IsNullOrWhiteSpace([string]$result.mission_id)) {
        $status = "UNTRUSTED_NOT_TSF_GOVERNED"
        $reasons.Add("Result has no TSF mission_id.") | Out-Null
        $receipt = New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
        Write-TsfAdmissionReceiptIfRequested -Receipt $receipt -ReceiptDirectory $ReceiptDirectory
        return $receipt
    }

    $mission = $null
    foreach ($candidatePath in @(Get-ChildItem -LiteralPath $MissionRegistryPath -Filter "*.json" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)) {
        try {
            $candidate = Read-TsfKernelJson -Path $candidatePath
            if ((Test-TsfContractProperty -Object $candidate -Name "mission_id") -and [string]$candidate.mission_id -eq [string]$result.mission_id) { $mission = $candidate; break }
        } catch { }
    }
    if ($null -eq $mission) {
        $status = "UNTRUSTED_NOT_TSF_GOVERNED"
        $reasons.Add("No registered TSF mission matches mission_id '$($result.mission_id)'.") | Out-Null
        $receipt = New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
        Write-TsfAdmissionReceiptIfRequested -Receipt $receipt -ReceiptDirectory $ReceiptDirectory
        return $receipt
    }

    if (!$resultValidation.valid) {
        $status = "REJECTED_INVALID_EVIDENCE"
        foreach ($errorText in @($resultValidation.errors)) { $reasons.Add([string]$errorText) | Out-Null }
        $receipt = New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
        Write-TsfAdmissionReceiptIfRequested -Receipt $receipt -ReceiptDirectory $ReceiptDirectory
        return $receipt
    }
    $missionValidation = Test-TsfMissionEnvelope -Mission $mission
    if (!$missionValidation.valid) {
        $status = "REJECTED_INVALID_EVIDENCE"
        $reasons.Add("Registered mission is invalid and cannot govern admission.") | Out-Null
        $receipt = New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
        Write-TsfAdmissionReceiptIfRequested -Receipt $receipt -ReceiptDirectory $ReceiptDirectory
        return $receipt
    }

    if (![string]::IsNullOrWhiteSpace($ReceiptDirectory)) {
        New-Item -ItemType Directory -Path $ReceiptDirectory -Force | Out-Null
        $safeResultId = ([string]$result.result_id) -replace '[^A-Za-z0-9._-]', '_'
        $receiptPath = Join-Path $ReceiptDirectory "$safeResultId.admission.json"
        if (Test-Path -LiteralPath $receiptPath) {
            $existing = Read-TsfKernelJson -Path $receiptPath
            if ([string]$existing.result_sha256 -eq $resultHash) {
                $existing.duplicate_submission = $true
                $existing.idempotent_replay = $true
                $existing.reasons = @($existing.reasons) + @("Exact duplicate result returned the preserved admission decision without a second admission side effect.")
                return $existing
            }
            $status = "REJECTED_INVALID_EVIDENCE"
            $reasons.Add("result_id was reused with different content.") | Out-Null
            return New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
        }
    }

    if ([bool]$result.grants_approval -or [bool]$result.grants_merge_authority -or [bool]$result.grants_production_authority) {
        $status = "TIM_REQUIRED"
        $reasons.Add("Returned evidence attempted to grant approval, merge, or production authority.") | Out-Null
    } elseif ([string]$result.policy_fingerprint -ne [string]$mission.policy.fingerprint) {
        $status = "REJECTED_POLICY_MISMATCH"
        $reasons.Add("Result policy fingerprint does not match the governing mission.") | Out-Null
    } elseif (![string]::IsNullOrWhiteSpace($ActivePolicyFingerprint) -and $ActivePolicyFingerprint -ne [string]$mission.policy.fingerprint) {
        $status = "REVIEW_REQUIRED"
        $reasons.Add("Active policies changed after mission creation.") | Out-Null
    }

    if ($status -eq "ADMITTED" -and [string]$result.parent_mission_id -ne [string]$mission.parent_mission_id) {
        $status = "REJECTED_INVALID_EVIDENCE"; $reasons.Add("Result parent mission linkage does not match the registered mission.") | Out-Null
    }

    if ($status -eq "ADMITTED") {
        if ([string]::IsNullOrWhiteSpace([string]$result.actual_repository) -or !(Test-TsfValueInScope -Value ([string]$result.actual_repository) -Scopes @($mission.repository_allowlist))) {
            $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Actual repository is absent or outside repository_allowlist.") | Out-Null
        } elseif (Test-TsfValueInScope -Value ([string]$result.actual_repository) -Scopes @($mission.forbidden_repositories)) {
            $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Actual repository matches forbidden_repositories.") | Out-Null
        }
    }
    if ($status -eq "ADMITTED") {
        foreach ($path in @($result.files_changed)) {
            if (!(Test-TsfValueInScope -Value ([string]$path) -Scopes @($mission.allowed_writes))) { $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Changed path is outside allowed_writes: $path") | Out-Null; break }
        }
    }
    if ($status -eq "ADMITTED") {
        foreach ($path in @($result.files_inspected)) {
            if (!(Test-TsfValueInScope -Value ([string]$path) -Scopes @($mission.allowed_reads))) { $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Inspected path is outside allowed_reads: $path") | Out-Null; break }
            if (Test-TsfValueInScope -Value ([string]$path) -Scopes @($mission.forbidden_sources)) { $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Inspected path matches forbidden_sources: $path") | Out-Null; break }
        }
    }
    if ($status -eq "ADMITTED") {
        $branchPolicy = $mission.branch_worktree_policy
        if ([bool]$branchPolicy.branch_required -and [string]$result.actual_branch_worktree.branch -ne [string]$branchPolicy.expected_branch) {
            $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Actual branch does not match the mission branch policy.") | Out-Null
        } elseif ([bool]$branchPolicy.worktree_required -and [string]$result.actual_branch_worktree.worktree -ne [string]$branchPolicy.expected_worktree) {
            $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Actual worktree does not match the mission worktree policy.") | Out-Null
        }
    }
    if ($status -eq "ADMITTED" -and [string]$mission.network_policy -eq "PROHIBITED" -and ($result.network_activity.used -eq $true -or @($result.network_activity.destinations).Count -gt 0)) {
        $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Network activity occurred while network_policy was PROHIBITED.") | Out-Null
    }
    if ($status -eq "ADMITTED" -and [string]$mission.network_policy -ne "PROHIBITED") {
        foreach ($destination in @($result.network_activity.destinations)) {
            if (!(Test-TsfValueInScope -Value ([string]$destination) -Scopes @($mission.source_allowlist)) -or (Test-TsfValueInScope -Value ([string]$destination) -Scopes @($mission.forbidden_sources))) {
                $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Network source is not allowed or is forbidden: $destination") | Out-Null; break
            }
        }
    }
    if ($status -eq "ADMITTED") {
        $forbiddenActionSet = @($mission.forbidden_actions | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        foreach ($majorAction in @($result.major_actions)) {
            $actionText = ([string]$majorAction).Trim().ToLowerInvariant()
            $actionId = if ($actionText -match '^action:\s*([a-z0-9_.-]+)$') { $Matches[1] } else { $actionText }
            if ($forbiddenActionSet -contains $actionId) { $status = "REJECTED_OUT_OF_SCOPE"; $reasons.Add("Result reports a forbidden action: $actionId") | Out-Null; break }
        }
    }

    if ($status -eq "ADMITTED") {
        foreach ($requiredTest in @($mission.required_tests | Where-Object { [bool]$_.required })) {
            $observed = @($result.tests | Where-Object { [string]$_.test_id -eq [string]$requiredTest.test_id -and [string]$_.status -eq "PASS" })
            if ($observed.Count -eq 0) { $status = "REJECTED_INVALID_EVIDENCE"; $reasons.Add("Required passing test evidence is missing: $($requiredTest.test_id)") | Out-Null; break }
        }
    }
    if ($status -eq "ADMITTED") {
        foreach ($requiredArtifact in @($mission.required_artifacts)) {
            $observed = @($result.artifacts | Where-Object { [string]$_.path -eq [string]$requiredArtifact.path -and [bool]$_.exists })
            if ($observed.Count -eq 0) { $status = "REJECTED_INVALID_EVIDENCE"; $reasons.Add("Required artifact is missing: $($requiredArtifact.path)") | Out-Null; break }
            if ([bool]$requiredArtifact.hash_required -and [string]::IsNullOrWhiteSpace([string]$observed[0].sha256)) { $status = "REJECTED_INVALID_EVIDENCE"; $reasons.Add("Required artifact hash is missing: $($requiredArtifact.path)") | Out-Null; break }
        }
    }
    if ($status -eq "ADMITTED" -and [string]$mission.required_verifier_independence -ne "NONE") {
        $verifier = @($result.verifier_evidence | Where-Object { [string]$_.independence -eq [string]$mission.required_verifier_independence -and [bool]$_.passed })
        if ($verifier.Count -eq 0) { $status = "REVIEW_REQUIRED"; $reasons.Add("Required independent verifier evidence is missing or not passing.") | Out-Null }
    }

    if ($status -eq "ADMITTED" -and ![string]::IsNullOrWhiteSpace([string]$mission.expires_at)) {
        $expires = [datetimeoffset]::Parse([string]$mission.expires_at)
        if ($CurrentTime -gt $expires) { $status = if ([string]$mission.stale_state_behavior -eq "TIM_REQUIRED") { "TIM_REQUIRED" } elseif ([string]$mission.stale_state_behavior -eq "REJECT") { "REJECTED_INVALID_EVIDENCE" } else { "REVIEW_REQUIRED" }; $reasons.Add("Result returned after mission expiry.") | Out-Null }
    }
    if ($status -eq "ADMITTED" -and ![string]::IsNullOrWhiteSpace([string]$mission.branch_worktree_policy.starting_head) -and [string]$result.git_facts.starting_head -ne [string]$mission.branch_worktree_policy.starting_head) {
        $status = if ([string]$mission.branch_worktree_policy.unexpected_advance_behavior -eq "REJECT") { "REJECTED_OUT_OF_SCOPE" } else { "REVIEW_REQUIRED" }
        $reasons.Add("Branch starting HEAD changed from the mission snapshot.") | Out-Null
    }
    if ($status -eq "ADMITTED" -and @($result.deviations_from_mission).Count -gt 0) { $status = "REVIEW_REQUIRED"; $reasons.Add("Result declares deviations from the mission.") | Out-Null }
    if ($status -eq "ADMITTED" -and [string]$result.surface_used -ne [string]$mission.recommended_surface) { $status = "REVIEW_REQUIRED"; $reasons.Add("Execution surface differs from the mission recommendation.") | Out-Null }
    if ($status -eq "ADMITTED" -and @($result.approval_use | Where-Object { [bool]$_.used -and [string]$_.approval_id -notin @($mission.approval_references | ForEach-Object { [string]$_.approval_id }) }).Count -gt 0) { $status = "TIM_REQUIRED"; $reasons.Add("Result claims use of an approval not referenced by the mission.") | Out-Null }
    if ($status -eq "ADMITTED") {
        $missionAssurance = [array]::IndexOf($script:AssuranceLevels, [string]$mission.model_selection_assurance)
        $resultAssurance = [array]::IndexOf($script:AssuranceLevels, [string]$result.model_assurance_level)
        if ($resultAssurance -lt $missionAssurance) { $status = "REVIEW_REQUIRED"; $reasons.Add("Observed model assurance is lower than the mission required.") | Out-Null }
    }

    if ($status -eq "ADMITTED") {
        if ([string]::IsNullOrWhiteSpace([string]$result.actual_model) -and [string]$result.model_assurance_level -eq "RECOMMENDED_ONLY") { $caveats.Add("Actual model is unknown and honestly reported as RECOMMENDED_ONLY.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace([string]$result.surface_task_identity)) { $caveats.Add("Native surface task identity was unavailable.") | Out-Null }
        foreach ($uncertainty in @($result.uncertainty)) { $caveats.Add([string]$uncertainty) | Out-Null }
        foreach ($warning in @($result.security_or_scope_warnings)) { $caveats.Add([string]$warning) | Out-Null }
        if ($caveats.Count -gt 0) { $status = "ADMITTED_WITH_CAVEATS" }
    }
    if ($reasons.Count -eq 0) { $reasons.Add("Result satisfied the registered mission and admission policy.") | Out-Null }
    $receipt = New-TsfAdmissionReceiptObject -Result $result -ResultHash $resultHash -Status $status -Reasons @($reasons) -Caveats @($caveats) -Now $CurrentTime
    Write-TsfAdmissionReceiptIfRequested -Receipt $receipt -ReceiptDirectory $ReceiptDirectory
    return $receipt
}

Export-ModuleMember -Function Get-TsfPolicyFingerprint, Test-TsfMissionEnvelope, Test-TsfResultEnvelope, Get-TsfAdmissionDecision, Get-TsfContractJsonHash
