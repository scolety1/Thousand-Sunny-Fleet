$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path $repoRoot ".codex-local\mission-queue-tests"
if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $workRoot "inbox") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $workRoot "drafted") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $workRoot "preflight_pending") | Out-Null

function Assert-Queue {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$sample = Join-Path $repoRoot "tests\fixtures\fleet\mission-queue\sample-mission.json"
$mission = Join-Path $workRoot "inbox\sample-mission.json"
Copy-Item -LiteralPath $sample -Destination $mission

$validOut = Join-Path $workRoot "valid-transition.json"
$valid = & (Join-Path $repoRoot "tools\Move-TsfMissionState.ps1") -MissionPath $mission -FromState "inbox" -ToState "drafted" -QueueRoot $workRoot -OutFile $validOut
Assert-Queue ($valid.verdict -eq "GREEN") "inbox to drafted transition passes"
Assert-Queue (Test-Path -LiteralPath (Join-Path $workRoot "drafted\sample-mission.json")) "mission moved to drafted"

$invalidOut = Join-Path $workRoot "invalid-transition.json"
$invalid = & (Join-Path $repoRoot "tools\Move-TsfMissionState.ps1") -MissionPath (Join-Path $workRoot "drafted\sample-mission.json") -FromState "drafted" -ToState "worker_running" -QueueRoot $workRoot -OutFile $invalidOut -DryRun
Assert-Queue ($invalid.verdict -eq "RED") "invalid transition fails closed"
Assert-Queue ($invalid.moved -eq $false) "invalid dry-run transition does not move"

Write-Host "Mission queue tests passed."
