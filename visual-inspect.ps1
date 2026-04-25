[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Project = "",

    [string]$ServeDirectory = ".",

    [string]$ServeCommand = "",

    [string[]]$Paths = @("/"),

    [int]$Port = 0,

    [string]$BaseUrl = "",

    [int]$ChromePort = 0,

    [string]$ChromePath = "",

    [string]$OutRoot = ".codex-logs",

    [switch]$SkipServer,

    [switch]$NoFailOnFindings
)

$ErrorActionPreference = "Continue"

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
            Start-Sleep -Milliseconds 500
        }
    }
    return $false
}

function Stop-Tree {
    param([int]$ProcessId)
    if ($ProcessId -gt 0) {
        cmd.exe /c "taskkill /PID $ProcessId /T /F" | Out-Null
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

    return 'node -e "const http=require(''http''),fs=require(''fs''),path=require(''path'');const root=process.cwd(),port={PORT};const types={''.html'':''text/html'',''.css'':''text/css'',''.js'':''text/javascript'',''.json'':''application/json'',''.csv'':''text/csv'',''.svg'':''image/svg+xml'',''.png'':''image/png'',''.jpg'':''image/jpeg'',''.jpeg'':''image/jpeg'',''.webp'':''image/webp''};http.createServer((q,s)=>{let u=decodeURIComponent(q.url.split(''?'')[0]);if(u===''/'' )u=''/index.html'';const f=path.normalize(path.join(root,u));if(!f.startsWith(root)){s.writeHead(403);return s.end(''forbidden'');}fs.readFile(f,(e,d)=>{if(e){s.writeHead(404);s.end(''not found'');}else{s.writeHead(200,{''content-type'':types[path.extname(f)]||''text/plain''});s.end(d);}});}).listen(port,''127.0.0.1'');"'
}

function Write-VisualBugReport {
    param(
        [object]$Summary,
        [string]$ReportPath
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) | Out-Null
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $high = @($Summary.findings | Where-Object { $_.severity -eq "high" })
    $medium = @($Summary.findings | Where-Object { $_.severity -eq "medium" })
    $low = @($Summary.findings | Where-Object { $_.severity -eq "low" })
    $status = if ($high.Count -gt 0) { "Needs Fixes" } else { "No Blocking Visual Bugs" }

    $lines = @(
        "# Visual Bug Report",
        "",
        "Generated: $date",
        "Project: $($Summary.project)",
        "Status: $status",
        "Artifacts: $($Summary.outDir)",
        "",
        "## Summary",
        "",
        "- High: $($high.Count)",
        "- Medium: $($medium.Count)",
        "- Low: $($low.Count)",
        ""
    )

    if ($Summary.findings.Count -eq 0) {
        $lines += "## Findings"
        $lines += ""
        $lines += "- No visual bugs detected by automated inspection."
    } else {
        $lines += "## Findings"
        $lines += ""
        $index = 1
        foreach ($finding in $Summary.findings) {
            $lines += "$index. [$($finding.severity.ToUpperInvariant())] $($finding.type) on $($finding.route) ($($finding.viewport))"
            $lines += ("   - Selector: ``{0}``" -f $finding.selector)
            $lines += "   - Issue: $($finding.message)"
            if (![string]::IsNullOrWhiteSpace([string]$finding.evidence)) {
                $lines += "   - Evidence: $($finding.evidence)"
            }
            $lines += "   - Screenshot: $($finding.screenshotPath)"
            $lines += ""
            $index++
        }
    }

    $lines += "## Suggested Task Queue Wording"
    $lines += ""
    if ($Summary.findings.Count -eq 0) {
        $lines += "- No visual fix tasks suggested."
    } else {
        foreach ($finding in @($Summary.findings | Select-Object -First 8)) {
            $lines += ("- [ ] Visual QA: fix `{0}` on `{1}` in {2} view. {3} Do not change backend, auth, secrets, dependencies, deployment config, generated output, or unrelated app behavior." -f $finding.type, $finding.route, $finding.viewport, $finding.message)
        }
    }

    Set-Content -Path $ReportPath -Value $lines
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

$chrome = if ([string]::IsNullOrWhiteSpace($ChromePath)) { Find-Chrome } else { $ChromePath }
if ([string]::IsNullOrWhiteSpace($chrome) -or !(Test-Path $chrome)) {
    Write-Host "Chrome or Edge not found." -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $repoPath (Join-Path $OutRoot "visual-inspect-$timestamp")
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

    $runner = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "tools\visual-inspect-runner.mjs"
    $options = @{
        baseUrl = $BaseUrl
        outDir = $outDir
        chromePort = $ChromePort
        project = $Project
        paths = $Paths
    } | ConvertTo-Json -Compress
    $optionsFile = Join-Path $outDir "visual-inspect-options.json"
    Set-Content -Path $optionsFile -Value $options

    node $runner "@$optionsFile"
    $runnerExit = $LASTEXITCODE
    $summaryPath = Join-Path $outDir "visual-inspect-summary.json"
    if (!(Test-Path $summaryPath)) {
        Write-Host "Visual inspect summary was not written." -ForegroundColor Red
        exit 1
    }

    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    $reportPath = Join-Path $repoPath "docs\codex\VISUAL_BUGS.md"
    Write-VisualBugReport -Summary $summary -ReportPath $reportPath

    if ($runnerExit -eq 0 -or $NoFailOnFindings) {
        Write-Host "Visual inspect completed. Report: $reportPath" -ForegroundColor Green
        exit 0
    }

    Write-Host "Visual inspect found blocking issues. Report: $reportPath" -ForegroundColor Red
    exit 1
} finally {
    if ($chromeProcess) {
        Stop-Tree -ProcessId $chromeProcess.Id
    }
    if ($serveProcess) {
        Stop-Tree -ProcessId $serveProcess.Id
    }
}
