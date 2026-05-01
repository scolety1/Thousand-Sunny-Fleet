[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [Alias("OutFile")]
    [string]$OutMarkdown = "out\fleet-product-dashboard.md",

    [string]$OutHtml = "out\fleet-product-dashboard.html",

    [switch]$NoHtml
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

function Get-LineValue {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = "(?im)^\s*$([regex]::Escape($Label))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-DecisionFromText {
    param([string]$Text)

    $match = [regex]::Match($Text, "(?im)^\s*Decision:\s*(ADMIT|REVISE|PARK|CONTINUE|REPAIR|SIMPLIFY|NEEDS HUMAN DIRECTION|READY|WARN|BLOCK)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().ToUpperInvariant() }
    $gateMatch = [regex]::Match($Text, "(?im)^Launch gate\s+[A-Za-z0-9_.-]+:\s+(READY|WARN|BLOCK)\b")
    if ($gateMatch.Success) { return $gateMatch.Groups[1].Value.Trim().ToUpperInvariant() }
    $lineMatch = [regex]::Match($Text, "(?im)^[A-Za-z0-9_-]+:\s+(ADMIT|REVISE|PARK|CONTINUE|REPAIR|SIMPLIFY|NEEDS HUMAN DIRECTION|READY|WARN|BLOCK)\b")
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim().ToUpperInvariant() }
    return "UNKNOWN"
}

function Get-FirstMeaningfulLine {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return "missing" }
    foreach ($line in ($Value -split "\r?\n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match "^(TODO|TBD|N/A|What can|What changed|What still|Specific improvement)") { continue }
        return $trimmed.Replace("|", "/")
    }
    return "missing"
}

function Get-ScoreValue {
    param([string]$ReviewText)

    $match = [regex]::Match($ReviewText, "(?im)^Score:\s*([0-9]+)\s*/\s*([0-9]+)\s*$")
    if ($match.Success) { return "$($match.Groups[1].Value)/$($match.Groups[2].Value)" }
    $lineMatch = [regex]::Match($ReviewText, "(?im)^[A-Za-z0-9_.-]+:\s+(?:ADMIT|REVISE|PARK)\s+\(([0-9]+)\s*/\s*([0-9]+)\)")
    if ($lineMatch.Success) { return "$($lineMatch.Groups[1].Value)/$($lineMatch.Groups[2].Value)" }
    return "missing"
}

function Get-MarkdownValue {
    param(
        [string]$RepoPath,
        [string]$RelativePath,
        [string]$Heading
    )

    $path = Join-Path $RepoPath $RelativePath
    if (!(Test-Path -LiteralPath $path)) { return "missing" }
    $text = Get-Content -LiteralPath $path -Raw
    $section = Get-SectionText -Text $text -Heading $Heading
    return Get-FirstMeaningfulLine -Value $section
}

function Get-CurrentPhase {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\PHASE_STATE.md"
    if (!(Test-Path -LiteralPath $path)) { return "missing" }
    $text = Get-Content -LiteralPath $path -Raw
    $match = [regex]::Match($text, "(?im)^Current Phase:\s*([a-z-]+)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return "unknown"
}

function Get-VisualSummary {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\VISUAL_BUGS.md"
    if (!(Test-Path -LiteralPath $path)) { return "missing" }
    $high = @(Select-String -Path $path -Pattern "\[HIGH\]" -ErrorAction SilentlyContinue).Count
    $medium = @(Select-String -Path $path -Pattern "\[MEDIUM\]" -ErrorAction SilentlyContinue).Count
    $low = @(Select-String -Path $path -Pattern "\[LOW\]" -ErrorAction SilentlyContinue).Count
    return "H$high/M$medium/L$low"
}

function Get-UncheckedCount {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) { return 0 }
    return @(Select-String -Path $path -Pattern "^\s*-\s+\[ \]\s+" -ErrorAction SilentlyContinue).Count
}

function Get-FirstUncheckedTask {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) { return "missing" }
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match "^\s*-\s+\[ \]\s+(.+)$") {
            return $matches[1].Trim().Replace("|", "/")
        }
    }
    return "none"
}

function Test-PlaceholderText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value.Trim() -match "^(TODO|TBD|N/A|none|missing|\.\.\.)$" -or $Value -match "\.\.\.")
}

function Test-UiOrProductTask {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task) -or $Task -eq "missing" -or $Task -eq "none") { return $false }
    return ($Task -match "(?i)\bclass:(feature|design|copy)\b" -or $Task -match "(?i)\bimpact:(visible|showpiece)\b")
}

function Get-TaskSurfaceCount {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return 0 }
    return @([regex]::Matches($Task, "(?i)(?:^|[\s\[])surface:(public|app|internal|mixed)\b")).Count
}

function Get-TaskFirstScreenValue {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return "" }
    $match = [regex]::Match($Task, "(?i)\bFirst screen:\s*(.+?)(?=\s+Remove/simplify:|\s+Guardrails:|\s+Acceptance:|\s+Check:|\s+\[[^\]]+\]|\s*$)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-TaskStagingMetadataStatus {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task) -or $Task -eq "missing" -or $Task -eq "none") { return "no task" }
    if (!(Test-UiOrProductTask -Task $Task)) { return "task not staged" }

    $surfaceCount = Get-TaskSurfaceCount -Task $Task
    if ($surfaceCount -eq 0) { return "task missing surface" }
    if ($surfaceCount -gt 1) { return "task multiple surfaces" }

    $firstScreen = Get-TaskFirstScreenValue -Task $Task
    if (Test-PlaceholderText -Value $firstScreen) { return "task missing first screen" }

    return "task staged"
}

function Get-InformationStagingStatus {
    param(
        [string]$RepoPath,
        [string]$FirstTask
    )

    $path = Join-Path $RepoPath "docs\codex\INFORMATION_STAGING.md"
    if (!(Test-Path -LiteralPath $path)) { return "missing doc" }
    $text = Get-Content -LiteralPath $path -Raw

    $missingSections = @()
    foreach ($heading in @("Surface Split", "First Screen Contract", "Progressive Disclosure Rules")) {
        if ([string]::IsNullOrWhiteSpace((Get-SectionText -Text $text -Heading $heading))) {
            $missingSections += $heading
        }
    }
    if ($missingSections.Count -gt 0) { return "doc missing: $($missingSections[0])" }

    $missingFields = @()
    foreach ($label in @("First screen job", "Primary content", "Secondary actions", "Detail content", "Not visible at first", "How deeper information opens")) {
        $value = Get-LineValue -Text $text -Label $label
        if (Test-PlaceholderText -Value $value) { $missingFields += $label }
    }
    if ($missingFields.Count -gt 0) { return "doc incomplete: $($missingFields[0])" }

    $taskStatus = Get-TaskStagingMetadataStatus -Task $FirstTask
    if ($taskStatus -eq "task staged") { return "ready" }
    if ($taskStatus -eq "task not staged" -or $taskStatus -eq "no task") { return "doc ready" }
    return $taskStatus
}

function Test-StagingNeedsAttention {
    param([string]$StagingDecision)

    if ([string]::IsNullOrWhiteSpace($StagingDecision)) { return $true }
    return ($StagingDecision -match "^(missing|doc missing|doc incomplete|task missing|task multiple)")
}

function Get-StagingAction {
    param([string]$StagingDecision)

    if (Test-StagingNeedsAttention -StagingDecision $StagingDecision) { return "fix staging contract" }
    return "no staging action"
}

function Get-GitValue {
    param(
        [string]$RepoPath,
        [string[]]$Arguments
    )

    $output = & git -C $RepoPath @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return "unknown" }
    return (($output | Select-Object -First 1) -join "").Trim()
}

function Get-GitDirtyState {
    param([string]$RepoPath)

    $status = @(& git -C $RepoPath status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) { return "unknown" }
    if ($status.Count -eq 0) { return "clean" }
    return "dirty $($status.Count)"
}

function Get-RunLockState {
    param([string]$ProjectName)

    $path = Join-Path $fleetRoot ".codex-local\locks\$ProjectName.lock.json"
    if (!(Test-Path -LiteralPath $path)) { return "none" }
    try {
        $lock = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $pidValue = [int]$lock.pid
        $proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if ($proc) { return "active PID $pidValue" }
        return "stale PID $pidValue"
    } catch {
        return "present"
    }
}

function Get-NextAction {
    param(
        [string]$LaunchDecision,
        [string]$AdmissionDecision,
        [string]$UsefulnessDecision,
        [string]$StagingDecision,
        [int]$UncheckedTasks,
        [string]$Dirty,
        [string]$Lock
    )

    if ($Lock -match "^active") { return "leave running" }
    if ($Dirty -match "^dirty") { return "inspect before launch" }
    if (Test-StagingNeedsAttention -StagingDecision $StagingDecision) { return "fix staging contract" }
    if ($LaunchDecision -eq "BLOCK") { return "fill docs or park before launch" }
    if ($AdmissionDecision -eq "PARK" -or $UsefulnessDecision -eq "PARK") { return "park" }
    if ($UsefulnessDecision -eq "NEEDS HUMAN DIRECTION") { return "needs direction" }
    if ($UsefulnessDecision -eq "REPAIR") { return "repair-first run" }
    if ($UsefulnessDecision -eq "SIMPLIFY") { return "simplicity run" }
    if ($UncheckedTasks -gt 0 -and $LaunchDecision -in @("READY", "WARN")) { return "eligible to launch" }
    if ($UncheckedTasks -eq 0) { return "park or generate tasks" }
    return "review"
}

function ConvertTo-HtmlEncoded {
    param([string]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Resolve-FleetOutputPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $fleetRoot $Path
}

Set-Location $fleetRoot
$projects = Get-Projects -Path $ConfigPath
if ($projects.Count -eq 0) { Stop-WithMessage "No projects found." }

$rows = @()
foreach ($project in $projects) {
    $name = [string]$project.name
    $repo = Resolve-Path ([string]$project.repo) -ErrorAction SilentlyContinue
    if (!$repo) {
        $rows += [pscustomobject]@{
            Ship = $name; Group = [string]$project.fleetGroup; Repo = [string]$project.repo; Branch = "missing"; Head = "missing"; Dirty = "missing"; Lock = "unknown"; Admission = "PARK"; Score = "0/100"; Usefulness = "PARK"; Launch = "BLOCK"; Staging = "missing repo"; Phase = "missing"; Tasks = 0; Visual = "missing"; Checkpoint = "missing"; LastUsefulChange = "repo missing"; NextTask = "none"; NextAction = "repair repo path"
        }
        continue
    }

    $repoPath = $repo.Path
    $admissionOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "ship-admission.ps1") -Project $name -Config $ConfigPath -NoWrite 2>&1
    $admissionText = ($admissionOutput | Out-String)
    $admissionDecision = Get-DecisionFromText -Text $admissionText
    $admissionScore = Get-ScoreValue -ReviewText $admissionText

    $usefulnessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "product-usefulness.ps1") -Project $name -Config $ConfigPath -NoWrite 2>&1
    $usefulnessText = ($usefulnessOutput | Out-String)
    $usefulnessDecision = Get-DecisionFromText -Text $usefulnessText

    $gateOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-launch-gate.ps1") -Project $name -ConfigPath $ConfigPath -Mode warn 2>&1
    $gateText = ($gateOutput | Out-String)
    $launchDecision = Get-DecisionFromText -Text $gateText

        $unchecked = Get-UncheckedCount -RepoPath $repoPath
        $dirty = Get-GitDirtyState -RepoPath $repoPath
        $lock = Get-RunLockState -ProjectName $name
        $lastUsefulChange = Get-MarkdownValue -RepoPath $repoPath -RelativePath "docs\codex\PRODUCT_USEFULNESS.md" -Heading "Last Useful Change"
        $nextTask = Get-FirstUncheckedTask -RepoPath $repoPath
        $staging = Get-InformationStagingStatus -RepoPath $repoPath -FirstTask $nextTask
        $checkpoint = Get-MarkdownValue -RepoPath $repoPath -RelativePath "docs\codex\CHECKPOINT_REVIEW.md" -Heading "Verdict"

        $rows += [pscustomobject]@{
        Ship = $name
        Group = if ([string]::IsNullOrWhiteSpace([string]$project.fleetGroup)) { "-" } else { [string]$project.fleetGroup }
        Repo = $repoPath
        Branch = Get-GitValue -RepoPath $repoPath -Arguments @("branch", "--show-current")
        Head = Get-GitValue -RepoPath $repoPath -Arguments @("rev-parse", "--short", "HEAD")
        Dirty = $dirty
        Lock = $lock
        Admission = $admissionDecision
        Score = $admissionScore
        Usefulness = $usefulnessDecision
        Launch = $launchDecision
        Staging = $staging
        Phase = Get-CurrentPhase -RepoPath $repoPath
        Tasks = $unchecked
        Visual = Get-VisualSummary -RepoPath $repoPath
        Checkpoint = $checkpoint
        LastUsefulChange = $lastUsefulChange
        NextTask = $nextTask
        NextAction = Get-NextAction -LaunchDecision $launchDecision -AdmissionDecision $admissionDecision -UsefulnessDecision $usefulnessDecision -StagingDecision $staging -UncheckedTasks $unchecked -Dirty $dirty -Lock $lock
    }
}

$outMarkdownPath = Resolve-FleetOutputPath -Path $OutMarkdown
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outMarkdownPath) | Out-Null

$md = @(
    "# Fleet Product Dashboard",
    "",
    "Generated: $(Get-Date -Format o)",
    "",
    "| Ship | Group | Launch | Admission | Score | Usefulness | Staging | Phase | Tasks | Visual | Checkpoint | Dirty | Lock | Next Action |",
    "| --- | --- | --- | --- | ---: | --- | --- | --- | ---: | --- | --- | --- | --- | --- |"
)
foreach ($row in $rows) {
    $md += "| $($row.Ship) | $($row.Group) | $($row.Launch) | $($row.Admission) | $($row.Score) | $($row.Usefulness) | $($row.Staging) | $($row.Phase) | $($row.Tasks) | $($row.Visual) | $($row.Checkpoint) | $($row.Dirty) | $($row.Lock) | $($row.NextAction) |"
}

$md += ""
$md += "## Staging Attention"
$md += ""
$stagingAttention = @($rows | Where-Object { Test-StagingNeedsAttention -StagingDecision ([string]$_.Staging) })
if ($stagingAttention.Count -eq 0) {
    $md += "No staging contract blockers detected."
} else {
    foreach ($row in $stagingAttention) {
        $md += "- $($row.Ship): $($row.Staging) -> $(Get-StagingAction -StagingDecision ([string]$row.Staging))"
    }
}

$md += ""
$md += "## Details"
$md += ""
foreach ($row in $rows) {
    $md += "### $($row.Ship)"
    $md += ""
    $md += "- Repo: $($row.Repo)"
    $md += "- Branch: $($row.Branch) @ $($row.Head)"
    $md += "- Last useful change: $($row.LastUsefulChange)"
    $md += "- Next task: $($row.NextTask)"
    $md += ""
}

Set-Content -LiteralPath $outMarkdownPath -Value ($md -join "`n")

if (!$NoHtml) {
    $outHtmlPath = Resolve-FleetOutputPath -Path $OutHtml
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outHtmlPath) | Out-Null
    $htmlRows = foreach ($row in $rows) {
        $stateClass = switch ($row.Launch) {
            "READY" { "ready" }
            "WARN" { "warn" }
            "BLOCK" { "block" }
            default { "unknown" }
        }
        "<tr class='$stateClass'><td>$((ConvertTo-HtmlEncoded $row.Ship))</td><td>$((ConvertTo-HtmlEncoded $row.Group))</td><td>$((ConvertTo-HtmlEncoded $row.Launch))</td><td>$((ConvertTo-HtmlEncoded $row.Admission))</td><td>$((ConvertTo-HtmlEncoded $row.Score))</td><td>$((ConvertTo-HtmlEncoded $row.Usefulness))</td><td>$((ConvertTo-HtmlEncoded $row.Staging))</td><td>$((ConvertTo-HtmlEncoded $row.Phase))</td><td>$($row.Tasks)</td><td>$((ConvertTo-HtmlEncoded $row.Visual))</td><td>$((ConvertTo-HtmlEncoded $row.Dirty))</td><td>$((ConvertTo-HtmlEncoded $row.Lock))</td><td>$((ConvertTo-HtmlEncoded $row.NextAction))</td></tr>"
    }
    $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fleet Product Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 32px; color: #17202a; background: #f7f8f8; }
    h1 { margin-bottom: 4px; }
    .meta { color: #53616a; margin-bottom: 24px; }
    table { width: 100%; border-collapse: collapse; background: white; box-shadow: 0 12px 32px rgba(0,0,0,.08); }
    th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid #e3e7ea; vertical-align: top; }
    th { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: #4d5b65; background: #eef2f4; }
    tr.ready td:first-child { border-left: 6px solid #2e8b57; }
    tr.warn td:first-child { border-left: 6px solid #c99522; }
    tr.block td:first-child { border-left: 6px solid #c4483f; }
    tr.unknown td:first-child { border-left: 6px solid #8b949e; }
  </style>
</head>
<body>
  <h1>Fleet Product Dashboard</h1>
  <div class="meta">Generated $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") from local fleet state.</div>
  <table>
    <thead>
      <tr><th>Ship</th><th>Group</th><th>Launch</th><th>Admission</th><th>Score</th><th>Usefulness</th><th>Staging</th><th>Phase</th><th>Tasks</th><th>Visual</th><th>Dirty</th><th>Lock</th><th>Next Action</th></tr>
    </thead>
    <tbody>
      $($htmlRows -join "`n      ")
    </tbody>
  </table>
</body>
</html>
"@
    Set-Content -LiteralPath $outHtmlPath -Value $html
}

Write-Host "Fleet product dashboard written:" -ForegroundColor Green
Write-Host "  $outMarkdownPath"
if (!$NoHtml) { Write-Host "  $(Join-Path $fleetRoot $OutHtml)" }

exit 0
