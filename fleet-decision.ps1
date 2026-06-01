[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("Decide", "Report", "Validate")]
    [string]$Action = "Report",
    [string]$StatePath = "fleet\state\ship-state.json",
    [string]$Ship = "",
    [string]$OutFile = "fleet\status\decisions.md",
    [string]$JsonOutFile = "fleet\status\decisions.json"
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-decision.ps1")

if (!(Test-Path -LiteralPath $StatePath)) { throw "State file not found: $StatePath" }
$stateFile = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$states = @($stateFile.ships)
if (![string]::IsNullOrWhiteSpace($Ship)) {
    $states = @($states | Where-Object { [string]$_.ship -eq $Ship })
    if ($states.Count -eq 0) { throw "Ship not found in state file: $Ship" }
}

$decisions = @()
foreach ($state in $states) {
    $input = New-FleetDecisionInput -State $state -EvidenceFreshness "fresh"
    $decisions += Resolve-FleetDecision -Input $input
}

if ($Action -eq "Validate") {
    foreach ($decision in $decisions) {
        if (!(Test-FleetDecisionValue -Decision ([string]$decision.decision))) { throw "Invalid decision for $($decision.ship): $($decision.decision)" }
    }
    Write-Host "Decision validation passed for $($decisions.Count) ship(s)."
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
[pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    decisions = @($decisions)
} | ConvertTo-Json -Depth 12 | Set-Content -Path $JsonOutFile -Encoding UTF8

$lines = @(
    "# Codex Fleet Decisions",
    "",
    "Generated: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))",
    "",
    "| Ship | State | Decision | Confidence | Reason | Human Action |",
    "| --- | --- | --- | --- | --- | --- |"
)
foreach ($decision in $decisions) {
    $reason = ([string]$decision.reason).Replace("|", "/")
    $humanAction = ([string]$decision.requiredHumanAction).Replace("|", "/")
    $lines += "| $($decision.ship) | $($decision.state) | $($decision.decision) | $($decision.confidence) | $reason | $humanAction |"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
$lines | Set-Content -Path $OutFile -Encoding UTF8

if ($Action -eq "Decide" -and $decisions.Count -eq 1) {
    $decision = $decisions[0]
    Write-Host "$($decision.ship) => $($decision.decision): $($decision.reason)"
} else {
    Write-Host "DECISION_REPORT: $([System.IO.Path]::GetFullPath($OutFile))"
    Write-Host "DECISION_JSON: $([System.IO.Path]::GetFullPath($JsonOutFile))"
}
