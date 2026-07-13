[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (@($MyInvocation.UnboundArguments).Count -ne 0) {
    throw "Route preview does not accept runtime arguments."
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$requestSchemaPath = Join-Path $repoRoot "fleet\control\hq-dispatch\hq-dispatch-route-preview-request.schema.v1.json"
$responseSchemaPath = Join-Path $repoRoot "fleet\control\hq-dispatch\hq-dispatch-route-preview-response.schema.v1.json"
$missionDraftPath = Join-Path $repoRoot "tools\New-TsfProjectMainBotMissionDraft.ps1"
$durableContractPath = Join-Path $repoRoot "tools\TsfDurableContract.Canonical.ps1"
$roleRegistryPath = Join-Path $repoRoot "fleet\control\worker-role-registry.v1.json"
$modelPolicyPath = Join-Path $repoRoot "fleet\control\model-routing-alias-policy.v1.json"

foreach ($requiredPath in @(
    $requestSchemaPath,
    $responseSchemaPath,
    $missionDraftPath,
    $durableContractPath,
    $roleRegistryPath,
    $modelPolicyPath
)) {
    if (!(Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "A hardcoded route-preview source is missing."
    }
}

function Read-TsfKernelJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPrefix = $repoRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    if (!$fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "A canonical JSON source escapes the TSF repository."
    }
    Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json -ErrorAction Stop
}

$script:TsfRoot = $repoRoot
. $durableContractPath

$rawRequest = [Console]::In.ReadToEnd()
if ([System.Text.Encoding]::UTF8.GetByteCount($rawRequest) -gt 8192) {
    throw "Route-preview request exceeds the fixed input limit."
}
if ([string]::IsNullOrWhiteSpace($rawRequest) -or $rawRequest.IndexOf([char]0) -ge 0) {
    throw "Route-preview request is empty or contains a forbidden null character."
}

try {
    $request = $rawRequest | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "Route-preview request is not valid JSON."
}

Set-StrictMode -Off
$requestValidation = Test-TsfJsonContract -Value $request -SchemaPath $requestSchemaPath
Set-StrictMode -Version Latest
if (!$requestValidation.valid) {
    throw "Route-preview request does not match the fixed request schema."
}

$naturalRequest = ([string]$request.natural_request).Trim()
if ([string]::IsNullOrWhiteSpace($naturalRequest)) {
    throw "Natural request must contain non-whitespace text."
}

Set-StrictMode -Off
$draft = & $missionDraftPath `
    -ProjectId "thousand-sunny-fleet" `
    -NaturalRequest $naturalRequest `
    -Lane "MASTER_TSF_CONTROL_PLANE" `
    -RequestedGoal $naturalRequest `
    -ExpectedArtifacts @("hq-dispatch-route-preview") `
    -StopConditions @(
        "scope-gate|approval_required|Stop if the request crosses a hard TSF gate.",
        "preview-only|execution_disabled|Stop before mission submission or execution."
    ) `
    -RepoPath $repoRoot `
    -CreatedBy "tsf_hq_dispatch_route_preview_v1"
Set-StrictMode -Version Latest

$classification = [string]$draft.classification
$knownClassifications = @(
    "SAFE_LOCAL_MISSION",
    "NEEDS_TIM_APPROVAL",
    "NEEDS_CHATGPT_HQ",
    "BLOCKED_UNSAFE",
    "NEEDS_MAIN_BOT_REVIEW"
)
if ($knownClassifications -notcontains $classification) {
    throw "Canonical mission-draft classification was not recognized."
}

$roleId = [string]$draft.normalized_intent.proposed_worker_role
$roleRegistry = Read-TsfKernelJson -Path $roleRegistryPath
$matchingRoles = @($roleRegistry.roles | Where-Object { [string]$_.role_id -ceq $roleId })
if ($matchingRoles.Count -ne 1) {
    throw "Canonical proposed worker role is absent or ambiguous in the worker-role registry."
}
$role = $matchingRoles[0]

Set-StrictMode -Off
$modelRoute = Resolve-TsfModelRouting `
    -Alias "standard_patch" `
    -Surface "CODEX" `
    -PolicyPath $modelPolicyPath
Set-StrictMode -Version Latest

$requiredApprovals = @()
$clarifications = @()
switch ($classification) {
    "NEEDS_TIM_APPROVAL" {
        $requiredApprovals = @([pscustomobject]@{
            gate = "EXACT_ACTION_BOUND_HUMAN_APPROVAL"
            status = "REQUIRED_BEFORE_ANY_FUTURE_EXECUTION"
            source = "tools/New-TsfProjectMainBotMissionDraft.ps1"
        })
    }
    "NEEDS_CHATGPT_HQ" {
        $clarifications = @("Canonical classification requires a bounded HQ decision packet before any future mission authoring or execution.")
    }
    "NEEDS_MAIN_BOT_REVIEW" {
        $clarifications = @("Canonical classification requires Project Main Bot clarification before any future mission authoring or execution.")
    }
    "BLOCKED_UNSAFE" {
        $clarifications = @("Canonical classification blocks the request. Do not repurpose this preview as approval or execution authority.")
    }
}

$sourceSpecs = @(
    [pscustomobject]@{ path = "tools/New-TsfProjectMainBotMissionDraft.ps1"; full_path = $missionDraftPath },
    [pscustomobject]@{ path = "tools/TsfDurableContract.Canonical.ps1"; full_path = $durableContractPath },
    [pscustomobject]@{ path = "fleet/control/worker-role-registry.v1.json"; full_path = $roleRegistryPath },
    [pscustomobject]@{ path = "fleet/control/model-routing-alias-policy.v1.json"; full_path = $modelPolicyPath }
)
$registrySources = @($sourceSpecs | ForEach-Object {
    [pscustomobject]@{
        path = $_.path
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.full_path).Hash.ToLowerInvariant()
        freshness = "READ_AT_PREVIEW_TIME"
    }
})

$previewToken = [Guid]::NewGuid().ToString("N")
$previewId = "hq-preview-$previewToken"
$previewRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".codex-local\hq-dispatch\preview"))
$artifactName = "$previewId.route-preview.json"
$artifactPath = [System.IO.Path]::GetFullPath((Join-Path $previewRoot $artifactName))
$previewPrefix = $previewRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
if (!$artifactPath.StartsWith($previewPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Generated preview artifact path escapes the fixed preview root."
}
$artifactRelativePath = ".codex-local/hq-dispatch/preview/$artifactName"

$response = [pscustomobject]@{
    schema_version = "tsf_hq_dispatch_route_preview_response_v1"
    generated_at = [DateTimeOffset]::UtcNow.ToString("o")
    banner = "PREVIEW_ONLY_NOT_AUTHORITY"
    record_kind = "hq_dispatch_route_preview"
    preview_id = $previewId
    natural_request = $naturalRequest
    proposed_project = [pscustomobject]@{
        project_id = [string]$draft.mission_packet.project_id
        lane = [string]$draft.mission_packet.lane
    }
    proposed_worker_role = [pscustomobject]@{
        role_id = [string]$role.role_id
        role_name = [string]$role.role_name
        purpose = [string]$role.purpose
        source_path = "fleet/control/worker-role-registry.v1.json"
    }
    model_routing = [pscustomobject]@{
        requested_alias = [string]$modelRoute.requested_alias
        stable_alias = [string]$modelRoute.stable_alias
        resolved_model = [string]$modelRoute.resolved_model
        reasoning_effort = [string]$modelRoute.reasoning_effort
        assurance = [string]$modelRoute.assurance
        surface = "CODEX"
        source_path = "fleet/control/model-routing-alias-policy.v1.json"
    }
    classification = $classification
    required_approvals = @($requiredApprovals)
    clarifications = @($clarifications)
    allowed_reads = @($draft.mission_packet.allowed_reads)
    allowed_writes = @($draft.mission_packet.allowed_writes)
    forbidden_actions = @($draft.mission_packet.forbidden_actions)
    stop_conditions = @($draft.mission_packet.stop_conditions)
    registry_sources = @($registrySources)
    authority = [pscustomobject]@{
        preview_only = $true
        route_preview_enabled = $true
        mission_execution_enabled = $false
        mission_submission_enabled = $false
        queue_mutation_enabled = $false
        approval_mutation_enabled = $false
        authority_statement = "This projection is evidence only and grants no mission, queue, approval, worker, lifecycle, plugin, app-server, merge, or deployment authority."
    }
    artifact = [pscustomobject]@{
        relative_path = $artifactRelativePath
        record_kind = "preview_artifact"
        mission_record = $false
        queue_record = $false
    }
}

Set-StrictMode -Off
$responseValidation = Test-TsfJsonContract -Value $response -SchemaPath $responseSchemaPath
Set-StrictMode -Version Latest
if (!$responseValidation.valid) {
    throw "Route-preview response failed its fixed response schema."
}

New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null
$prettyJson = $response | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText(
    $artifactPath,
    $prettyJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

[Console]::Out.WriteLine(($response | ConvertTo-Json -Depth 30 -Compress))
