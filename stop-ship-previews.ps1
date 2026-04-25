[CmdletBinding()]
param(
    [string]$ManifestPath = ".\out\ship-previews.json"
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-ProcessTree {
    param([int]$ProcessId)

    $children = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ParentProcessId -eq $ProcessId })
    foreach ($child in $children) {
        Stop-ProcessTree -ProcessId ([int]$child.ProcessId)
    }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped preview process $ProcessId" -ForegroundColor Yellow
    }
}

if (!(Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "No ship preview manifest found: $ManifestPath" -ForegroundColor Yellow
    exit 0
}

$entries = @(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
foreach ($entry in $entries) {
    if ($null -ne $entry.pid -and [int]$entry.pid -gt 0) {
        Stop-ProcessTree -ProcessId ([int]$entry.pid)
    }
}

Remove-Item -LiteralPath $ManifestPath -Force -ErrorAction SilentlyContinue
Write-Host "Ship preview servers stopped." -ForegroundColor Green
