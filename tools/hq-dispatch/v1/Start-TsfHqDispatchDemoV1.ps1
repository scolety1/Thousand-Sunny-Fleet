[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$ResetFixture
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw 'TSF_HQ_DEMO_NODE_UNAVAILABLE' }
$arguments = @((Join-Path $scriptRoot 'demo.mjs'))
if ($ResetFixture) { $arguments += '--reset' }
Write-Host 'Starting deterministic TSF-local HQ Dispatch demo in the foreground.' -ForegroundColor Cyan
& $node.Source @arguments
exit $LASTEXITCODE
