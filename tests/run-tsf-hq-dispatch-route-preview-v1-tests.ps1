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

$pluginRoot = "fleet/reference/plugin-catalog-risk-v1"
$pluginCatalog = Read-TsfHqJson "$pluginRoot/plugin-catalog.v1.json"
$pluginPacks = Read-TsfHqJson "$pluginRoot/plugin-packs-reference.v1.json"
$pluginPriority = Read-TsfHqJson "$pluginRoot/plugin-review-priority.v1.json"
$pluginRisk = Read-TsfHqJson "$pluginRoot/plugin-risk-policy.v1.json"
Assert-TsfHq ($pluginCatalog.baseline_state -ceq "REVIEW_ONLY_REFERENCE_NOT_RUNTIME_ENFORCED") "PLUGIN-001" "Static plugin catalog preserves exact review-only display state."
Assert-TsfHq ($pluginCatalog.runtime_observation_count -eq 0) "PLUGIN-002" "Static plugin catalog still has zero runtime observations."
Assert-TsfHq (@($pluginCatalog.plugins).Count -eq 36) "PLUGIN-003" "Static plugin catalog still contains 36 references."
Assert-TsfHq (@($pluginCatalog.plugins | Where-Object authority_granted).Count -eq 0) "PLUGIN-004" "No static plugin reference grants authority."
Assert-TsfHq ($pluginPacks.runtime_resolver_input -eq $false) "PLUGIN-005" "Static plugin packs are not resolver input."
Assert-TsfHq ($pluginPriority.prioritization_is_authorization -eq $false) "PLUGIN-006" "Plugin review priority is not authorization."
Assert-TsfHq ($pluginRisk.runtime_enforced -eq $false) "PLUGIN-007" "Plugin risk policy remains non-runtime-enforced."

$protectedFiles = @(
    "tools/New-TsfProjectMainBotMissionDraft.ps1",
    "tools/TsfDurableContract.Canonical.ps1",
    "tools/tsf-codex-app-server-adapter.mjs",
    "tools/Invoke-TsfMissionLifecycle.ps1",
    "tools/Invoke-TsfMissionQueueForegroundExecutor.ps1",
    "tools/Get-TsfAdmissionDecision.ps1",
    "tools/codex-fleet-enforcement-kernel.ps1",
    "fleet/control/worker-role-registry.v1.json",
    "fleet/control/model-routing-alias-policy.v1.json",
    "fleet/reference/plugin-catalog-risk-v1/plugin-catalog.v1.json",
    "fleet/reference/plugin-catalog-risk-v1/plugin-packs-reference.v1.json",
    "fleet/reference/plugin-catalog-risk-v1/plugin-review-priority.v1.json",
    "fleet/reference/plugin-catalog-risk-v1/plugin-risk-policy.v1.json"
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

& node $nodeTestPath
Assert-TsfHq ($LASTEXITCODE -eq 0) "INTEGRATION-001" "Foreground Node endpoint and injection integration suite passes."

$latestPreview = Get-ChildItem -LiteralPath ".codex-local/hq-dispatch/preview" -Filter "*.route-preview.json" -File |
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
}

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

$diffCheckOutput = @(& git diff --check origin/main -- 2>&1)
Assert-TsfHq ($LASTEXITCODE -eq 0) "GIT-001" "git diff --check passes for tracked changes."
if ($diffCheckOutput.Count -gt 0) {
    Write-Host ($diffCheckOutput -join [Environment]::NewLine)
}

if ($script:Failures.Count -gt 0) {
    Write-Host "HQ Dispatch validation failed: $($script:Failures.Count) failures / $script:AssertionCount assertions." -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host "TSF_HQ_DISPATCH_VALIDATION_PASS assertions=$script:AssertionCount actions=$($actions.Count) enabled_actions=$($enabledActions.Count) plugin_runtime_observations=$($pluginCatalog.runtime_observation_count)" -ForegroundColor Green
exit 0
