[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [int]$FlatRunThreshold = 3,

    [ValidateSet("warn", "enforce")]
    [string]$Mode = "warn",

    [string]$OutDir = "out\kill-switches",

    [switch]$WriteParkingReason
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

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

function Get-DecisionFromText {
    param([string]$Text)
    $match = [regex]::Match($Text, "(?im)^\s*Decision:\s*(READY|WARN|BLOCK|CONTINUE|REPAIR|SIMPLIFY|PARK|NEEDS HUMAN DIRECTION)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().ToUpperInvariant() }
    $gateMatch = [regex]::Match($Text, "(?im)^Launch gate\s+[A-Za-z0-9_.-]+:\s+(READY|WARN|BLOCK)\b")
    if ($gateMatch.Success) { return $gateMatch.Groups[1].Value.Trim().ToUpperInvariant() }
    $lineMatch = [regex]::Match($Text, "(?im)^[A-Za-z0-9_.-]+:\s+(CONTINUE|REPAIR|SIMPLIFY|PARK|NEEDS HUMAN DIRECTION)\b")
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim().ToUpperInvariant() }
    return "UNKNOWN"
}

function Get-RecentSimonSignals {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\MAGIC_SCORECARD.md"
    if (!(Test-Path -LiteralPath $path)) {
        return @()
    }

    $text = Get-Content -LiteralPath $path -Raw
    $matches = [regex]::Matches($text, "(?im)Simon improvement score:\s*SCORE:\s*(\d+);\s*DIRECTION:\s*([^;`\r`\n]+)")
    $signals = @()
    foreach ($match in $matches) {
        $signals += [pscustomobject]@{
            Score = [int]$match.Groups[1].Value
            Direction = $match.Groups[2].Value.Trim().ToLowerInvariant()
        }
    }
    return @($signals)
}

function Get-ConsecutiveWeakSignalCount {
    param([object[]]$Signals)

    $count = 0
    for ($i = $Signals.Count - 1; $i -ge 0; $i--) {
        $signal = $Signals[$i]
        if ($signal.Direction -in @("flat", "regressed", "weaker") -or [int]$signal.Score -lt 4) {
            $count++
        } else {
            break
        }
    }
    return $count
}

function Get-QualityQuarantineCount {
    param([string]$RepoPath)
    $path = Join-Path $RepoPath "docs\codex\QUALITY_QUARANTINE.md"
    if (!(Test-Path -LiteralPath $path)) { return 0 }
    return @(Select-String -Path $path -Pattern "(?i)^##\s+|quality quarantine|flat|regressed|weak|looping" -ErrorAction SilentlyContinue).Count
}

function Get-UncheckedCount {
    param([string]$RepoPath)
    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) { return 0 }
    return @(Select-String -Path $path -Pattern "^\s*-\s+\[ \]\s+" -ErrorAction SilentlyContinue).Count
}

Set-Location $fleetRoot
if ($FlatRunThreshold -lt 1) { Stop-WithMessage "-FlatRunThreshold must be at least 1." }

$ship = @(Get-Projects -Path $ConfigPath | Where-Object { [string]$_.name -ceq [string]$Project })
if ($ship.Count -ne 1) { Stop-WithMessage "Project not found or ambiguous: $Project" }
$ship = $ship[0]
$repo = Resolve-Path ([string]$ship.repo) -ErrorAction SilentlyContinue
if (!$repo) { Stop-WithMessage "Repo not found: $($ship.repo)" }
$repoPath = $repo.Path

$usefulnessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "product-usefulness.ps1") -Project $Project -Config $ConfigPath -NoWrite 2>&1
$usefulnessText = ($usefulnessOutput | Out-String)
$usefulnessDecision = Get-DecisionFromText -Text $usefulnessText

$launchOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-launch-gate.ps1") -Project $Project -ConfigPath $ConfigPath -Mode warn 2>&1
$launchText = ($launchOutput | Out-String)
$launchDecision = Get-DecisionFromText -Text $launchText

$signals = @(Get-RecentSimonSignals -RepoPath $repoPath)
$weakCount = Get-ConsecutiveWeakSignalCount -Signals $signals
$quarantineCount = Get-QualityQuarantineCount -RepoPath $repoPath
$unchecked = Get-UncheckedCount -RepoPath $repoPath

$issues = [System.Collections.Generic.List[string]]::new()
$decision = "CONTINUE"

if ($usefulnessDecision -in @("PARK", "NEEDS HUMAN DIRECTION")) {
    $decision = "KILL"
    $issues.Add("Product usefulness is $usefulnessDecision.") | Out-Null
}
if ($launchDecision -eq "BLOCK") {
    $decision = "KILL"
    $issues.Add("Launch gate is BLOCK.") | Out-Null
}
if ($weakCount -ge $FlatRunThreshold) {
    $decision = "KILL"
    $issues.Add("$weakCount consecutive weak/flat Simon scorecard signals reached threshold $FlatRunThreshold.") | Out-Null
}
if ($quarantineCount -ge $FlatRunThreshold) {
    $decision = "KILL"
    $issues.Add("Quality quarantine signal count $quarantineCount reached threshold $FlatRunThreshold.") | Out-Null
}
if ($unchecked -eq 0 -and $usefulnessDecision -notin @("CONTINUE", "REPAIR", "SIMPLIFY")) {
    $decision = "KILL"
    $issues.Add("No unchecked tasks and usefulness gate is not ready to continue.") | Out-Null
}

if ($decision -ne "KILL" -and ($usefulnessDecision -in @("REPAIR", "SIMPLIFY") -or $launchDecision -eq "WARN" -or $weakCount -gt 0)) {
    $decision = "WATCH"
    if ($usefulnessDecision -in @("REPAIR", "SIMPLIFY")) { $issues.Add("Usefulness asks for $usefulnessDecision.") | Out-Null }
    if ($launchDecision -eq "WARN") { $issues.Add("Launch gate is WARN.") | Out-Null }
    if ($weakCount -gt 0) { $issues.Add("$weakCount recent weak/flat Simon signal(s), below threshold.") | Out-Null }
}

$outRoot = Join-Path $fleetRoot $OutDir
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$safeName = ([string]$Project) -replace "[^A-Za-z0-9_.-]+", "-"
$outPath = Join-Path $outRoot "$safeName.md"

$lines = @(
    "# Fleet Kill Switch",
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
    "Usefulness decision: $usefulnessDecision",
    "",
    "Launch decision: $launchDecision",
    "",
    "Unchecked tasks: $unchecked",
    "",
    "Consecutive weak Simon signals: $weakCount / $FlatRunThreshold",
    "",
    "Quality quarantine signals: $quarantineCount / $FlatRunThreshold",
    "",
    "## Issues",
    ""
)
if ($issues.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($issue in $issues) { $lines += "- $issue" }
}
$lines += ""
$lines += "## Next Action"
$lines += ""
switch ($decision) {
    "KILL" { $lines += "- Park this ship or ask for human direction before another unattended loop." }
    "WATCH" { $lines += "- Allow only a bounded repair/simplify batch, then recheck." }
    default { $lines += "- Continue under normal launch gates." }
}

Set-Content -LiteralPath $outPath -Value ($lines -join "`n")

if ($WriteParkingReason -and $decision -eq "KILL") {
    $parkingPath = Join-Path $repoPath "docs\codex\PARKING_REASON.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $parkingPath) | Out-Null
    Set-Content -LiteralPath $parkingPath -Value ($lines -join "`n")
}

$color = switch ($decision) {
    "CONTINUE" { "Green" }
    "WATCH" { "Yellow" }
    "KILL" { "Red" }
    default { "White" }
}
Write-Host "Kill switch ${Project}: $decision" -ForegroundColor $color
Write-Host "Report: $outPath" -ForegroundColor DarkCyan
foreach ($issue in $issues) { Write-Host "  - $issue" }

if ($Mode -eq "enforce" -and $decision -eq "KILL") {
    exit 1
}

exit 0

