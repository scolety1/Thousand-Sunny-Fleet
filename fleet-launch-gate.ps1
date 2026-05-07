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

function Get-UsefulnessRequestedPhase {
    param([string]$Decision)

    switch (($Decision).Trim().ToUpperInvariant()) {
        "REPAIR" { return "repair" }
        "SIMPLIFY" { return "simplicity" }
        default { return "" }
    }
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

function Test-TaskRequiresSurface {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    if ($Task -match "(?i)(?:^|[\s\[])impact:(visible|showpiece)\b") { return $true }
    if ($Task -match "(?i)(?:^|[\s\[])class:(feature|design|copy)\b") { return $true }
    return $false
}

function Test-TaskHasSurface {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    return ($Task -match "(?i)(?:^|[\s\[])surface:(public|app|internal|mixed)\b")
}

function Get-TaskSurfaceCount {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return 0 }
    return @([regex]::Matches($Task, "(?i)(?:^|[\s\[])surface:(public|app|internal|mixed)\b")).Count
}

function Test-TaskHasOneSurface {
    param([string]$Task)

    return ((Get-TaskSurfaceCount -Task $Task) -eq 1)
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

function Test-IsUiOrProductShip {
    param([object]$Ship)

    $profile = [string](Get-ConfigPropertyValue -Object $Ship -Name "profile")
    $projectType = [string](Get-ConfigPropertyValue -Object $Ship -Name "projectType")
    $visualPaths = @(Get-ConfigPropertyValue -Object $Ship -Name "visualPaths" | ForEach-Object { $_ })

    if ($profile -in @("frontend-static-demo", "real-product", "experimental-prototype")) { return $true }
    if ($projectType -in @("marketing-site", "full-stack-web", "desktop-app", "mobile-app", "game", "sandbox-prototype", "ai-workflow")) { return $true }
    if ($visualPaths.Count -gt 0) { return $true }
    return $false
}

function Test-HasInformationStaging {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\INFORMATION_STAGING.md"
    if (!(Test-Path -LiteralPath $path)) { return $false }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($label in @("Surface Split", "First Screen Contract", "Progressive Disclosure Rules")) {
        if ($text -notmatch [regex]::Escape($label)) { return $false }
    }
    return $true
}

function Get-InformationStagingMissingFields {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\INFORMATION_STAGING.md"
    $missing = [System.Collections.Generic.List[string]]::new()
    if (!(Test-Path -LiteralPath $path)) {
        foreach ($label in @("First screen job", "Primary content", "Secondary actions", "Detail content", "Not visible at first", "How deeper information opens")) {
            $missing.Add($label) | Out-Null
        }
        return @($missing)
    }

    $text = Get-Content -LiteralPath $path -Raw
    foreach ($label in @("First screen job", "Primary content", "Secondary actions", "Detail content", "Not visible at first", "How deeper information opens")) {
        $match = [regex]::Match($text, "(?im)^\s*$([regex]::Escape($label)):\s*(.+?)\s*$")
        if (!$match.Success -or [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) {
            $missing.Add($label) | Out-Null
            continue
        }

        $value = $match.Groups[1].Value.Trim()
        if (Test-IsPlaceholderText -Value $value) {
            $missing.Add($label) | Out-Null
        }
    }

    return @($missing)
}

function Test-HasOperatingMode {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\OPERATING_MODE.md"
    if (!(Test-Path -LiteralPath $path)) { return $false }
    $text = Get-Content -LiteralPath $path -Raw
    return ($text -match "(?im)^Mode:\s*(hospitality-studio|formula-lab|software-engineering|demo-forge)\s*$" -and
        $text -match "(?m)^## Planning Rules\s*$" -and
        $text -match "(?m)^## First Screen Contract\s*$" -and
        $text -match "(?m)^## Required Gates\s*$")
}

function Get-OperatingModeValue {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\OPERATING_MODE.md"
    if (!(Test-Path -LiteralPath $path)) { return "" }
    $text = Get-Content -LiteralPath $path -Raw
    $match = [regex]::Match($text, "(?im)^Mode:\s*(hospitality-studio|formula-lab|software-engineering|demo-forge)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Test-HasReferenceBrief {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\REFERENCE_BRIEF.md"
    if (!(Test-Path -LiteralPath $path)) {
        $path = Join-Path $RepoPath "docs\codex\CREATIVE_BRIEF.md"
    }
    if (!(Test-Path -LiteralPath $path)) { return $false }
    $text = Get-Content -LiteralPath $path -Raw
    return ($text -match "(?m)^## Surface Type\s*$" -and
        $text -match "(?m)^## Reference Qualities\s*$" -and
        $text -match "(?m)^## First Screen Rules\s*$" -and
        $text -match "(?m)^## Forbidden Patterns\s*$" -and
        $text -match "(?i)Do not copy" -and
        $text -match "(?i)under 30 seconds")
}

function Test-IsPlaceholderText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value -match "(?i)\b(todo|tbd|unknown|fill this|to be decided|not decided|placeholder|lorem ipsum)\b" -or $Value.Trim() -match "(?i)^(n/a|none)\.?$")
}

function Test-TaskHasFirstScreenField {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    $match = [regex]::Match($Task, "(?i)\bfirst[- ]screen(?:\s+job)?\s*:\s*([^.\[\r\n]+)")
    if (!$match.Success) { return $false }
    return !(Test-IsPlaceholderText -Value $match.Groups[1].Value)
}

function Test-TaskHasSkillWorkflow {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    return ($Task -match "(?i)\b(?:Skill|Workflow)\s*:\s*[^.;\[\r\n]+")
}

function Test-TaskHasProof {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    return ($Task -match "(?i)\bProof\s*:\s*[^.;\[\r\n]+")
}

function Test-TaskHasStopIf {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    return ($Task -match "(?i)\bStop\s+if\s*:\s*[^.;\[\r\n]+")
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
    $requestedUsefulnessPhase = Get-UsefulnessRequestedPhase -Decision $usefulnessDecision
    if ($LoopPhase -ne "auto" -and $LoopPhase -ne $requestedUsefulnessPhase) {
        Add-Issue -Severity "WARN" -Message "Product usefulness asks for $usefulnessDecision; launch should use loop phase $requestedUsefulnessPhase."
    }
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
    $hasAnyV2Field = ((Test-TaskHasSkillWorkflow -Task $task) -or (Test-TaskHasProof -Task $task) -or (Test-TaskHasStopIf -Task $task))
    if ($hasAnyV2Field) {
        if (!(Test-TaskHasSkillWorkflow -Task $task)) {
            Add-Issue -Severity "BLOCK" -Message "Task Contract V2 task is missing Skill/Workflow."
        }
        if (!(Test-TaskHasProof -Task $task)) {
            Add-Issue -Severity "BLOCK" -Message "Task Contract V2 task is missing Proof."
        }
        if (!(Test-TaskHasStopIf -Task $task)) {
            Add-Issue -Severity "BLOCK" -Message "Task Contract V2 task is missing Stop if."
        }
    } else {
        Add-Issue -Severity "WARN" -Message "First unchecked task is legacy format; future generated tasks should use Skill, Proof, and Stop if."
    }
    if ((Test-IsUiOrProductShip -Ship $ship) -and (Test-TaskRequiresSurface -Task $task)) {
        $surfaceCount = Get-TaskSurfaceCount -Task $task
        if ($surfaceCount -eq 0) {
            Add-Issue -Severity "BLOCK" -Message "First unchecked visible/product task is missing surface metadata: surface:public, surface:app, surface:internal, or surface:mixed."
        } elseif ($surfaceCount -gt 1) {
            Add-Issue -Severity "BLOCK" -Message "First unchecked visible/product task has multiple surface metadata values; choose exactly one of surface:public, surface:app, surface:internal, or surface:mixed."
        }
        if (!(Test-TaskHasFirstScreenField -Task $task)) {
            Add-Issue -Severity "BLOCK" -Message "First unchecked visible/product task is missing first-screen metadata. Add 'First screen: ...' so Nami knows what must stay dominant."
        }
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

if ((Test-IsUiOrProductShip -Ship $ship) -and !(Test-HasInformationStaging -RepoPath $repoPath)) {
    Add-Issue -Severity "BLOCK" -Message "UI/product ship is missing docs/codex/INFORMATION_STAGING.md with surface split and first-screen contract."
} elseif (Test-IsUiOrProductShip -Ship $ship) {
    $missingStagingFields = @(Get-InformationStagingMissingFields -RepoPath $repoPath)
    if ($missingStagingFields.Count -gt 0) {
        Add-Issue -Severity "BLOCK" -Message "INFORMATION_STAGING.md has incomplete first-screen contract fields: $($missingStagingFields -join ', ')."
    }
}

if (!(Test-HasOperatingMode -RepoPath $repoPath)) {
    Add-Issue -Severity "WARN" -Message "Ship is missing docs/codex/OPERATING_MODE.md; long runs should write an operating mode before launch."
}

$operatingModeValue = Get-OperatingModeValue -RepoPath $repoPath
if ($operatingModeValue -eq "hospitality-studio" -and !(Test-HasReferenceBrief -RepoPath $repoPath)) {
    Add-Issue -Severity "WARN" -Message "Hospitality Studio ship is missing docs/codex/REFERENCE_BRIEF.md; showpiece runs should define creative references before implementation."
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
