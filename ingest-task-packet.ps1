[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)][string]$PacketPath,
    [string]$ConfigPath = ".\projects.json",
    [switch]$Apply,
    [switch]$AllowStaleBaseCommit
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")

function Resolve-LocalPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Get-Phase0Property {
    param(
        [object]$Object,
        [string]$Name
    )
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-Phase0NonEmptyList {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    return ((@($Value) | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0)
}

function Test-Phase0Gate {
    param([object]$Gate)

    $issues = [System.Collections.Generic.List[string]]::new()
    $allowedClassifications = @(
        "already_exists_admitted",
        "exists_display_only",
        "exists_review_only",
        "exists_not_joined",
        "exists_wrong_scope",
        "exists_stale",
        "exists_conflicting",
        "exists_duplicate",
        "not_found"
    )
    $allowedReuseDecisions = @(
        "REUSE",
        "ADMIT_OR_GATE",
        "ADAPTER_NEEDED",
        "NULL_FENCE_NEEDED",
        "VALIDATION_NEEDED",
        "NEW_BUILD_ALLOWED",
        "STOP"
    )

    if ($null -eq $Gate) {
        $issues.Add("Missing phase0Gate.") | Out-Null
        return @($issues)
    }

    $lane = Get-Phase0Property -Object $Gate -Name "laneScopeDeclaration"
    $trace = Get-Phase0Property -Object $Gate -Name "existingAssetTrace"
    $buildPermission = Get-Phase0Property -Object $Gate -Name "buildPermission"
    $reuseDecision = [string](Get-Phase0Property -Object $Gate -Name "reuseDecision")
    $scopeExpansionRule = [string](Get-Phase0Property -Object $Gate -Name "scopeExpansionRule")

    if ($null -eq $lane) { $issues.Add("phase0Gate missing laneScopeDeclaration.") | Out-Null }
    if ($null -eq $trace) { $issues.Add("phase0Gate missing existingAssetTrace.") | Out-Null }
    if ($null -eq $buildPermission) { $issues.Add("phase0Gate missing buildPermission.") | Out-Null }

    if ([string]::IsNullOrWhiteSpace($reuseDecision)) {
        $issues.Add("phase0Gate missing reuseDecision.") | Out-Null
    } elseif ($allowedReuseDecisions -notcontains $reuseDecision) {
        $issues.Add("phase0Gate reuseDecision is not an approved Phase 0 decision: $reuseDecision") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($scopeExpansionRule) -or $scopeExpansionRule -notmatch "TIM_REQUIRED_SCOPE_EXPANSION") {
        $issues.Add("phase0Gate scopeExpansionRule must require TIM_REQUIRED_SCOPE_EXPANSION.") | Out-Null
    }

    if ($null -ne $lane) {
        foreach ($field in @("laneType", "allowedSearchScope", "forbiddenSearchScope", "canonicalRepoInspectionAllowed", "normalNwrPacketReadsAllowed", "crossLaneComparisonAllowed", "mutationAllowed", "timApprovalRequiredForScopeExpansion")) {
            $value = Get-Phase0Property -Object $lane -Name $field
            if ($null -eq $value) { $issues.Add("phase0Gate laneScopeDeclaration missing $field.") | Out-Null }
        }
        if (!(Test-Phase0NonEmptyList -Value (Get-Phase0Property -Object $lane -Name "allowedSearchScope"))) {
            $issues.Add("phase0Gate allowedSearchScope must name at least one allowed search surface.") | Out-Null
        }
        if (!(Test-Phase0NonEmptyList -Value (Get-Phase0Property -Object $lane -Name "forbiddenSearchScope"))) {
            $issues.Add("phase0Gate forbiddenSearchScope must name at least one forbidden search surface.") | Out-Null
        }
    }

    if ($null -ne $trace) {
        foreach ($field in @("searchedLocations", "matchingFilesOrFolders", "relevantExistingArtifacts", "classification", "reuseDecision", "whyNewBuildIsOrIsNotAllowed", "restrictedScopeExclusions")) {
            $value = Get-Phase0Property -Object $trace -Name $field
            if ($null -eq $value) { $issues.Add("phase0Gate existingAssetTrace missing $field.") | Out-Null }
        }
        if (!(Test-Phase0NonEmptyList -Value (Get-Phase0Property -Object $trace -Name "searchedLocations"))) {
            $issues.Add("phase0Gate searchedLocations must include at least one searched location.") | Out-Null
        }
        $classification = [string](Get-Phase0Property -Object $trace -Name "classification")
        if ([string]::IsNullOrWhiteSpace($classification)) {
            $issues.Add("phase0Gate existingAssetTrace missing classification.") | Out-Null
        } elseif ($allowedClassifications -notcontains $classification) {
            $issues.Add("phase0Gate classification is not approved: $classification") | Out-Null
        }
        $traceReuseDecision = [string](Get-Phase0Property -Object $trace -Name "reuseDecision")
        if ([string]::IsNullOrWhiteSpace($traceReuseDecision)) {
            $issues.Add("phase0Gate existingAssetTrace missing reuseDecision.") | Out-Null
        } elseif ($allowedReuseDecisions -notcontains $traceReuseDecision) {
            $issues.Add("phase0Gate existingAssetTrace reuseDecision is not approved: $traceReuseDecision") | Out-Null
        }
        $why = [string](Get-Phase0Property -Object $trace -Name "whyNewBuildIsOrIsNotAllowed")
        if ([string]::IsNullOrWhiteSpace($why)) {
            $issues.Add("phase0Gate must explain why new build is or is not allowed.") | Out-Null
        }
    }

    if ($null -ne $buildPermission) {
        $newBuildAllowed = Get-Phase0Property -Object $buildPermission -Name "newBuildAllowed"
        $whyBuild = [string](Get-Phase0Property -Object $buildPermission -Name "whyNewBuildIsOrIsNotAllowed")
        if ($null -eq $newBuildAllowed) { $issues.Add("phase0Gate buildPermission missing newBuildAllowed.") | Out-Null }
        if ([string]::IsNullOrWhiteSpace($whyBuild)) { $issues.Add("phase0Gate buildPermission must explain why new build is or is not allowed.") | Out-Null }
    }

    return @($issues)
}

$packetFullPath = Resolve-LocalPath $PacketPath
$configFullPath = Resolve-LocalPath $ConfigPath
if (!(Test-Path -LiteralPath $packetFullPath)) { throw "Packet not found: $packetFullPath" }
if (!(Test-Path -LiteralPath $configFullPath)) { throw "Config not found: $configFullPath" }

$reportRoot = Join-Path $fleetRoot ".codex-local\packets"
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$packet = Get-Content -LiteralPath $packetFullPath -Raw | ConvertFrom-Json
$projects = @(Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json)
$packetId = if ($packet.packetId) { [string]$packet.packetId } else { "packet-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
$storedPacket = Join-Path $reportRoot "$packetId.json"
$reportMd = Join-Path $reportRoot "$packetId.INGEST.md"
$reportJson = Join-Path $reportRoot "$packetId.INGEST.json"

$errors = [System.Collections.Generic.List[string]]::new()
$accepted = [System.Collections.Generic.List[object]]::new()
$rejected = [System.Collections.Generic.List[object]]::new()

if ([string]::IsNullOrWhiteSpace([string]$packet.project)) { $errors.Add("Missing project.") | Out-Null }
if ([string]::IsNullOrWhiteSpace([string]$packet.baseCommit)) { $errors.Add("Missing baseCommit.") | Out-Null }
if ($null -eq $packet.tasks) { $errors.Add("Missing tasks.") | Out-Null }
$phase0GateIssues = @(Test-Phase0Gate -Gate $packet.phase0Gate)
foreach ($issue in $phase0GateIssues) { $errors.Add($issue) | Out-Null }

$project = @($projects | Where-Object { [string]$_.name -eq [string]$packet.project }) | Select-Object -First 1
if ($null -eq $project) {
    $errors.Add("Unknown project: $($packet.project)") | Out-Null
} else {
    $repoState = Get-FleetRepoState -Repo ([string]$project.repo)
    if ($repoState.state -ne "clean" -and $repoState.state -ne "dirty") {
        $errors.Add("Project repo is $($repoState.state): $($repoState.message)") | Out-Null
    } elseif (!$AllowStaleBaseCommit -and [string]$packet.baseCommit -ne [string]$repoState.head) {
        $errors.Add("Stale baseCommit: packet $($packet.baseCommit), repo $($repoState.head)") | Out-Null
    }
}

if ((Test-Path -LiteralPath $storedPacket) -and $Apply) {
    $errors.Add("Duplicate packet ID already stored: $packetId") | Out-Null
}

$seenTaskIds = @{}
foreach ($task in @($packet.tasks)) {
    $id = [string]$task.id
    $line = [string]$task.checklistLine
    $taskErrors = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($id)) { $taskErrors.Add("missing task id") | Out-Null }
    if ($seenTaskIds.ContainsKey($id)) { $taskErrors.Add("duplicate task id $id") | Out-Null } else { $seenTaskIds[$id] = $true }
    if ([string]::IsNullOrWhiteSpace($line)) { $taskErrors.Add("missing checklistLine") | Out-Null }
    $contract = if (![string]::IsNullOrWhiteSpace($line)) { Test-FleetTaskContractLine -Line $line } else { [pscustomobject]@{ valid = $false; missing = @("checklistLine"); metadataOk = $false } }
    if (!$contract.valid) {
        $taskErrors.Add("invalid Task Contract V2 line; missing=$($contract.missing -join ', '); metadataOk=$($contract.metadataOk)") | Out-Null
    }
    if ($line -match "(?i)(secrets?|auth|payment|deploy|migration|package\.json|package-lock\.json)" -and $line -notmatch "(?i)explicit approval") {
        $taskErrors.Add("forbidden/sensitive scope without explicit approval") | Out-Null
    }
    if ($taskErrors.Count -gt 0) {
        $rejected.Add([pscustomobject]@{ id = $id; reasons = @($taskErrors) }) | Out-Null
    } else {
        $accepted.Add([pscustomobject]@{ id = $id; line = $line }) | Out-Null
    }
}

$valid = ($errors.Count -eq 0 -and $rejected.Count -eq 0)
if ($Apply -and $valid) {
    Copy-Item -LiteralPath $packetFullPath -Destination $storedPacket -Force
    $queuePath = Join-Path ([string]$project.repo) "docs\codex\TASK_QUEUE.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $queuePath) | Out-Null
    if (!(Test-Path -LiteralPath $queuePath)) { Set-Content -Path $queuePath -Encoding UTF8 -Value "# Task Queue`r`n" }
    Add-Content -Path $queuePath -Encoding UTF8 -Value ("`r`n## External audit tasks - $packetId - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n")
    foreach ($task in $accepted) {
        $line = [string]$task.line
        if ($line -notmatch "^\s*-\s+\[.\]") { $line = "- [ ] $line" }
        Add-Content -Path $queuePath -Encoding UTF8 -Value $line
    }
}

$result = [pscustomobject]@{
    packetId = $packetId
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    project = [string]$packet.project
    valid = $valid
    applied = ($Apply -and $valid)
    phase0GateValid = ($phase0GateIssues.Count -eq 0)
    phase0GateIssues = @($phase0GateIssues)
    errors = @($errors)
    accepted = @($accepted)
    rejected = @($rejected)
    storedPacket = if (Test-Path -LiteralPath $storedPacket) { $storedPacket } else { "" }
}
$result | ConvertTo-Json -Depth 12 | Set-Content -Path $reportJson -Encoding UTF8
@(
    "# External Audit Ingest",
    "",
    "- Packet ID: $packetId",
    "- Project: $($packet.project)",
    "- Valid: $valid",
    "- Applied: $($Apply -and $valid)",
    "- Phase 0 gate valid: $($phase0GateIssues.Count -eq 0)",
    "- Accepted tasks: $($accepted.Count)",
    "- Rejected tasks: $($rejected.Count)",
    "",
    "## Errors",
    $(if ($errors.Count -eq 0) { "- None" } else { @($errors | ForEach-Object { "- $_" }) }),
    "",
    "## Rejected",
    $(if ($rejected.Count -eq 0) { "- None" } else { @($rejected | ForEach-Object { "- $($_.id): $($_.reasons -join '; ')" }) })
) | Set-Content -Path $reportMd -Encoding UTF8

Write-Host "INGEST_REPORT: $reportMd"
Write-Host "INGEST_JSON: $reportJson"
if (!$valid) { exit 1 }
