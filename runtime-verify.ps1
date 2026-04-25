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
    return @(Get-Content $Path | Where-Object { $_ -match "^\s*-\s+\[ \]\s+(command|url|text):\s*(.+)$" } | ForEach-Object { $_.Trim() })
}

function Invoke-CommandCheck {
    param([string]$Command)
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $Command *> $null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-UrlCheck {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec ([Math]::Min(15, $TimeoutSeconds))
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Invoke-TextCheck {
    param([string]$Spec)
    $parts = @($Spec -split "\s+=>\s+", 2)
    if ($parts.Count -ne 2) { return $false }
    $path = $parts[0].Trim()
    $needle = $parts[1].Trim()
    if (!(Test-Path $path)) { return $false }
    $text = Get-Content $path -Raw
    return ($text -like "*$needle*")
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
- [ ] text: README.md => Getting Started
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
    $null = $line -match "^\s*-\s+\[ \]\s+(command|url|text):\s*(.+)$"
    $kind = $Matches[1]
    $spec = $Matches[2].Trim()
    $passed = switch ($kind) {
        "command" { Invoke-CommandCheck -Command $spec }
        "url" { Invoke-UrlCheck -Url $spec }
        "text" { Invoke-TextCheck -Spec $spec }
        default { $false }
    }
    $results += [pscustomobject]@{ kind = $kind; spec = $spec; passed = $passed }
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
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines

if ($failed.Count -gt 0) {
    Write-Host "Runtime verification failed." -ForegroundColor Red
    exit 1
}

Write-Host "Runtime verification passed." -ForegroundColor Green
exit 0
