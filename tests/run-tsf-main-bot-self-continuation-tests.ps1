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

$bounded = & (Join-Path $repoRoot "tools\Invoke-TsfProjectMainBotSelfContinuation.ps1") -RequestPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\self_continuation\bounded-fixture-worker.request.json") -OutDirectory (Join-Path $workRoot "bounded-dry") -ApprovedFixtureWorkerMode -DryRun -MaxWorkerInvocations 1
Assert-Self ($bounded.next_decision -eq "GREEN_SELF_CONTINUATION_DRY_RUN_READY") "bounded fixture request reaches approved dry-run readiness"
Assert-Self ($bounded.selected_worker_role -eq "builder_worker") "bounded fixture request routes to Builder Worker"
Assert-Self ($bounded.worker_invocations_used -eq 0) "bounded dry-run consumes no worker invocation"
Assert-Self ($bounded.codex_cli_worker_execution_invoked -eq $false) "bounded dry-run invokes no Codex CLI worker"

$overBudget = & (Join-Path $repoRoot "tools\Invoke-TsfProjectMainBotSelfContinuation.ps1") -RequestPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\self_continuation\bounded-fixture-worker.request.json") -OutDirectory (Join-Path $workRoot "over-budget") -ApprovedFixtureWorkerMode -MaxWorkerInvocations 3
Assert-Self ($overBudget.next_decision -eq "TIM_REQUIRED_WORKER_BUDGET_EXCEEDED") "worker budget above policy fails closed"
Assert-Self ($overBudget.codex_cli_worker_execution_invoked -eq $false) "over-budget request invokes no Codex CLI worker"

Write-Host "Project Main Bot self-continuation tests passed."
