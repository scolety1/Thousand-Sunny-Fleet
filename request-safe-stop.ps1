[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project = "",
    [switch]$All,
    [switch]$Clear,
    [switch]$List
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent $PSCommandPath
$stopRoot = Join-Path $fleetRoot ".codex-local\stop-requests"
New-Item -ItemType Directory -Force -Path $stopRoot | Out-Null

function ConvertTo-SafeStopName {
    param([string]$Name)

    $safeName = if ([string]::IsNullOrWhiteSpace($Name)) { "ALL" } else { ([string]$Name) -replace "[^a-zA-Z0-9_-]+", "-" }
    $safeName = $safeName.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { return "ALL" }
    return $safeName
}

function Get-SafeStopPath {
    param([string]$Name)

    return (Join-Path $stopRoot "$(ConvertTo-SafeStopName -Name $Name).stop.json")
}

if ($List) {
    $requests = @(Get-ChildItem -Path $stopRoot -Filter "*.stop.json" -File -ErrorAction SilentlyContinue)
    if ($requests.Count -eq 0) {
        Write-Host "No safe stop requests are active." -ForegroundColor Green
        exit 0
    }

    Write-Host "Active safe stop requests:" -ForegroundColor Yellow
    foreach ($request in $requests) {
        Write-Host "- $($request.BaseName): $($request.FullName)" -ForegroundColor Yellow
    }
    exit 0
}

if ($All -and ![string]::IsNullOrWhiteSpace($Project)) {
    Write-Host "Use either -All or -Project, not both." -ForegroundColor Red
    exit 1
}

if (!$All -and [string]::IsNullOrWhiteSpace($Project)) {
    Write-Host "Choose a target:" -ForegroundColor Red
    Write-Host "  .\request-safe-stop.ps1 -All" -ForegroundColor Yellow
    Write-Host "  .\request-safe-stop.ps1 -Project EasyLife" -ForegroundColor Yellow
    Write-Host "  .\request-safe-stop.ps1 -List" -ForegroundColor Yellow
    exit 1
}

$target = if ($All) { "ALL" } else { $Project }
$stopPath = Get-SafeStopPath -Name $target

if ($Clear) {
    if (Test-Path $stopPath) {
        Remove-Item -LiteralPath $stopPath -Force
        Write-Host "Cleared safe stop request for $target." -ForegroundColor Green
    } else {
        Write-Host "No safe stop request was active for $target." -ForegroundColor Yellow
    }
    exit 0
}

$request = [pscustomobject]@{
    target = $target
    requestedAt = (Get-Date).ToString("o")
    user = $env:USERNAME
    machine = $env:COMPUTERNAME
    behavior = "Stop before the next task/batch boundary. Do not kill in-progress Codex/build/review work."
}

$request | ConvertTo-Json -Depth 4 | Set-Content -Path $stopPath -Encoding UTF8
Write-Host "Safe stop requested for $target." -ForegroundColor Yellow
Write-Host "The loop will stop at the next safe boundary instead of starting more work." -ForegroundColor Yellow
Write-Host "Request file: $stopPath" -ForegroundColor DarkYellow
Write-Host "Clear it with:" -ForegroundColor Cyan
if ($All) {
    Write-Host "  .\request-safe-stop.ps1 -All -Clear" -ForegroundColor Cyan
} else {
    Write-Host "  .\request-safe-stop.ps1 -Project $Project -Clear" -ForegroundColor Cyan
}
