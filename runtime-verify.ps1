[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$ChecksFile = "docs/codex/RUNTIME_CHECKS.md",

    [string]$OutFile = "docs/codex/RUNTIME_VERIFICATION.md",

    [int]$TimeoutSeconds = 120,

    [switch]$Template,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-CheckLines {
    param([string]$Path)
    if (!(Test-Path $Path)) { return @() }
    return @(Get-Content $Path | Where-Object { $_ -match "^\s*-\s+(?:\[\s*\]\s+)?(command|url|url-text|text|file):\s*(.+)$" } | ForEach-Object { $_.Trim() })
}

function Invoke-CommandCheck {
    param([string]$Command)
    $job = Start-Job -ScriptBlock {
        param([string]$InnerCommand, [string]$WorkingDirectory)
        Set-Location -LiteralPath $WorkingDirectory
        & powershell -NoProfile -ExecutionPolicy Bypass -Command $InnerCommand *> $null
        return $LASTEXITCODE
    } -ArgumentList $Command, (Get-Location).Path

    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    if ($null -eq $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ passed = $false; detail = "Timed out after $TimeoutSeconds seconds."; timedOut = $true }
    }

    $exitCode = Receive-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $exitCodeValue = @($exitCode | Select-Object -Last 1)[0]
    if ($null -eq $exitCodeValue) { $exitCodeValue = 1 }
    $passed = ([int]$exitCodeValue -eq 0)
    return [pscustomobject]@{ passed = $passed; detail = "Exit code $exitCodeValue."; timedOut = $false }
}

function Invoke-UrlCheck {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec ([Math]::Min(15, $TimeoutSeconds))
        $passed = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
        return [pscustomobject]@{ passed = $passed; detail = "HTTP $($response.StatusCode)."; timedOut = $false }
    } catch {
        return [pscustomobject]@{ passed = $false; detail = $_.Exception.Message; timedOut = $false }
    }
}

function Invoke-TextCheck {
    param([string]$Spec)
    $parts = @($Spec -split "\s+=>\s+", 2)
    if ($parts.Count -ne 2) {
        return [pscustomobject]@{ passed = $false; detail = "Use: text: file => expected text"; timedOut = $false }
    }
    $path = $parts[0].Trim()
    $needle = $parts[1].Trim()
    if (!(Test-Path $path)) { return [pscustomobject]@{ passed = $false; detail = "File not found: $path."; timedOut = $false } }
    $text = Get-Content $path -Raw
    $passed = $text.Contains($needle)
    return [pscustomobject]@{ passed = $passed; detail = if ($passed) { "Found expected text." } else { "Expected text missing." }; timedOut = $false }
}

function Invoke-FileCheck {
    param([string]$Path)
    $exists = Test-Path $Path
    return [pscustomobject]@{ passed = $exists; detail = if ($exists) { "File exists." } else { "File not found." }; timedOut = $false }
}

function Invoke-UrlTextCheck {
    param([string]$Spec)
    $parts = @($Spec -split "\s+=>\s+", 2)
    if ($parts.Count -ne 2) {
        return [pscustomobject]@{ passed = $false; detail = "Use: url-text: URL => expected text"; timedOut = $false }
    }
    $url = $parts[0].Trim()
    $needle = $parts[1].Trim()
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec ([Math]::Min(15, $TimeoutSeconds))
        $statusOk = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
        $textOk = ([string]$response.Content).Contains($needle)
        $passed = ($statusOk -and $textOk)
        $detail = if ($passed) { "HTTP $($response.StatusCode), found expected text." } else { "HTTP $($response.StatusCode), expected text missing." }
        return [pscustomobject]@{ passed = $passed; detail = $detail; timedOut = $false }
    } catch {
        return [pscustomobject]@{ passed = $false; detail = $_.Exception.Message; timedOut = $false }
    }
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

if ($Template) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ChecksFile) | Out-Null
    if (!(Test-Path $ChecksFile)) {
        Set-Content -Path $ChecksFile -Value @"
# Runtime Checks

Add workflow checks that prove the ship works beyond compilation.

Examples:

- [ ] command: npm.cmd run build
- [ ] url: http://127.0.0.1:3000/health
- [ ] url-text: http://127.0.0.1:3000/ => Welcome
- [ ] text: README.md => Getting Started
- [ ] file: README.md
"@
    }
    Write-Host "Runtime check template ready: $ChecksFile" -ForegroundColor Green
    exit 0
}

if ($ValidateOnly) {
    if (!(Test-Path $OutFile)) {
        Stop-WithMessage "Runtime verification report missing: $OutFile"
    }
    $report = Get-Content $OutFile -Raw
    if ($report -match "(?im)^GREEN\s*$") {
        Write-Host "Runtime verification is GREEN." -ForegroundColor Green
        exit 0
    }
    Stop-WithMessage "Runtime verification is not GREEN."
}

$checks = @(Get-CheckLines -Path $ChecksFile)
if ($checks.Count -eq 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value @(
        "# Runtime Verification",
        "",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "## Verdict",
        "",
        "YELLOW",
        "",
        "## Findings",
        "",
        "- No runtime checks configured in $ChecksFile."
    )
    Write-Host "No runtime checks configured." -ForegroundColor Yellow
    exit 0
}

$results = @()
foreach ($line in $checks) {
    $null = $line -match "^\s*-\s+(?:\[\s*\]\s+)?(command|url|url-text|text|file):\s*(.+)$"
    $kind = $Matches[1]
    $spec = $Matches[2].Trim()
    $started = Get-Date
    $check = switch ($kind) {
        "command" { Invoke-CommandCheck -Command $spec }
        "url" { Invoke-UrlCheck -Url $spec }
        "url-text" { Invoke-UrlTextCheck -Spec $spec }
        "text" { Invoke-TextCheck -Spec $spec }
        "file" { Invoke-FileCheck -Path $spec }
        default { [pscustomobject]@{ passed = $false; detail = "Unknown check type."; timedOut = $false } }
    }
    $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
    $results += [pscustomobject]@{ kind = $kind; spec = $spec; passed = [bool]$check.passed; detail = [string]$check.detail; durationMs = $durationMs; timedOut = [bool]$check.timedOut }
}

$failed = @($results | Where-Object { -not $_.passed })
$verdict = if ($failed.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Runtime Verification",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "## Verdict",
    "",
    $verdict,
    "",
    "## Checks",
    ""
)
foreach ($result in $results) {
    $mark = if ($result.passed) { "PASS" } else { "FAIL" }
    $lines += "- [$mark] $($result.kind): $($result.spec)"
    $lines += "  - Detail: $($result.detail)"
    $lines += "  - DurationMs: $($result.durationMs)"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines

if ($failed.Count -gt 0) {
    Write-Host "Runtime verification failed." -ForegroundColor Red
    exit 1
}

Write-Host "Runtime verification passed." -ForegroundColor Green
exit 0
