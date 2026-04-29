[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [ValidateSet("warn", "enforce")]
    [string]$Mode = "warn",

    [string]$OutDir = "out\launch-gates"
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (Test-Path $fleetRuntime) {
    . $fleetRuntime
}

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    param([string]$Path)

    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) { Stop-WithMessage "Config not found: $Path" }

    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) { return @($loaded) }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") { return @($loaded.value) }
    if ($null -ne $loaded) { return @($loaded) }
    return @()
}

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-DecisionFromText {
    param([string]$Text)

    $match = [regex]::Match($Text, "(?im)^\s*Decision:\s*(ADMIT|REVISE|PARK|CONTINUE|REPAIR|SIMPLIFY|NEEDS HUMAN DIRECTION)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().ToUpperInvariant() }
    $lineMatch = [regex]::Match($Text, "(?im)^[A-Za-z0-9_-]+:\s+(ADMIT|REVISE|PARK|CONTINUE|REPAIR|SIMPLIFY|NEEDS HUMAN DIRECTION)\b")
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim().ToUpperInvariant() }
    return "UNKNOWN"
}

function Get-SectionText {
    param(
        [string]$Text,
        [string]$Heading
    )

    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-CurrentPhase {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\PHASE_STATE.md"
    if (!(Test-Path -LiteralPath $path)) { return "" }
    $text = Get-Content -LiteralPath $path -Raw
    $match = [regex]::Match($text, "(?im)^Current Phase:\s*([a-z-]+)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().ToLowerInvariant() }
    return ""
}

function Get-FirstUncheckedTaskLine {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) { return "" }
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match "^\s*-\s+\[ \]\s+(.+)$") {
            return $line.Trim()
        }
    }
    return ""
}

function Test-TaskHasProductShape {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    foreach ($label in @("User pain:", "Target:", "Change:", "Remove/simplify:", "Guardrails:", "Acceptance:", "Check:")) {
        if ($Task -notmatch [regex]::Escape($label)) { return $false }
    }
    return $true
}

function Test-TaskHasForbiddenScopeLocal {
    param([string]$Task)

    if (Get-Command Test-FleetTaskHasForbiddenScope -ErrorAction SilentlyContinue) {
        return (Test-FleetTaskHasForbiddenScope -Task $Task)
    }

    return ($Task -match "(?i)\b(forbidden scope|do not|don't|must not|avoid touching|without touching|no auth|no backend|no payments|no package|no dependency)\b")
}

function Test-HasLocalEvaluator {
    param(
        [object]$Ship,
        [string]$RepoPath
    )

    $buildCommand = [string](Get-ConfigPropertyValue -Object $Ship -Name "buildCommand")
    $visualPaths = @(Get-ConfigPropertyValue -Object $Ship -Name "visualPaths" | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($buildCommand)) { return $true }
    if ($visualPaths.Count -gt 0) { return $true }

    $evalPath = Join-Path $RepoPath "docs\codex\EVALUATORS.md"
    if (!(Test-Path -LiteralPath $evalPath)) { return $false }
    $evalText = Get-Content -LiteralPath $evalPath -Raw
    $buildSection = Get-SectionText -Text $evalText -Heading "Build Evaluator"
    $productSection = Get-SectionText -Text $evalText -Heading "Product Evaluator"
    $dataSection = Get-SectionText -Text $evalText -Heading "Data Or Formula Evaluator"
    return (($buildSection -match "(?i)Command:\s*\S+") -or ($productSection -match "(?i)Expected user outcome:\s*\S+") -or ($dataSection -match "(?i)(Fixtures|Golden values):\s*\S+"))
}

Set-Location $fleetRoot
$ship = @(Get-Projects -Path $ConfigPath | Where-Object { [string]$_.name -ceq [string]$Project })
if ($ship.Count -ne 1) { Stop-WithMessage "Project not found or ambiguous: $Project" }
$ship = $ship[0]

$repo = Resolve-Path ([string]$ship.repo) -ErrorAction SilentlyContinue
if (!$repo) { Stop-WithMessage "Repo not found: $($ship.repo)" }
$repoPath = $repo.Path

$issues = [System.Collections.Generic.List[object]]::new()

function Add-Issue {
    param(
        [ValidateSet("WARN", "BLOCK")]
        [string]$Severity,
        [string]$Message
    )
    $issues.Add([pscustomobject]@{ Severity = $Severity; Message = $Message }) | Out-Null
}

$admissionOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "ship-admission.ps1") -Project $Project -Config $ConfigPath -NoWrite 2>&1
$admissionText = ($admissionOutput | Out-String)
$admissionDecision = Get-DecisionFromText -Text $admissionText
if ($admissionDecision -eq "PARK") {
    Add-Issue -Severity "BLOCK" -Message "Ship admission is PARK."
} elseif ($admissionDecision -eq "REVISE") {
    Add-Issue -Severity "WARN" -Message "Ship admission is REVISE; sharpen admission docs before long runs."
} elseif ($admissionDecision -ne "ADMIT") {
    Add-Issue -Severity "WARN" -Message "Ship admission decision is unknown."
}

$usefulnessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "product-usefulness.ps1") -Project $Project -Config $ConfigPath -NoWrite 2>&1
$usefulnessText = ($usefulnessOutput | Out-String)
$usefulnessDecision = Get-DecisionFromText -Text $usefulnessText
if ($usefulnessDecision -in @("PARK", "NEEDS HUMAN DIRECTION")) {
    Add-Issue -Severity "BLOCK" -Message "Product usefulness is $usefulnessDecision."
} elseif ($usefulnessDecision -in @("REPAIR", "SIMPLIFY")) {
    Add-Issue -Severity "WARN" -Message "Product usefulness asks for $usefulnessDecision; launch should use the matching phase."
} elseif ($usefulnessDecision -ne "CONTINUE") {
    Add-Issue -Severity "WARN" -Message "Product usefulness decision is unknown."
}

$currentPhase = Get-CurrentPhase -RepoPath $repoPath
if ($currentPhase -eq "parked" -and $LoopPhase -ne "parked") {
    Add-Issue -Severity "BLOCK" -Message "Ship phase is parked but requested loop phase is $LoopPhase."
} elseif ($LoopPhase -ne "auto" -and ![string]::IsNullOrWhiteSpace($currentPhase) -and $currentPhase -ne $LoopPhase) {
    if (!($LoopPhase -eq "repair" -or $currentPhase -eq "repair")) {
        Add-Issue -Severity "WARN" -Message "Requested loop phase $LoopPhase does not match PHASE_STATE current phase $currentPhase."
    }
}

$task = Get-FirstUncheckedTaskLine -RepoPath $repoPath
if (![string]::IsNullOrWhiteSpace($task)) {
    if (!(Test-TaskHasProductShape -Task $task)) {
        Add-Issue -Severity "BLOCK" -Message "First unchecked task is missing product-shape fields."
    }
    if (!(Test-TaskHasForbiddenScopeLocal -Task $task)) {
        Add-Issue -Severity "BLOCK" -Message "First unchecked task is missing explicit forbidden scope."
    }
} else {
    if ($usefulnessDecision -in @("CONTINUE", "REPAIR", "SIMPLIFY")) {
        Add-Issue -Severity "WARN" -Message "No unchecked tasks exist; planner must generate product-shaped tasks before implementation."
    } else {
        Add-Issue -Severity "BLOCK" -Message "No unchecked tasks exist and usefulness gate is not ready to continue."
    }
}

if (!(Test-HasLocalEvaluator -Ship $ship -RepoPath $repoPath)) {
    Add-Issue -Severity "BLOCK" -Message "No local evaluator found in buildCommand, visualPaths, or EVALUATORS.md."
}

$blockCount = @($issues | Where-Object { $_.Severity -eq "BLOCK" }).Count
$warnCount = @($issues | Where-Object { $_.Severity -eq "WARN" }).Count
$decision = if ($blockCount -gt 0) { "BLOCK" } elseif ($warnCount -gt 0) { "WARN" } else { "READY" }

$outRoot = Join-Path $fleetRoot $OutDir
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$safeName = ([string]$Project) -replace "[^A-Za-z0-9_.-]+", "-"
$outPath = Join-Path $outRoot "$safeName.md"

$lines = @(
    "# Fleet Launch Gate",
    "",
    "Generated: $(Get-Date -Format o)",
    "",
    "Project: $Project",
    "",
    "Repo: $repoPath",
    "",
    "Decision: $decision",
    "",
    "Mode: $Mode",
    "",
    "Requested loop phase: $LoopPhase",
    "",
    "Current phase: $(if ([string]::IsNullOrWhiteSpace($currentPhase)) { 'missing' } else { $currentPhase })",
    "",
    "Admission decision: $admissionDecision",
    "",
    "Usefulness decision: $usefulnessDecision",
    "",
    "First unchecked task: $(if ([string]::IsNullOrWhiteSpace($task)) { 'none' } else { $task })",
    "",
    "## Issues",
    ""
)
if ($issues.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($issue in $issues) {
        $lines += "- [$($issue.Severity)] $($issue.Message)"
    }
}
$lines += ""
$lines += "## Raw Admission Output"
$lines += ""
$lines += '```text'
$lines += $admissionText.Trim()
$lines += '```'
$lines += ""
$lines += "## Raw Usefulness Output"
$lines += ""
$lines += '```text'
$lines += $usefulnessText.Trim()
$lines += '```'

Set-Content -LiteralPath $outPath -Value ($lines -join "`n")

$color = switch ($decision) {
    "READY" { "Green" }
    "WARN" { "Yellow" }
    "BLOCK" { "Red" }
    default { "White" }
}
Write-Host "Launch gate ${Project}: $decision (admission=$admissionDecision, usefulness=$usefulnessDecision)" -ForegroundColor $color
Write-Host "Report: $outPath" -ForegroundColor DarkCyan
foreach ($issue in $issues) {
    Write-Host "  [$($issue.Severity)] $($issue.Message)"
}

if ($Mode -eq "enforce" -and $decision -eq "BLOCK") {
    exit 1
}

exit 0
