$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path $repoRoot ".codex-local\main-bot-self-continuation-tests"
if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

function Assert-Self {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$safe = & (Join-Path $repoRoot "tools\Invoke-TsfProjectMainBotSelfContinuation.ps1") -RequestPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\self_continuation\safe-local.request.json") -OutDirectory (Join-Path $workRoot "safe")
Assert-Self ($safe.next_decision -eq "GREEN_SELF_CONTINUATION_DRY_RUN_READY") "safe local request self-continues to dry-run readiness"
Assert-Self ($safe.codex_cli_worker_execution_invoked -eq $false) "safe self-continuation invokes no Codex CLI worker"

$hard = & (Join-Path $repoRoot "tools\Invoke-TsfProjectMainBotSelfContinuation.ps1") -RequestPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\self_continuation\hard-gate.request.json") -OutDirectory (Join-Path $workRoot "hard")
Assert-Self ($hard.next_decision -eq "TIM_REQUIRED") "hard gate request escalates to TIM_REQUIRED"
Assert-Self ($hard.push_merge_deploy_attempted -eq $false) "hard gate request performs no push/merge/deploy"

Write-Host "Project Main Bot self-continuation tests passed."
