$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$script:AssertionCount = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert-TsfHq {
    param(
        [bool]$Condition,
        [string]$Id,
        [string]$Message
    )
    $script:AssertionCount += 1
    if ($Condition) {
        Write-Host "PASS [$Id] $Message" -ForegroundColor Green
    } else {
        $script:Failures.Add("[$Id] $Message") | Out-Null
        Write-Host "FAIL [$Id] $Message" -ForegroundColor Red
    }
}

function Read-TsfHqJson {
    param([string]$Path)
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $script:Failures.Add("[JSON-PARSE] $Path failed to parse.") | Out-Null
        return $null
    }
}

function Test-TsfHqSourceHashes {
    param(
        [object[]]$Sources,
        [string]$Prefix
    )
    foreach ($source in @($Sources)) {
        $fullPath = Join-Path $repoRoot ([string]$source.path)
        Assert-TsfHq (Test-Path -LiteralPath $fullPath -PathType Leaf) "$Prefix-SOURCE" "Source exists: $($source.path)"
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant()
            Assert-TsfHq ($actual -ceq [string]$source.sha256) "$Prefix-HASH" "Source hash is current: $($source.path)"
        }
    }
}

function Get-TsfHqCanonicalTextSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $normalizedUtf8 = [System.Text.UTF8Encoding]::new($false)
    $text = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($Path))
    $normalizedText = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $sha256.ComputeHash($normalizedUtf8.GetBytes($normalizedText))
        )).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Copy-TsfHqJsonValue {
    param([Parameter(Mandatory = $true)][object]$Value)
    $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

. ".\tools\TsfJsonContract.ps1"

$controlRoot = "fleet/control/hq-dispatch"
$requestSchemaPath = "$controlRoot/hq-dispatch-route-preview-request.schema.v1.json"
$responseSchemaPath = "$controlRoot/hq-dispatch-route-preview-response.schema.v1.json"
$skillSchemaPath = "$controlRoot/hq-dispatch-skill-registry.schema.v1.json"
$skillRegistryPath = "$controlRoot/hq-dispatch-skill-registry.v1.json"
$actionSchemaPath = "$controlRoot/hq-dispatch-setup-action-registry.schema.v1.json"
$actionRegistryPath = "$controlRoot/hq-dispatch-setup-action-registry.v1.json"

$jsonFiles = @(
    $requestSchemaPath,
    $responseSchemaPath,
    $skillSchemaPath,
    $skillRegistryPath,
    $actionSchemaPath,
    $actionRegistryPath
)
foreach ($path in $jsonFiles) {
    $json = Read-TsfHqJson $path
    Assert-TsfHq ($null -ne $json) "JSON-PARSE" "JSON parses: $path"
}

$requestSchema = Read-TsfHqJson $requestSchemaPath
$responseSchema = Read-TsfHqJson $responseSchemaPath
$skillSchema = Read-TsfHqJson $skillSchemaPath
$skillRegistry = Read-TsfHqJson $skillRegistryPath
$actionSchema = Read-TsfHqJson $actionSchemaPath
$actionRegistry = Read-TsfHqJson $actionRegistryPath

$checksumManifestPath = "docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/SHA256SUMS.txt"
$checksumLines = @(Get-Content -LiteralPath $checksumManifestPath | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
Assert-TsfHq ($checksumLines.Count -eq 19) "CHECKSUM-001" "Checksum manifest covers the other 19 intended files."
foreach ($line in $checksumLines) {
    $matchesChecksum = $line -match "^([a-f0-9]{64})  (.+)$"
    if (!$matchesChecksum) {
        Assert-TsfHq $false "CHECKSUM-002" "Checksum manifest entry has the required format."
        continue
    }
    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    $fullPath = Join-Path $repoRoot $relativePath
    $hashMatches =
        $relativePath -cne $checksumManifestPath -and
        (Test-Path -LiteralPath $fullPath -PathType Leaf) -and
        ((Get-TsfHqCanonicalTextSha256 -Path $fullPath) -ceq $expectedHash)
    Assert-TsfHq $hashMatches "CHECKSUM-002" "Checksum is current: $relativePath"
}

$validRequest = [pscustomobject]@{ natural_request = "Review a bounded local TSF change." }
$unknownRequest = [pscustomobject]@{
    natural_request = "Review a bounded local TSF change."
    command = "caller supplied"
}
$validRequestResult = Test-TsfJsonContract -Value $validRequest -SchemaPath $requestSchemaPath
$unknownRequestResult = Test-TsfJsonContract -Value $unknownRequest -SchemaPath $requestSchemaPath
Assert-TsfHq ($validRequestResult.valid) "SCHEMA-REQUEST-001" "Request schema accepts the sole natural_request field."
Assert-TsfHq (!$unknownRequestResult.valid) "SCHEMA-REQUEST-002" "Request schema rejects unknown command fields."
Assert-TsfHq ($requestSchema.additionalProperties -eq $false) "SCHEMA-REQUEST-003" "Request schema is closed to unknown properties."

$skillValidation = Test-TsfJsonContract -Value $skillRegistry -SchemaPath $skillSchemaPath
$actionValidation = Test-TsfJsonContract -Value $actionRegistry -SchemaPath $actionSchemaPath
Assert-TsfHq ($skillValidation.valid) "SCHEMA-SKILL-001" "Skill registry validates against its versioned schema."
Assert-TsfHq ($actionValidation.valid) "SCHEMA-ACTION-001" "Setup/action registry validates against its versioned schema."
Assert-TsfHq (@($skillRegistry.skills).Count -eq 18) "REGISTRY-SKILL-001" "Skill registry projects all 18 documented skills."
Assert-TsfHq (@($skillRegistry.skills | Where-Object locally_present_definition).Count -eq 5) "REGISTRY-SKILL-002" "Skill registry distinguishes five local definitions."
Assert-TsfHq (@($skillRegistry.skills | Where-Object { !$_.documented_in_skill_map }).Count -eq 0) "REGISTRY-SKILL-003" "Every projected skill preserves documented status."
Test-TsfHqSourceHashes -Sources @($skillRegistry.sources) -Prefix "REGISTRY-SKILL"

$actions = @($actionRegistry.actions)
$enabledActions = @($actions | Where-Object execution_enabled)
Assert-TsfHq ($actions.Count -eq 71) "REGISTRY-ACTION-001" "Setup/action registry projects 71 scoped operations."
Assert-TsfHq ($enabledActions.Count -eq 1) "REGISTRY-ACTION-002" "Exactly one action is execution-enabled."
Assert-TsfHq ($enabledActions[0].action_id -ceq "route-preview") "REGISTRY-ACTION-003" "Route preview is the sole enabled action."
foreach ($action in $actions) {
    $hasRequiredFields =
        ![string]::IsNullOrWhiteSpace([string]$action.class) -and
        ![string]::IsNullOrWhiteSpace([string]$action.source_path) -and
        ![string]::IsNullOrWhiteSpace([string]$action.availability) -and
        $null -ne $action.required_human_gate -and
        $null -ne $action.required_human_gate.required -and
        ![string]::IsNullOrWhiteSpace([string]$action.authority_boundary)
    Assert-TsfHq $hasRequiredFields "REGISTRY-ACTION-004" "Action declares class/source/availability/gate/boundary: $($action.action_id)"
    if ($action.action_id -cne "route-preview") {
        Assert-TsfHq (!$action.execution_enabled) "REGISTRY-ACTION-005" "Non-preview action stays disabled: $($action.action_id)"
    }
}
Test-TsfHqSourceHashes -Sources @($actionRegistry.sources) -Prefix "REGISTRY-ACTION"

$protectedFiles = @(
    "tools/New-TsfProjectMainBotMissionDraft.ps1",
    "tools/TsfDurableContract.Canonical.ps1",
    "tools/tsf-codex-app-server-adapter.mjs",
    "tools/Invoke-TsfMissionLifecycle.ps1",
    "tools/Invoke-TsfMissionQueueForegroundExecutor.ps1",
    "tools/Get-TsfAdmissionDecision.ps1",
    "tools/codex-fleet-enforcement-kernel.ps1",
    "fleet/control/worker-role-registry.v1.json",
    "fleet/control/model-routing-alias-policy.v1.json"
)
foreach ($path in $protectedFiles) {
    $workingBlob = (& git hash-object -- $path).Trim()
    $originBlob = (& git rev-parse ("origin/main:" + $path)).Trim()
    Assert-TsfHq ($LASTEXITCODE -eq 0 -and $workingBlob -ceq $originBlob) "PROTECTED-001" "Protected canonical source is unchanged: $path"
}

$wrapperPath = "tools/hq-dispatch/v1/Invoke-TsfHqDispatchRoutePreview.ps1"
$serverPath = "tools/hq-dispatch/v1/server.mjs"
$uiScriptPath = "tools/hq-dispatch/v1/public/app.js"
$nodeTestPath = "tests/test-tsf-hq-dispatch-route-preview-v1.mjs"
$parserTargets = @($wrapperPath, $PSCommandPath)
foreach ($path in $parserTargets) {
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $path),
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-TsfHq (@($parseErrors).Count -eq 0) "PARSER-PS-001" "PowerShell parser accepts: $path"
    if ($path -eq $wrapperPath) {
        $commandNames = @(
            $ast.FindAll(
                { param($node) $node -is [Management.Automation.Language.CommandAst] },
                $true
            ) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
        )
        $forbiddenCommands = @(
            "Start-Process",
            "Start-Job",
            "Invoke-Command",
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Install-Module",
            "Install-Package",
            "Invoke-TsfMissionLifecycle",
            "Invoke-TsfMissionQueueForegroundExecutor",
            "Get-TsfAdmissionDecision"
        )
        Assert-TsfHq (@($commandNames | Where-Object { $forbiddenCommands -contains $_ }).Count -eq 0) "PARSER-PS-002" "Route wrapper contains no network, background, install, lifecycle, queue, or admission command."
    }
}

foreach ($path in @($serverPath, $uiScriptPath, $nodeTestPath)) {
    & node --check $path
    Assert-TsfHq ($LASTEXITCODE -eq 0) "PARSER-NODE-001" "Node syntax check passes: $path"
}

$serverSource = Get-Content -Raw -LiteralPath $serverPath
$wrapperSource = Get-Content -Raw -LiteralPath $wrapperPath
Assert-TsfHq (@([regex]::Matches($serverSource, "\bspawn\(")).Count -eq 1) "BOUNDARY-001" "Server contains exactly one child-process invocation site."
Assert-TsfHq ($serverSource -match "ROUTE_PREVIEW_WRAPPER") "BOUNDARY-002" "Server child invocation is bound to the fixed route-preview wrapper."
Assert-TsfHq ($serverSource -notmatch "process\.env|0\.0\.0\.0") "BOUNDARY-003" "Server exposes no environment override or wildcard listener."
Assert-TsfHq ($wrapperSource -match [regex]::Escape(".codex-local\hq-dispatch\preview")) "BOUNDARY-004" "Wrapper hardcodes the only artifact root."
Assert-TsfHq ($wrapperSource -notmatch "approval-ledger|Invoke-TsfMissionLifecycle|Invoke-TsfMissionQueueForegroundExecutor|Get-TsfAdmissionDecision|tsf-codex-app-server-adapter") "BOUNDARY-005" "Wrapper exposes no approval, lifecycle, queue, admission, or app-server operation."
Assert-TsfHq ($serverSource -notmatch "plugin-catalog-risk-v1" -and $serverSource -match "plugin_registry_projected: false") "BOUNDARY-006" "Server reads and projects no plugin registry."
Assert-TsfHq ($wrapperSource -match "FileMode\]::CreateNew" -and $wrapperSource -match "attempt -le 8") "ARTIFACT-COLLISION-001" "Wrapper uses bounded exclusive-create collision handling."

$collisionResult = & {
    # Keep the wrapper's strict-mode setting inside this child scope so it cannot
    # alter the canonical JSON-contract validator used later in this harness.
    . (Resolve-Path -LiteralPath $wrapperPath)
    $collisionRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".codex-local\hq-dispatch\preview"))
    New-Item -ItemType Directory -Force -Path $collisionRoot | Out-Null
    $collisionPath = Join-Path $collisionRoot "hq-preview-00000000000000000000000000000000.route-preview.json"
    if (Test-Path -LiteralPath $collisionPath -PathType Leaf) {
        Remove-Item -LiteralPath $collisionPath -Force
    }
    $collisionMarker = "existing-preview-artifact-must-not-change"
    [System.IO.File]::WriteAllText($collisionPath, $collisionMarker, [System.Text.UTF8Encoding]::new($false))
    $collisionHashBefore = (Get-FileHash -LiteralPath $collisionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $collisionRejected = $false
    try {
        Write-TsfHqPreviewArtifactExclusive -Path $collisionPath -Content "replacement-content-must-not-win"
    } catch {
        $collisionRejected = $_.Exception.Message -ceq "PREVIEW_ARTIFACT_COLLISION"
    } finally {
        $collisionHashAfter = (Get-FileHash -LiteralPath $collisionPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Remove-Item -LiteralPath $collisionPath -Force
    }
    [pscustomobject]@{
        rejected = $collisionRejected
        unchanged = $collisionHashAfter -ceq $collisionHashBefore
    }
}
Assert-TsfHq $collisionResult.rejected "ARTIFACT-COLLISION-002" "An existing artifact path fails as a deterministic collision."
Assert-TsfHq $collisionResult.unchanged "ARTIFACT-COLLISION-003" "A collision cannot overwrite an existing artifact."

$previewPathsBefore = @(Get-ChildItem -LiteralPath ".codex-local/hq-dispatch/preview" -Filter "*.route-preview.json" -File -ErrorAction SilentlyContinue | ForEach-Object FullName)
& node $nodeTestPath
Assert-TsfHq ($LASTEXITCODE -eq 0) "INTEGRATION-001" "Foreground Node endpoint and injection integration suite passes."

$latestPreview = Get-ChildItem -LiteralPath ".codex-local/hq-dispatch/preview" -Filter "*.route-preview.json" -File |
    Where-Object { $_.FullName -notin $previewPathsBefore } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
Assert-TsfHq ($null -ne $latestPreview) "ARTIFACT-001" "At least one preview artifact was produced."
if ($null -ne $latestPreview) {
    $preview = Read-TsfHqJson $latestPreview.FullName
    $previewValidation = Test-TsfJsonContract -Value $preview -SchemaPath $responseSchemaPath
    Assert-TsfHq ($previewValidation.valid) "ARTIFACT-002" "Preview artifact validates against the response schema."
    Assert-TsfHq ($preview.record_kind -ceq "hq_dispatch_route_preview") "ARTIFACT-003" "Preview artifact is explicitly not a mission record."
    Assert-TsfHq ($preview.artifact.mission_record -eq $false -and $preview.artifact.queue_record -eq $false) "ARTIFACT-004" "Preview artifact denies mission and queue record identity."
    Assert-TsfHq ($preview.authority.mission_execution_enabled -eq $false) "ARTIFACT-005" "Preview artifact denies mission execution."

    $explanationNames = @(
        "project_lane", "classification", "worker_role", "model_routing",
        "access_proposal", "allowed_reads", "allowed_writes",
        "forbidden_operations", "approvals_required", "clarifications_required",
        "stop_conditions", "authority_not_granted"
    )
    Assert-TsfHq ($preview.route_explanation.schema_version -ceq "tsf_hq_dispatch_route_explanation_v1") "EXPLANATION-001" "Complete versioned explanation is accepted."
    foreach ($name in $explanationNames) {
        $element = $preview.route_explanation.$name
        $validElement =
            ![string]::IsNullOrWhiteSpace([string]$element.reason_code) -and
            ![string]::IsNullOrWhiteSpace([string]$element.summary) -and
            @($element.canonical_source_bindings).Count -gt 0
        Assert-TsfHq $validElement "EXPLANATION-002" "Explanation element is complete: $name"
    }

    $missingProjectLane = Copy-TsfHqJsonValue $preview
    $missingProjectLane.route_explanation.PSObject.Properties.Remove("project_lane")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingProjectLane -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-001" "Missing project/lane explanation is rejected."
    $missingAccess = Copy-TsfHqJsonValue $preview
    $missingAccess.PSObject.Properties.Remove("access_proposal")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingAccess -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-002" "Missing access proposal is rejected."
    $missingRole = Copy-TsfHqJsonValue $preview
    $missingRole.route_explanation.PSObject.Properties.Remove("worker_role")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingRole -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-003" "Missing role-fit explanation is rejected."
    $missingModel = Copy-TsfHqJsonValue $preview
    $missingModel.route_explanation.PSObject.Properties.Remove("model_routing")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingModel -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-004" "Missing model/effort explanation is rejected."
    $missingAuthority = Copy-TsfHqJsonValue $preview
    $missingAuthority.route_explanation.PSObject.Properties.Remove("authority_not_granted")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingAuthority -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-005" "Missing authority exclusions are rejected."
    $missingBindings = Copy-TsfHqJsonValue $preview
    $missingBindings.route_explanation.worker_role.PSObject.Properties.Remove("canonical_source_bindings")
    Assert-TsfHq (!(Test-TsfJsonContract -Value $missingBindings -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-006" "Missing source bindings are rejected."
    $emptySummary = Copy-TsfHqJsonValue $preview
    $emptySummary.route_explanation.model_routing.summary = ""
    Assert-TsfHq (!(Test-TsfJsonContract -Value $emptySummary -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-007" "Empty explanation summaries are rejected."
    $unknownNested = Copy-TsfHqJsonValue $preview
    $unknownNested.route_explanation.project_lane | Add-Member -NotePropertyName unexpected -NotePropertyValue "rejected"
    Assert-TsfHq (!(Test-TsfJsonContract -Value $unknownNested -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-008" "Unknown nested explanation fields are rejected."
    $malformedReason = Copy-TsfHqJsonValue $preview
    $malformedReason.route_explanation.classification.reason_code = "not-valid"
    Assert-TsfHq (!(Test-TsfJsonContract -Value $malformedReason -SchemaPath $responseSchemaPath).valid) "EXPLANATION-NEG-009" "Malformed explanation reason codes are rejected."

    $projectBindings = @($preview.route_explanation.project_lane.canonical_source_bindings)
    Assert-TsfHq (@($projectBindings | Where-Object { $_.source_field -ceq "draft.mission_packet.project_id" -and $_.observed_value -ceq $preview.proposed_project.project_id }).Count -eq 1) "EXPLANATION-SEM-001" "Project rationale binds the fixed canonical project."
    Assert-TsfHq (@($projectBindings | Where-Object { $_.source_field -ceq "draft.mission_packet.lane" -and $_.observed_value -ceq $preview.proposed_project.lane }).Count -eq 1) "EXPLANATION-SEM-002" "Lane rationale binds the fixed canonical lane."
    $roleBindings = @($preview.route_explanation.worker_role.canonical_source_bindings)
    Assert-TsfHq (@($roleBindings | Where-Object { $_.source_field -ceq "draft.normalized_intent.proposed_worker_role" -and $_.observed_value -ceq $preview.proposed_worker_role.role_id }).Count -eq 1) "EXPLANATION-SEM-003" "Role explanation binds the canonical role result."
    $modelBindings = @($preview.route_explanation.model_routing.canonical_source_bindings)
    $modelValues = @($modelBindings | ForEach-Object { [string]$_.observed_value })
    Assert-TsfHq ($modelValues -contains [string]$preview.model_routing.stable_alias -and $modelValues -contains [string]$preview.model_routing.resolved_model -and $modelValues -contains [string]$preview.model_routing.reasoning_effort) "EXPLANATION-SEM-004" "Model explanation binds alias, model, and effort outputs."
    Assert-TsfHq ($preview.access_proposal.access_level -ceq "TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION" -and $preview.access_proposal.network_scope -ceq "NO_NETWORK" -and $preview.access_proposal.execution_scope -ceq "ROUTE_PREVIEW_ONLY_NO_EXECUTION") "EXPLANATION-SEM-005" "Access explanation remains recommendation-only with no network or execution scope."
    Assert-TsfHq ((Get-TsfContractJsonHash -Value @($preview.access_proposal.read_scope)) -ceq (Get-TsfContractJsonHash -Value @($preview.allowed_reads)) -and (Get-TsfContractJsonHash -Value @($preview.access_proposal.write_scope)) -ceq (Get-TsfContractJsonHash -Value @($preview.allowed_writes))) "EXPLANATION-SEM-006" "Access scopes match the projected reads and writes."
    Assert-TsfHq ($preview.authority.preview_only -and !$preview.authority.mission_execution_enabled -and !$preview.authority.mission_submission_enabled -and !$preview.authority.queue_mutation_enabled -and !$preview.authority.approval_mutation_enabled) "EXPLANATION-SEM-007" "No explanation or access proposal grants authority."
    $allBindings = @($explanationNames | ForEach-Object { @($preview.route_explanation.$_.canonical_source_bindings) })
    $allowedAssurances = @("CANONICAL_POLICY_OUTPUT", "CANONICAL_REGISTRY_OUTPUT", "FIXED_MILESTONE_BOUNDARY", "UNKNOWN_OR_RECOMMENDATION_ONLY")
    Assert-TsfHq (@($allBindings | Where-Object { $allowedAssurances -notcontains [string]$_.assurance -or [string]::IsNullOrWhiteSpace([string]$_.source_path) -or [string]::IsNullOrWhiteSpace([string]$_.source_field) }).Count -eq 0) "EXPLANATION-SEM-008" "All explanation bindings retain bounded source and assurance data."
    Assert-TsfHq (($preview.route_explanation | ConvertTo-Json -Depth 40) -notmatch [regex]::Escape("Review a bounded TSF-local documentation change.")) "EXPLANATION-SEM-009" "Explanation provenance does not retain the raw natural request."
}

$legacyRawArtifacts = @()
foreach ($file in @(Get-ChildItem -LiteralPath ".codex-local/hq-dispatch/preview" -File -Filter "*.route-preview.json" -ErrorAction SilentlyContinue)) {
    $value = Read-TsfHqJson $file.FullName
    if ($null -ne $value -and $value.PSObject.Properties.Name -contains "natural_request") {
        $legacyRawArtifacts += $file.Name
    }
}
Assert-TsfHq ($legacyRawArtifacts.Count -eq 0) "ARTIFACT-HYGIENE-001" "Legacy cleanup leaves zero preview artifacts with raw natural_request fields."

$pluginBaselineChanges = @(& git diff --name-only origin/main -- ":(glob)**/*plugin*" ":(glob)**/plugins/**")
$pluginBaselineChanges = @($pluginBaselineChanges | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
Assert-TsfHq ($pluginBaselineChanges.Count -eq 0) "PLUGIN-BASELINE-001" "Static plugin baseline has no feature-branch mutation."

$changed = @(
    & git diff --name-only origin/main --
    & git ls-files --others --exclude-standard
) | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Replace("\", "/") } | Sort-Object -Unique
$allowedScope = [regex]"^(fleet/control/hq-dispatch/|tools/hq-dispatch/v1/|docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/|tests/test-tsf-hq-dispatch-route-preview-v1\.mjs$|tests/run-tsf-hq-dispatch-route-preview-v1-tests\.ps1$)"
$outsideScope = @($changed | Where-Object { !$allowedScope.IsMatch($_) })
Assert-TsfHq ($outsideScope.Count -eq 0) "SCOPE-001" "Only intended Milestone 1 files are changed."
if ($outsideScope.Count -gt 0) {
    Write-Host "Outside scope: $($outsideScope -join ', ')" -ForegroundColor Red
}
$forbiddenChangedPattern = [regex]"(?i)(mission-envelope|result-envelope|admission|lifecycle|recovery|producer|queue.*schema|approval-ledger|plugin-catalog-risk-v1/|TsfDurableContract\.Canonical|ProjectMainBotMissionDraft|codex-fleet-enforcement-kernel)"
$forbiddenChanged = @($changed | Where-Object { $forbiddenChangedPattern.IsMatch($_) })
Assert-TsfHq ($forbiddenChanged.Count -eq 0) "SCOPE-002" "No canonical mission, result, admission, lifecycle, recovery, producer, queue, approval, plugin, routing, or kernel file changed."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$diffCheckOutput = @(& git -c core.autocrlf=false diff --check origin/main -- 2>&1)
$diffCheckExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
Assert-TsfHq ($diffCheckExitCode -eq 0) "GIT-001" "git diff --check passes for tracked changes."
if ($diffCheckOutput.Count -gt 0) {
    Write-Host ($diffCheckOutput -join [Environment]::NewLine)
}

if ($script:Failures.Count -gt 0) {
    Write-Host "HQ Dispatch validation failed: $($script:Failures.Count) failures / $script:AssertionCount assertions." -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host "TSF_HQ_DISPATCH_VALIDATION_PASS assertions=$script:AssertionCount actions=$($actions.Count) enabled_actions=$($enabledActions.Count) external_integrations=disabled" -ForegroundColor Green
exit 0
