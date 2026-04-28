[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Project = "",

    [string]$ServeDirectory = ".",

    [string]$ServeCommand = "",

    [int]$Port = 0,

    [string[]]$RequiredText = @(),

    [string[]]$Anchors = @(),

    [string]$Path = "/",

    [string]$BaseUrl = "",

    [int]$ChromePort = 0,

    [string]$ChromePath = "",

    [string]$OutRoot = ".codex-logs",

    [switch]$SkipServer
)

$ErrorActionPreference = "Continue"

$Anchors = @($Anchors |
    ForEach-Object { ([string]$_) -split "," } |
    ForEach-Object { $_.Trim() } |
    Where-Object { ![string]::IsNullOrWhiteSpace($_) })

function Find-Chrome {
    $candidates = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return ""
}

function Wait-Http {
    param([string]$Url, [int]$TimeoutSeconds = 45)

    $started = Get-Date
    while (((Get-Date) - $started).TotalSeconds -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return $true
            }
        } catch {
            $statusCode = 0
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($statusCode -ge 200 -and $statusCode -lt 500) {
                return $true
            }
            Start-Sleep -Milliseconds 500
        }
    }
    return $false
}

function Stop-Tree {
    param([int]$ProcessId)
    if ($ProcessId -gt 0) {
        cmd.exe /c "taskkill /PID $ProcessId /T /F 1>NUL 2>NUL" | Out-Null
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

function Get-DefaultServeCommand {
    param([string]$ServeDir)

    if (Test-Path (Join-Path $ServeDir "package.json")) {
        return "npm.cmd run dev -- --host 127.0.0.1 --port {PORT}"
    }

    $fleetRoot = Split-Path -Parent $PSCommandPath
    $serverScript = Join-Path $fleetRoot "tools\static-preview-server.ps1"
    return ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" -Root . -Port {{PORT}}' -f $serverScript)
}

$repoMatches = @(Resolve-Path $Repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Write-Host "Repo not found or ambiguous: $Repo" -ForegroundColor Red
    exit 1
}
$repoPath = $repoMatches[0].Path

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Split-Path -Leaf $repoPath
}

if ($Port -le 0) {
    $Port = Get-FreeTcpPort
}
if ($ChromePort -le 0) {
    $ChromePort = Get-FreeTcpPort
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = "http://127.0.0.1:$Port"
}

if (![string]::IsNullOrWhiteSpace($Path) -and $Path -ne "/") {
    $base = [System.Uri]$BaseUrl
    $builder = [System.UriBuilder]::new($base)
    $builder.Path = if ($Path.StartsWith("/")) { $Path } else { "/$Path" }
    $BaseUrl = $builder.Uri.AbsoluteUri
}

if ($RequiredText.Count -eq 0) {
    if ($Project -match "Restaurant") {
        $RequiredText = @("Cellar & Table", "wine", "restaurant", "Text", "Email")
    } else {
        $RequiredText = @("EasyLife")
    }
}

if ($Anchors.Count -eq 0 -and $Project -match "Restaurant") {
    $Anchors = @("#demos", "#wine-list", "#ways-we-can-help", "#contact")
}

$chrome = if ([string]::IsNullOrWhiteSpace($ChromePath)) { Find-Chrome } else { $ChromePath }
if ([string]::IsNullOrWhiteSpace($chrome) -or !(Test-Path $chrome)) {
    Write-Host "Chrome or Edge not found." -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $repoPath (Join-Path $OutRoot "visual-$timestamp")
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$serveProcess = $null
$chromeProcess = $null

try {
    if (!$SkipServer) {
        $serveDir = Join-Path $repoPath $ServeDirectory
        if ([string]::IsNullOrWhiteSpace($ServeCommand)) {
            $ServeCommand = Get-DefaultServeCommand -ServeDir $serveDir
        }
        $command = $ServeCommand.Replace("{PORT}", [string]$Port)
        $serveLog = Join-Path $outDir "server.log"
        $serveErr = Join-Path $outDir "server.err.log"
        $serveProcess = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $command) -WorkingDirectory $serveDir -RedirectStandardOutput $serveLog -RedirectStandardError $serveErr -PassThru -WindowStyle Hidden
    }

    if (-not (Wait-Http -Url $BaseUrl -TimeoutSeconds 60)) {
        Write-Host "Timed out waiting for $BaseUrl" -ForegroundColor Red
        exit 1
    }

    $chromeUserData = Join-Path $outDir "chrome-profile"
    $chromeArgs = @(
        "--headless=new",
        "--remote-debugging-port=$ChromePort",
        "--user-data-dir=$chromeUserData",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "about:blank"
    )
    $chromeProcess = Start-Process -FilePath $chrome -ArgumentList $chromeArgs -PassThru -WindowStyle Hidden

    if (-not (Wait-Http -Url "http://127.0.0.1:$ChromePort/json/version" -TimeoutSeconds 30)) {
        Write-Host "Timed out waiting for Chrome DevTools on port $ChromePort" -ForegroundColor Red
        exit 1
    }

    $runner = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "tools\visual-smoke-runner.mjs"
    $options = @{
        baseUrl = $BaseUrl
        outDir = $outDir
        requiredText = $RequiredText
        anchors = $Anchors
        chromePort = $ChromePort
    } | ConvertTo-Json -Compress
    $optionsFile = Join-Path $outDir "visual-smoke-options.json"
    Set-Content -Path $optionsFile -Value $options

    node $runner "@$optionsFile"
    $ok = $LASTEXITCODE -eq 0
    if ($ok) {
        Write-Host "Visual smoke passed. Artifacts: $outDir" -ForegroundColor Green
        exit 0
    }

    Write-Host "Visual smoke failed. Artifacts: $outDir" -ForegroundColor Red
    exit 1
} finally {
    if ($chromeProcess) {
        Stop-Tree -ProcessId $chromeProcess.Id
    }
    if ($serveProcess) {
        Stop-Tree -ProcessId $serveProcess.Id
    }
}
