[CmdletBinding(PositionalBinding = $false)]
param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw 'TSF_HQ_START_NODE_UNAVAILABLE' }

# Doctor is intentionally run by the public entrypoint. The server repeats the
# read-only gate immediately before claiming ownership to close the race window.
& $node.Source (Join-Path $scriptRoot 'reliability-cli.mjs') doctor-start-gate
if ($LASTEXITCODE -ne 0) { throw 'TSF_HQ_START_BLOCKED_BY_DOCTOR' }

Write-Host 'Starting TSF HQ Dispatch V1 in the foreground. Press Ctrl+C for bounded shutdown.' -ForegroundColor Cyan
& $node.Source (Join-Path $scriptRoot 'server.mjs')
exit $LASTEXITCODE
