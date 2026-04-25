[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$OutFile = "out\visual-gallery.html",

    [int]$RunsPerProject = 3
)

$ErrorActionPreference = "Continue"

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

function Html {
    param([object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function To-FileUrl {
    param([string]$Path)
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) {
        return ""
    }
    return ([System.Uri]$resolved.Path).AbsoluteUri
}

function Get-Summary {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

if ($RunsPerProject -lt 1) {
    $RunsPerProject = 1
}

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
    if ($projects.Count -ne 1) {
        Write-Host "Project not found: $Project" -ForegroundColor Red
        exit 1
    }
}

$cards = @()
foreach ($projectConfig in $projects) {
    $repoMatches = @(Resolve-Path $projectConfig.repo -ErrorAction SilentlyContinue)
    if ($repoMatches.Count -ne 1) {
        $cards += [pscustomobject]@{
            project = $projectConfig.name
            missing = $true
            message = "Repo missing: $($projectConfig.repo)"
        }
        continue
    }

    $repoPath = $repoMatches[0].Path
    $logRoot = Join-Path $repoPath ".codex-logs"
    $runs = @(Get-ChildItem $logRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^visual(-inspect)?-" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $RunsPerProject)

    if ($runs.Count -eq 0) {
        $cards += [pscustomobject]@{
            project = $projectConfig.name
            missing = $true
            message = "No visual runs found under $logRoot"
        }
        continue
    }

    foreach ($run in $runs) {
        $summary = Get-Summary -Path (Join-Path $run.FullName "visual-inspect-summary.json")
        $pngs = @(Get-ChildItem $run.FullName -Filter "*.png" -File -ErrorAction SilentlyContinue | Sort-Object Name)
        $findings = if ($summary -and $summary.findings) { @($summary.findings).Count } else { 0 }
        $passed = if ($summary) { [string]$summary.passed } else { "unknown" }
        $routes = if ($summary -and $summary.routes) { (@($summary.routes) -join ", ") } else { "unknown" }

        $cards += [pscustomobject]@{
            project = $projectConfig.name
            missing = $false
            runName = $run.Name
            runPath = $run.FullName
            lastWrite = $run.LastWriteTime
            passed = $passed
            findings = $findings
            routes = $routes
            screenshots = $pngs
        }
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Codex Fleet Visual Gallery</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #172126;
      --muted: #64727a;
      --line: #d8e0e3;
      --paper: #f7f8f6;
      --card: #ffffff;
      --accent: #173b57;
      --warn: #8a5a00;
      --bad: #9f1d20;
      --good: #1f6f43;
    }
    body {
      margin: 0;
      background: var(--paper);
      color: var(--ink);
      font-family: Segoe UI, Arial, sans-serif;
      line-height: 1.45;
    }
    header {
      padding: 28px clamp(18px, 4vw, 48px);
      background: #ffffff;
      border-bottom: 1px solid var(--line);
      position: sticky;
      top: 0;
      z-index: 1;
    }
    h1 {
      margin: 0;
      font-size: clamp(24px, 4vw, 40px);
    }
    header p {
      margin: 6px 0 0;
      color: var(--muted);
    }
    main {
      padding: 24px clamp(14px, 3vw, 36px) 48px;
    }
    .ship {
      margin: 0 0 28px;
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 10px;
      overflow: hidden;
    }
    .ship-head {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      padding: 16px 18px;
      border-bottom: 1px solid var(--line);
      align-items: center;
    }
    h2 {
      margin: 0;
      font-size: 20px;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
    }
    .badge {
      display: inline-block;
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 4px 9px;
      font-size: 12px;
      font-weight: 700;
      color: var(--accent);
      background: #f4f7f8;
    }
    .badge.bad { color: var(--bad); }
    .badge.warn { color: var(--warn); }
    .badge.good { color: var(--good); }
    .screens {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 16px;
      padding: 18px;
    }
    figure {
      margin: 0;
      border: 1px solid var(--line);
      background: #fbfcfc;
      border-radius: 8px;
      overflow: hidden;
    }
    figure img {
      display: block;
      width: 100%;
      height: auto;
      background: #eef2f3;
    }
    figcaption {
      padding: 10px 12px;
      color: var(--muted);
      font-size: 13px;
      word-break: break-word;
    }
    .empty {
      padding: 18px;
      color: var(--bad);
    }
  </style>
</head>
<body>
  <header>
    <h1>Codex Fleet Visual Gallery</h1>
    <p>Generated $timestamp. Latest visual smoke and visual inspection screenshots for morning review.</p>
  </header>
  <main>
"@

foreach ($card in $cards) {
    if ($card.missing) {
        $html += @"
    <section class="ship">
      <div class="ship-head">
        <div>
          <h2>$(Html $card.project)</h2>
          <div class="meta">No screenshots available</div>
        </div>
        <span class="badge bad">Missing</span>
      </div>
      <div class="empty">$(Html $card.message)</div>
    </section>
"@
        continue
    }

    $badgeClass = if ($card.passed -eq "True" -and $card.findings -eq 0) { "good" } elseif ($card.findings -gt 0) { "warn" } else { "" }
    $html += @"
    <section class="ship">
      <div class="ship-head">
        <div>
          <h2>$(Html $card.project)</h2>
          <div class="meta">$(Html $card.runName) | $(Html $card.lastWrite) | Routes: $(Html $card.routes)</div>
          <div class="meta">$(Html $card.runPath)</div>
        </div>
        <span class="badge $badgeClass">Passed: $(Html $card.passed) | Findings: $(Html $card.findings)</span>
      </div>
      <div class="screens">
"@

    foreach ($shot in $card.screenshots) {
        $fileUrl = To-FileUrl -Path $shot.FullName
        $html += @"
        <figure>
          <a href="$(Html $fileUrl)"><img src="$(Html $fileUrl)" alt="$(Html $shot.Name)"></a>
          <figcaption>$(Html $shot.Name)</figcaption>
        </figure>
"@
    }

    $html += @"
      </div>
    </section>
"@
}

$html += @"
  </main>
</body>
</html>
"@

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $html

Write-Host "Wrote visual gallery: $OutFile" -ForegroundColor Green
