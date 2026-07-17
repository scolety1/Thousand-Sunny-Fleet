[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$cli = Join-Path $scriptRoot 'reliability-cli.mjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw 'TSF_HQ_DOCTOR_NODE_UNAVAILABLE' }

$raw = & $node.Source $cli doctor | Out-String
$exitCode = $LASTEXITCODE
try {
    $report = $raw | ConvertFrom-Json
} catch {
    throw 'TSF_HQ_DOCTOR_OUTPUT_INVALID'
}

if ($Json) {
    $report | ConvertTo-Json -Depth 30
    exit $exitCode
}

Write-Host ("TSF HQ Dispatch Doctor V1: {0}" -f $report.overall_status) -ForegroundColor $(if ($report.safe_to_start) { 'Green' } elseif ($report.overall_status -eq 'UNSAFE_TO_START') { 'Red' } else { 'Yellow' })
Write-Output ("Safe to start: {0}" -f $report.safe_to_start)
Write-Output ("Repository: {0}" -f $report.repository.top)
Write-Output ("Commit: {0}" -f $report.repository.head)
Write-Output ("Listener: {0}:{1} ({2} listener(s))" -f $report.listener_state.host, $report.listener_state.port, @($report.listener_state.listeners).Count)
Write-Output ("Process owner: {0}" -f $report.process_owner.disposition)
Write-Output ("Path budget: {0}/{1}" -f $report.path_budget.maximum_path_length, $report.path_budget.target_limit)
Write-Output ("Pending TIM_REQUIRED: {0}; interrupted: {1}; replay conflicts: {2}" -f $report.pending_tim_required_requests, $report.interrupted_missions, $report.duplicate_replay_conflicts)
foreach ($check in $report.checks) {
    Write-Output ("[{0}] {1}" -f $check.status, $check.name)
    Write-Output ("  Next: {0}" -f $check.next_action)
}
Write-Output ("Exact next action: {0}" -f $report.exact_next_action)
Write-Output 'Diagnostic output excludes the local stop capability and operator-session tokens.'
exit $exitCode
