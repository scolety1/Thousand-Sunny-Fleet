[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$RecoverVerifiedStaleOwnership
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw 'TSF_HQ_STOP_NODE_UNAVAILABLE' }
$command = if ($RecoverVerifiedStaleOwnership) { 'recover-stale-owner' } else { 'stop' }
& $node.Source (Join-Path $scriptRoot 'reliability-cli.mjs') $command
exit $LASTEXITCODE
