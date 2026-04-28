[CmdletBinding()]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [int]$BasePort = 5301,

    [switch]$OpenEach,

    [switch]$NoOpen,

    [switch]$VisibleServers
)

$ErrorActionPreference = "Stop"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

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

function ConvertTo-StringArray {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    return @($Value | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
}

function Test-TcpPortOpen {
    param([int]$Port)

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (!$connect.AsyncWaitHandle.WaitOne(500, $false)) {
            return $false
        }
        $client.EndConnect($connect)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Wait-PreviewUrl {
    param(
        [string]$Url,
        [int]$Seconds = 20
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return $true
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    return $false
}

function Html {
    param([object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Start-ShipServer {
    param(
        [object]$Ship,
        [string]$ServePath,
        [int]$Port,
        [bool]$HasDevScript
    )

    $logRoot = Join-Path $fleetRoot "out\preview-logs"
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    $safeName = ([string]$Ship.name) -replace "[^a-zA-Z0-9_.-]+", "-"
    $stdoutLog = Join-Path $logRoot "$safeName.out.log"
    $stderrLog = Join-Path $logRoot "$safeName.err.log"

    if ($HasDevScript) {
        if ($VisibleServers) {
            $command = "Set-Location '$ServePath'; npm.cmd run dev -- --host 127.0.0.1 --port $Port"
            return Start-Process -FilePath "powershell" -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        }

        return Start-Process -FilePath "npm.cmd" `
            -ArgumentList @("run", "dev", "--", "--host", "127.0.0.1", "--port", "$Port") `
            -WorkingDirectory $ServePath `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError $stderrLog `
            -WindowStyle Hidden `
            -PassThru
    }

    $staticServer = Join-Path $fleetRoot "tools\static-preview-server.ps1"
    if ($VisibleServers) {
        return Start-Process -FilePath "powershell" -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $staticServer, "-Root", $ServePath, "-Port", "$Port") -PassThru
    }

    return Start-Process -FilePath "powershell" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $staticServer, "-Root", $ServePath, "-Port", "$Port") `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -WindowStyle Hidden `
        -PassThru
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
    if ($projects.Count -ne 1) {
        Write-Host "Project not found: $Project" -ForegroundColor Red
        exit 1
    }
}

$results = @()
$index = 0

foreach ($ship in $projects) {
    $repoPath = Resolve-Path -LiteralPath $ship.repo -ErrorAction SilentlyContinue
    if (!$repoPath) {
        $results += [pscustomobject]@{
            name = $ship.name
            status = "missing repo"
            url = ""
            pid = $null
            repo = $ship.repo
            servePath = ""
            routes = @()
        }
        continue
    }

    $serveDirectory = [string](Get-ConfigPropertyValue -Object $ship -Name "visualServeDirectory")
    if ([string]::IsNullOrWhiteSpace($serveDirectory)) {
        $serveDirectory = [string](Get-ConfigPropertyValue -Object $ship -Name "buildDirectory")
    }
    if ([string]::IsNullOrWhiteSpace($serveDirectory)) { $serveDirectory = "." }
    $servePathValue = Join-Path $repoPath.Path $serveDirectory
    $servePath = Resolve-Path -LiteralPath $servePathValue -ErrorAction SilentlyContinue
    if (!$servePath) {
        $results += [pscustomobject]@{
            name = $ship.name
            status = "missing serve path"
            url = ""
            pid = $null
            repo = $repoPath.Path
            servePath = $servePathValue
            routes = @()
        }
        continue
    }

    $previewPort = Get-ConfigPropertyValue -Object $ship -Name "previewPort"
    $port = if ($null -ne $previewPort -and [int]$previewPort -gt 0) { [int]$previewPort } else { $BasePort + $index }
    $index++
    $previewHost = [string](Get-ConfigPropertyValue -Object $ship -Name "previewHost")
    if ([string]::IsNullOrWhiteSpace($previewHost)) { $previewHost = "127.0.0.1" }
    $rootUrl = "http://$previewHost`:$port/"
    $process = $null
    $status = "existing"

    if (!(Test-TcpPortOpen -Port $port)) {
        $packagePath = Join-Path $servePath.Path "package.json"
        $hasDevScript = $false
        if (Test-Path -LiteralPath $packagePath) {
            try {
                $package = Get-Content $packagePath -Raw | ConvertFrom-Json
                $hasDevScript = $null -ne $package.scripts.PSObject.Properties["dev"]
            } catch {
                $hasDevScript = $false
            }
        }

        $hasIndex = Test-Path -LiteralPath (Join-Path $servePath.Path "index.html")
        $hasStaticHtml = $null -ne (Get-ChildItem -LiteralPath $servePath.Path -Filter "*.html" -File -ErrorAction SilentlyContinue | Select-Object -First 1)

        if (!$hasDevScript -and !$hasIndex -and !$hasStaticHtml) {
            $status = "no dev script or index.html"
        } else {
            $process = Start-ShipServer -Ship $ship -ServePath $servePath.Path -Port $port -HasDevScript $hasDevScript
            $status = if (Wait-PreviewUrl -Url $rootUrl) { "started" } else { "started but not ready" }
        }
    }

    $routes = @(ConvertTo-StringArray -Value (Get-ConfigPropertyValue -Object $ship -Name "visualPaths"))
    if ($routes.Count -eq 0) { $routes = @("/") }

    $results += [pscustomobject]@{
        name = $ship.name
        status = $status
        url = $rootUrl
        pid = if ($process) { $process.Id } else { $null }
        repo = $repoPath.Path
        servePath = $servePath.Path
        routes = $routes
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$manifestPath = Join-Path $fleetRoot "out\ship-previews.json"
$dashboardPath = Join-Path $fleetRoot "out\ship-previews.html"
New-Item -ItemType Directory -Force -Path (Split-Path $manifestPath) | Out-Null
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath

$cards = foreach ($result in $results) {
    $routeLinks = foreach ($route in $result.routes) {
        $routeText = if ([string]::IsNullOrWhiteSpace($route)) { "/" } else { [string]$route }
        $href = if ($routeText.StartsWith("/")) { "$($result.url.TrimEnd("/"))$routeText" } else { "$($result.url)$routeText" }
        "<a href=`"$(Html $href)`">$(Html $routeText)</a>"
    }

    @"
      <section class="card">
        <div>
          <p class="eyebrow">$(Html $result.status)</p>
          <h2>$(Html $result.name)</h2>
          <p class="path">$(Html $result.repo)</p>
        </div>
        <a class="primary" href="$(Html $result.url)">Open Ship</a>
        <div class="routes">$($routeLinks -join "")</div>
      </section>
"@
}

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Codex Fleet Ship Previews</title>
  <style>
    :root { color-scheme: light; --ink:#172126; --muted:#69767d; --line:#d9e1e4; --paper:#f5f7f5; --card:#fff; --accent:#173b57; }
    body { margin:0; background:var(--paper); color:var(--ink); font-family:Segoe UI, Arial, sans-serif; }
    header { padding:28px clamp(18px,4vw,48px); background:#fff; border-bottom:1px solid var(--line); }
    h1 { margin:0; font-size:clamp(26px,4vw,44px); }
    header p { margin:8px 0 0; color:var(--muted); }
    main { display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:16px; padding:22px clamp(14px,3vw,36px) 42px; }
    .card { display:grid; gap:14px; align-content:start; min-height:210px; padding:18px; background:var(--card); border:1px solid var(--line); border-radius:10px; box-shadow:0 12px 30px rgba(23,33,38,.06); }
    .eyebrow { margin:0 0 5px; color:var(--accent); font-size:12px; text-transform:uppercase; font-weight:800; letter-spacing:.06em; }
    h2 { margin:0; font-size:22px; }
    .path { margin:8px 0 0; color:var(--muted); font-size:13px; word-break:break-word; }
    a { color:var(--accent); font-weight:750; }
    .primary { display:inline-flex; justify-content:center; align-items:center; min-height:42px; border-radius:8px; color:#fff; background:var(--accent); text-decoration:none; }
    .routes { display:flex; flex-wrap:wrap; gap:8px; }
    .routes a { border:1px solid var(--line); border-radius:999px; padding:6px 10px; background:#f7fafb; text-decoration:none; font-size:13px; }
  </style>
</head>
<body>
  <header>
    <h1>Codex Fleet Ship Previews</h1>
    <p>Generated $timestamp. Local preview servers only; nothing is deployed.</p>
  </header>
  <main>
$($cards -join "`n")
  </main>
</body>
</html>
"@

Set-Content -LiteralPath $dashboardPath -Value $html

if (!$NoOpen) {
    Start-Process $dashboardPath
    if ($OpenEach) {
        foreach ($result in $results | Where-Object { ![string]::IsNullOrWhiteSpace($_.url) }) {
            Start-Process $result.url
        }
    }
}

$results | Select-Object name, status, url, pid, servePath | Format-Table -AutoSize
Write-Host ""
Write-Host "Preview dashboard: $dashboardPath" -ForegroundColor Green
Write-Host "Stop servers started by this tool with: .\stop-ship-previews.ps1" -ForegroundColor Yellow
