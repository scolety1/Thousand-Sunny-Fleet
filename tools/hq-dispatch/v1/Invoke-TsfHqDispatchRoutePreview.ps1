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
$semanticIntegrityPath = Join-Path $repoRoot "tools\TsfSemanticIntegrity.ps1"
$originalIntentSchemaPath = Join-Path $repoRoot "fleet\control\original-operator-intent.schema.v1.json"
$scopeTransformationSchemaPath = Join-Path $repoRoot "fleet\control\scope-transformation.schema.v1.json"
$taskCompletionSchemaPath = Join-Path $repoRoot "fleet\control\task-completion-contract.schema.v1.json"

foreach ($requiredPath in @(
    $requestSchemaPath,
    $responseSchemaPath,
    $missionDraftPath,
    $durableContractPath,
    $roleRegistryPath,
    $modelPolicyPath,
    $semanticIntegrityPath,
    $originalIntentSchemaPath,
    $scopeTransformationSchemaPath,
    $taskCompletionSchemaPath
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
. $semanticIntegrityPath

function New-TsfHqObservedBinding {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$SourceField,
        [Parameter(Mandatory = $true)][string]$ObservedValue,
        [Parameter(Mandatory = $true)][ValidateSet(
            "CANONICAL_POLICY_OUTPUT",
            "CANONICAL_REGISTRY_OUTPUT",
            "FIXED_MILESTONE_BOUNDARY",
            "UNKNOWN_OR_RECOMMENDATION_ONLY"
        )][string]$Assurance
    )

    [pscustomobject][ordered]@{
        source_path = $SourcePath
        source_field = $SourceField
        observed_value = $ObservedValue
        assurance = $Assurance
    }
}

function New-TsfHqHashedBinding {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$SourceField,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()][object]$ObservedValue,
        [Parameter(Mandatory = $true)][ValidateSet(
            "CANONICAL_POLICY_OUTPUT",
            "CANONICAL_REGISTRY_OUTPUT",
            "FIXED_MILESTONE_BOUNDARY",
            "UNKNOWN_OR_RECOMMENDATION_ONLY"
        )][string]$Assurance
    )

    $canonicalJson = ConvertTo-Json -InputObject @($ObservedValue) -Depth 100 -Compress
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $observedHash = ([System.BitConverter]::ToString(
            $sha256.ComputeHash([System.Text.UTF8Encoding]::new($false).GetBytes($canonicalJson))
        )).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }

    [pscustomobject][ordered]@{
        source_path = $SourcePath
        source_field = $SourceField
        observed_value_sha256 = $observedHash
        assurance = $Assurance
    }
}

function New-TsfHqExplanationElement {
    param(
        [Parameter(Mandatory = $true)][string]$ReasonCode,
        [Parameter(Mandatory = $true)][string]$Summary,
        [Parameter(Mandatory = $true)][object[]]$Bindings
    )

    [pscustomobject][ordered]@{
        reason_code = $ReasonCode
        summary = $Summary
        canonical_source_bindings = @($Bindings)
    }
}

function Write-TsfHqPreviewArtifactExclusive {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
    } catch [System.IO.IOException] {
        throw [System.InvalidOperationException]::new(
            "PREVIEW_ARTIFACT_COLLISION",
            $_.Exception
        )
    }
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Content)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } catch {
        $stream.Dispose()
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force
        }
        throw
    } finally {
        $stream.Dispose()
    }
}

function Invoke-TsfHqDispatchRoutePreviewMain {
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
    -AllowedWrites @() `
    -ExpectedArtifacts @("hq-dispatch-route-preview") `
    -StopConditions @(
        "scope-gate|approval_required|Stop if the request crosses a hard TSF gate.",
        "preview-only|execution_disabled|Stop before mission submission or execution."
    ) `
    -RepoPath $repoRoot `
    -CreatedBy "tsf_hq_dispatch_route_preview_v1"
Set-StrictMode -Version Latest

$canonicalClassification = [string]$draft.classification
$classification = $canonicalClassification
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

function Test-TsfHqDetachedHead {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    $dotGit = Join-Path $RepositoryRoot '.git'
    $gitDirectory = $dotGit
    if (Test-Path -LiteralPath $dotGit -PathType Leaf) {
        $pointer = (Get-Content -LiteralPath $dotGit -Raw).Trim()
        if ($pointer -notmatch '^gitdir:\s*(.+)$') { throw 'ROUTE_PREVIEW_GIT_IDENTITY_UNAVAILABLE' }
        $gitPointerPath = [string]$Matches[1]
        $gitDirectory = if ([System.IO.Path]::IsPathRooted($gitPointerPath)) { [System.IO.Path]::GetFullPath($gitPointerPath) } else { [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $gitPointerPath)) }
    }
    $headPath = Join-Path $gitDirectory 'HEAD'
    if (!(Test-Path -LiteralPath $headPath -PathType Leaf)) { throw 'ROUTE_PREVIEW_GIT_IDENTITY_UNAVAILABLE' }
    $head = (Get-Content -LiteralPath $headPath -Raw).Trim()
    if ($head -match '^ref:\s+refs/heads/[A-Za-z0-9._/-]+$') { return $false }
    if ($head -match '^[a-f0-9]{40}$') { return $true }
    throw 'ROUTE_PREVIEW_GIT_IDENTITY_UNAVAILABLE'
}
$detachedHead = Test-TsfHqDetachedHead -RepositoryRoot $repoRoot
$analysisPreviewId = 'hq-preview-' + ('0' * 32)
$analysisExactContract = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId $analysisPreviewId
$analysisIntent = New-TsfOriginalOperatorIntentContract -NaturalRequest $naturalRequest -PreviewId $analysisPreviewId -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -ProhibitedOperations @($draft.mission_packet.forbidden_actions)
$analysisProposedOperations = if ($null -ne $analysisExactContract) { @('RETURN_RESULT') } else { @('READ_ANALYSIS','RETURN_RESULT') }
$analysisScope = New-TsfScopeTransformationContract -OriginalIntent $analysisIntent -AuthorizedMissionGoal $naturalRequest -ProposedOperations $analysisProposedOperations -ProposedAccess 'READ_ONLY' -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -DetachedHead:$detachedHead
if (![bool]$analysisScope.queue_allowed -and $classification -eq 'SAFE_LOCAL_MISSION') {
    $classification = if ([string]$analysisScope.classification -eq 'AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION') { 'NEEDS_TIM_APPROVAL' } else { 'NEEDS_MAIN_BOT_REVIEW' }
}

$classificationExplanation = switch ($classification) {
    "SAFE_LOCAL_MISSION" {
        [pscustomobject]@{
            reason_code = "CANONICAL_DRAFT_SAFE_LOCAL_CLASSIFICATION"
            summary = "The canonical draft returned SAFE_LOCAL_MISSION. HQ Dispatch formats that observed value as a bounded local preview classification and does not grant execution authority."
        }
    }
    "NEEDS_TIM_APPROVAL" {
        [pscustomobject]@{
            reason_code = "CANONICAL_DRAFT_TIM_APPROVAL_CLASSIFICATION"
            summary = "The canonical draft returned NEEDS_TIM_APPROVAL. HQ Dispatch therefore displays an exact-action human gate before any separate future execution path."
        }
    }
    "NEEDS_CHATGPT_HQ" {
        [pscustomobject]@{
            reason_code = "CANONICAL_DRAFT_HQ_REVIEW_CLASSIFICATION"
            summary = "The canonical draft returned NEEDS_CHATGPT_HQ. HQ Dispatch therefore displays the need for a separate bounded HQ decision packet."
        }
    }
    "BLOCKED_UNSAFE" {
        [pscustomobject]@{
            reason_code = "CANONICAL_DRAFT_BLOCKED_CLASSIFICATION"
            summary = "The canonical draft returned BLOCKED_UNSAFE. HQ Dispatch displays that result without converting it into approval, mission, or execution authority."
        }
    }
    "NEEDS_MAIN_BOT_REVIEW" {
        [pscustomobject]@{
            reason_code = "CANONICAL_DRAFT_MAIN_BOT_REVIEW_CLASSIFICATION"
            summary = "The canonical draft returned NEEDS_MAIN_BOT_REVIEW. HQ Dispatch therefore displays a clarification requirement before any future mission authoring."
        }
    }
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
$approvalReasonCode = "NO_CLASSIFICATION_APPROVAL_IDENTIFIED"
$approvalSummary = "The canonical classification does not identify an exact approval for this preview. All future execution remains disabled and separately gated."
$clarificationReasonCode = "NO_CLASSIFICATION_CLARIFICATION_IDENTIFIED"
$clarificationSummary = "The canonical classification does not identify a required clarification for this preview."
switch ($classification) {
    "NEEDS_TIM_APPROVAL" {
        $requiredApprovals = @([pscustomobject]@{
            gate = "EXACT_ACTION_BOUND_HUMAN_APPROVAL"
            status = "REQUIRED_BEFORE_ANY_FUTURE_EXECUTION"
            source = "tools/New-TsfProjectMainBotMissionDraft.ps1"
        })
        $approvalReasonCode = "CLASSIFICATION_REQUIRES_EXACT_HUMAN_APPROVAL"
        $approvalSummary = "The observed NEEDS_TIM_APPROVAL classification is displayed with a fixed exact-action human gate; HQ Dispatch cannot capture or satisfy that gate."
    }
    "NEEDS_CHATGPT_HQ" {
        $clarifications = @("Canonical classification requires a bounded HQ decision packet before any future mission authoring or execution.")
        $clarificationReasonCode = "CLASSIFICATION_REQUIRES_BOUNDED_HQ_PACKET"
        $clarificationSummary = "The observed NEEDS_CHATGPT_HQ classification requires a separate bounded HQ decision packet before any future mission authoring."
    }
    "NEEDS_MAIN_BOT_REVIEW" {
        $clarifications = @("Canonical classification requires Project Main Bot clarification before any future mission authoring or execution.")
        $clarificationReasonCode = "CLASSIFICATION_REQUIRES_MAIN_BOT_CLARIFICATION"
        $clarificationSummary = "The observed NEEDS_MAIN_BOT_REVIEW classification requires Project Main Bot clarification before any future mission authoring."
    }
    "BLOCKED_UNSAFE" {
        $clarifications = @("Canonical classification blocks the request. Do not repurpose this preview as approval or execution authority.")
        $clarificationReasonCode = "CLASSIFICATION_BLOCKS_REQUEST"
        $clarificationSummary = "The observed BLOCKED_UNSAFE classification is a stop condition and cannot be repurposed as approval or execution authority."
    }
}

$sourceSpecs = @(
    [pscustomobject]@{ path = "tools/New-TsfProjectMainBotMissionDraft.ps1"; full_path = $missionDraftPath },
    [pscustomobject]@{ path = "tools/TsfDurableContract.Canonical.ps1"; full_path = $durableContractPath },
    [pscustomobject]@{ path = "tools/TsfSemanticIntegrity.ps1"; full_path = $semanticIntegrityPath },
    [pscustomobject]@{ path = "fleet/control/worker-role-registry.v1.json"; full_path = $roleRegistryPath },
    [pscustomobject]@{ path = "fleet/control/model-routing-alias-policy.v1.json"; full_path = $modelPolicyPath },
    [pscustomobject]@{ path = "fleet/control/original-operator-intent.schema.v1.json"; full_path = $originalIntentSchemaPath },
    [pscustomobject]@{ path = "fleet/control/scope-transformation.schema.v1.json"; full_path = $scopeTransformationSchemaPath },
    [pscustomobject]@{ path = "fleet/control/task-completion-contract.schema.v1.json"; full_path = $taskCompletionSchemaPath }
)
$registrySources = @($sourceSpecs | ForEach-Object {
    [pscustomobject]@{
        path = $_.path
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.full_path).Hash.ToLowerInvariant()
        freshness = "READ_AT_PREVIEW_TIME"
    }
})

$previewRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".codex-local\hq-dispatch\preview"))
$previewPrefix = $previewRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null

$wrapperSourcePath = "tools/hq-dispatch/v1/Invoke-TsfHqDispatchRoutePreview.ps1"
$allowedReads = @($draft.mission_packet.allowed_reads)
$allowedWrites = @($draft.mission_packet.allowed_writes)
$forbiddenActions = @($draft.mission_packet.forbidden_actions)
$stopConditions = @($draft.mission_packet.stop_conditions)

$projectLaneBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.project_id" -ObservedValue ([string]$draft.mission_packet.project_id) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.lane" -ObservedValue ([string]$draft.mission_packet.lane) -Assurance "CANONICAL_POLICY_OUTPUT"
)
$classificationBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.classification" -ObservedValue $canonicalClassification -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "scope_transformation.effective_classification" -ObservedValue $classification -Assurance "FIXED_MILESTONE_BOUNDARY"
)
$roleBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.normalized_intent.proposed_worker_role" -ObservedValue ([string]$draft.normalized_intent.proposed_worker_role) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "fleet/control/worker-role-registry.v1.json" -SourceField "roles[role_id=$roleId].role_name" -ObservedValue ([string]$role.role_name) -Assurance "CANONICAL_REGISTRY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "fleet/control/worker-role-registry.v1.json" -SourceField "roles[role_id=$roleId].purpose" -ObservedValue ([string]$role.purpose) -Assurance "CANONICAL_REGISTRY_OUTPUT"
)
$modelBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/TsfDurableContract.Canonical.ps1" -SourceField "Resolve-TsfModelRouting.result.requested_alias" -ObservedValue ([string]$modelRoute.requested_alias) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "tools/TsfDurableContract.Canonical.ps1" -SourceField "Resolve-TsfModelRouting.result.stable_alias" -ObservedValue ([string]$modelRoute.stable_alias) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "fleet/control/model-routing-alias-policy.v1.json" -SourceField "surface_resolutions.CODEX.$([string]$modelRoute.stable_alias)" -ObservedValue ([string]$modelRoute.resolved_model) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "fleet/control/model-routing-alias-policy.v1.json" -SourceField "aliases.$([string]$modelRoute.stable_alias).default_reasoning_effort" -ObservedValue ([string]$modelRoute.reasoning_effort) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath "tools/TsfDurableContract.Canonical.ps1" -SourceField "Resolve-TsfModelRouting.result.assurance" -ObservedValue ([string]$modelRoute.assurance) -Assurance "UNKNOWN_OR_RECOMMENDATION_ONLY"
)
$accessBindings = @(
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.allowed_reads" -ObservedValue ([object]$allowedReads) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.allowed_writes" -ObservedValue ([object]$allowedWrites) -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.network_scope" -ObservedValue "NO_NETWORK" -Assurance "FIXED_MILESTONE_BOUNDARY"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.execution_scope" -ObservedValue "ROUTE_PREVIEW_ONLY_NO_EXECUTION" -Assurance "FIXED_MILESTONE_BOUNDARY"
)
$readBindings = @(
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.allowed_reads" -ObservedValue ([object]$allowedReads) -Assurance "CANONICAL_POLICY_OUTPUT"
)
$writeBindings = @(
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.allowed_writes" -ObservedValue ([object]$allowedWrites) -Assurance "CANONICAL_POLICY_OUTPUT"
)
$forbiddenBindings = @(
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.forbidden_actions" -ObservedValue ([object]$forbiddenActions) -Assurance "CANONICAL_POLICY_OUTPUT"
)
$approvalBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.classification" -ObservedValue $classification -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqHashedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.required_approvals" -ObservedValue ([object]$requiredApprovals) -Assurance "FIXED_MILESTONE_BOUNDARY"
)
$clarificationBindings = @(
    New-TsfHqObservedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.classification" -ObservedValue $classification -Assurance "CANONICAL_POLICY_OUTPUT"
    New-TsfHqHashedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.clarifications" -ObservedValue ([object]$clarifications) -Assurance "FIXED_MILESTONE_BOUNDARY"
)
$stopBindings = @(
    New-TsfHqHashedBinding -SourcePath "tools/New-TsfProjectMainBotMissionDraft.ps1" -SourceField "draft.mission_packet.stop_conditions" -ObservedValue ([object]$stopConditions) -Assurance "CANONICAL_POLICY_OUTPUT"
)
$authorityBindings = @(
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.preview_only" -ObservedValue "true" -Assurance "FIXED_MILESTONE_BOUNDARY"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.mission_execution_enabled" -ObservedValue "false" -Assurance "FIXED_MILESTONE_BOUNDARY"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.queue_mutation_enabled" -ObservedValue "false" -Assurance "FIXED_MILESTONE_BOUNDARY"
    New-TsfHqObservedBinding -SourcePath $wrapperSourcePath -SourceField "fixed_milestone_boundary.plugin_access_enabled" -ObservedValue "false" -Assurance "FIXED_MILESTONE_BOUNDARY"
)

$accessRationale = "The canonical draft proposes bounded TSF-local read/write scopes. Milestone 1 fixes network scope to NO_NETWORK and execution scope to ROUTE_PREVIEW_ONLY_NO_EXECUTION, so this is a recommendation and grants no authority."
$accessProposal = [pscustomobject][ordered]@{
    access_level = "TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION"
    read_scope = @($allowedReads)
    write_scope = @($allowedWrites)
    network_scope = "NO_NETWORK"
    execution_scope = "ROUTE_PREVIEW_ONLY_NO_EXECUTION"
    rationale = $accessRationale
    reason_code = "MILESTONE_1_SCOPED_ACCESS_RECOMMENDATION"
    canonical_source_bindings = @($accessBindings)
}

$routeExplanation = [pscustomobject][ordered]@{
    schema_version = "tsf_hq_dispatch_route_explanation_v1"
    project_lane = New-TsfHqExplanationElement -ReasonCode "FIXED_TSF_PREVIEW_PROJECT_LANE" -Summary "The canonical draft returned project thousand-sunny-fleet and lane MASTER_TSF_CONTROL_PLANE because Milestone 1 is a fixed TSF-local control-plane preview, not adaptive project routing." -Bindings $projectLaneBindings
    classification = New-TsfHqExplanationElement -ReasonCode ([string]$classificationExplanation.reason_code) -Summary ([string]$classificationExplanation.summary) -Bindings $classificationBindings
    worker_role = New-TsfHqExplanationElement -ReasonCode "CANONICAL_DEFAULT_ROLE_RECOMMENDATION" -Summary "The canonical draft selected $([string]$role.role_name) ($roleId), whose registry purpose is '$([string]$role.purpose)'. Milestone 1 reports this registered default and does not claim adaptive role fit or start the worker." -Bindings $roleBindings
    model_routing = New-TsfHqExplanationElement -ReasonCode "CANONICAL_MODEL_POLICY_RECOMMENDATION" -Summary "The fixed request alias $([string]$modelRoute.requested_alias) resolved canonically to $([string]$modelRoute.stable_alias), model $([string]$modelRoute.resolved_model), effort $([string]$modelRoute.reasoning_effort), with $([string]$modelRoute.assurance) assurance. This is a bounded recommendation, not an adaptive model decision or model call." -Bindings $modelBindings
    access_proposal = New-TsfHqExplanationElement -ReasonCode "MILESTONE_1_SCOPED_ACCESS_RECOMMENDATION" -Summary $accessRationale -Bindings $accessBindings
    allowed_reads = New-TsfHqExplanationElement -ReasonCode "CANONICAL_DRAFT_ALLOWED_READS" -Summary "Allowed reads are copied from the canonical draft output and remain proposal data only." -Bindings $readBindings
    allowed_writes = New-TsfHqExplanationElement -ReasonCode "CANONICAL_DRAFT_ALLOWED_WRITES" -Summary "Allowed writes are copied from the canonical draft output and grant no filesystem or mission authority." -Bindings $writeBindings
    forbidden_operations = New-TsfHqExplanationElement -ReasonCode "CANONICAL_DRAFT_FORBIDDEN_OPERATIONS" -Summary "Forbidden operations are copied from the canonical draft output and are reinforced by the fixed preview-only runtime boundary." -Bindings $forbiddenBindings
    approvals_required = New-TsfHqExplanationElement -ReasonCode $approvalReasonCode -Summary $approvalSummary -Bindings $approvalBindings
    clarifications_required = New-TsfHqExplanationElement -ReasonCode $clarificationReasonCode -Summary $clarificationSummary -Bindings $clarificationBindings
    stop_conditions = New-TsfHqExplanationElement -ReasonCode "CANONICAL_DRAFT_STOP_CONDITIONS" -Summary "Stop conditions are copied from the canonical draft output; HQ Dispatch cannot clear or satisfy them." -Bindings $stopBindings
    authority_not_granted = New-TsfHqExplanationElement -ReasonCode "FIXED_PREVIEW_AUTHORITY_EXCLUSIONS" -Summary "PREVIEW_ONLY_NOT_AUTHORITY grants no mission, queue, approval, worker, lifecycle, credential, live-service, plugin, external-repository, app-server, merge, deployment, or production authority." -Bindings $authorityBindings
}

$writtenResponse = $null
for ($attempt = 1; $attempt -le 8; $attempt++) {
    $previewToken = [Guid]::NewGuid().ToString("N")
    $previewId = "hq-preview-$previewToken"
    $exactResponseContract = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId $previewId
    $originalIntent = New-TsfOriginalOperatorIntentContract -NaturalRequest $naturalRequest -PreviewId $previewId -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -ProhibitedOperations @($forbiddenActions)
    $proposedOperations = if ($null -ne $exactResponseContract) { @('RETURN_RESULT') } else { @('READ_ANALYSIS','RETURN_RESULT') }
    $scopeTransformation = New-TsfScopeTransformationContract -OriginalIntent $originalIntent -AuthorizedMissionGoal $naturalRequest -ProposedOperations $proposedOperations -ProposedAccess 'READ_ONLY' -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -DetachedHead:$detachedHead
    $taskCompletionContract = if ($null -eq $exactResponseContract -and [bool]$scopeTransformation.queue_allowed) { New-TsfTaskCompletionContract -RequiredTask $naturalRequest -OriginalIntent $originalIntent -ScopeTransformation $scopeTransformation } else { $null }
    foreach ($contractCheck in @(
        [pscustomobject]@{value=$originalIntent;schema=$originalIntentSchemaPath;name='original intent'},
        [pscustomobject]@{value=$scopeTransformation;schema=$scopeTransformationSchemaPath;name='scope transformation'}
    )) { Set-StrictMode -Off; $check=Test-TsfJsonContract -Value $contractCheck.value -SchemaPath $contractCheck.schema; Set-StrictMode -Version Latest; if(!$check.valid){throw "Route-preview $($contractCheck.name) contract invalid: $($check.errors -join '; ')"} }
    if ($null -ne $taskCompletionContract) { Set-StrictMode -Off; $check=Test-TsfJsonContract -Value $taskCompletionContract -SchemaPath $taskCompletionSchemaPath; Set-StrictMode -Version Latest; if(!$check.valid){throw "Route-preview task completion contract invalid: $($check.errors -join '; ')"} }
    $artifactName = "$previewId.route-preview.json"
    $artifactPath = [System.IO.Path]::GetFullPath((Join-Path $previewRoot $artifactName))
    if (!$artifactPath.StartsWith($previewPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated preview artifact path escapes the fixed preview root."
    }
    $artifactRelativePath = ".codex-local/hq-dispatch/preview/$artifactName"

    $response = [pscustomobject][ordered]@{
        schema_version = "tsf_hq_dispatch_route_preview_response_v1"
        generated_at = [DateTimeOffset]::UtcNow.ToString("o")
        banner = "PREVIEW_ONLY_NOT_AUTHORITY"
        record_kind = "hq_dispatch_route_preview"
        preview_id = $previewId
        result_validation_mode = $(if ($null -ne $exactResponseContract) { 'EXACT_LITERAL_V1' } else { 'GENERAL_RESULT_V2' })
        exact_response_contract = $exactResponseContract
        original_operator_intent = $originalIntent
        scope_transformation = $scopeTransformation
        task_completion_contract = $taskCompletionContract
        canonical_classification = $canonicalClassification
        proposed_mission_goal = $naturalRequest
        proposed_operations = @($proposedOperations)
        submission_gate = $(if ([bool]$scopeTransformation.queue_allowed -and $classification -eq 'SAFE_LOCAL_MISSION') { 'SUBMITTABLE_AFTER_REVALIDATION' } else { 'TIM_REQUIRED_NO_QUEUE' })
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
        access_proposal = $accessProposal
        route_explanation = $routeExplanation
        required_approvals = @($requiredApprovals)
        clarifications = @($clarifications)
        allowed_reads = @($allowedReads)
        allowed_writes = @($allowedWrites)
        forbidden_actions = @($forbiddenActions)
        stop_conditions = @($stopConditions)
        registry_sources = @($registrySources)
        authority = [pscustomobject]@{
            preview_only = $true
            route_preview_enabled = $true
            mission_execution_enabled = $false
            mission_submission_enabled = $false
            queue_mutation_enabled = $false
            approval_mutation_enabled = $false
            credential_access_enabled = $false
            live_ai_service_access_enabled = $false
            plugin_access_enabled = $false
            external_repository_access_enabled = $false
            request_text_persisted = $true
            authority_statement = "This projection is evidence only and grants no mission, queue, approval, worker, lifecycle, credential, live-service, plugin, external-repository, app-server, merge, or deployment authority."
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
        throw "Route-preview response failed its fixed response schema: $($responseValidation.errors -join '; ')"
    }

    $prettyJson = $response | ConvertTo-Json -Depth 40
    try {
        Write-TsfHqPreviewArtifactExclusive -Path $artifactPath -Content ($prettyJson + [Environment]::NewLine)
        $writtenResponse = $response
        break
    } catch {
        if ($_.Exception.Message -ceq "PREVIEW_ARTIFACT_COLLISION") {
            continue
        }
        throw
    }
}

if ($null -eq $writtenResponse) {
    throw "PREVIEW_ARTIFACT_COLLISION_RETRY_LIMIT"
}

[Console]::Out.WriteLine(($writtenResponse | ConvertTo-Json -Depth 40 -Compress))
}

if ($MyInvocation.InvocationName -cne ".") {
    Invoke-TsfHqDispatchRoutePreviewMain
}
