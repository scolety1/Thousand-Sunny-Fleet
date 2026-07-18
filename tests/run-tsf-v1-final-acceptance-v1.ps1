[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$EvidenceRoot,
    [switch]$SkipRealAppServerProof
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
. (Join-Path $PSScriptRoot 'support\TsfFinalAcceptanceGitState.ps1')
$localRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.codex-local'))
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$startedAt = [datetimeoffset]::UtcNow
if (-not $EvidenceRoot) {
    $stamp = $startedAt.ToString('yyyyMMddTHHmmssfffZ')
    $EvidenceRoot = Join-Path $localRoot "evidence\m4-final-acceptance\$stamp-$PID"
}
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$localPrefix = $localRoot.TrimEnd('\') + '\'
if (-not $EvidenceRoot.StartsWith($localPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'TSF_M4_EVIDENCE_ROOT_OUTSIDE_CODEX_LOCAL'
}
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
if ((Get-Item -LiteralPath $EvidenceRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'TSF_M4_EVIDENCE_ROOT_REPARSE_POINT_REJECTED'
}

$rows = [Collections.Generic.List[object]]::new()
$hasFailure = $false

function Get-RelativeEvidencePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return $Path.Substring($repoRoot.Length).TrimStart('\').Replace('\', '/')
}

function Get-OutputMarkers([string]$Text) {
    $markers = [Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '(?i)assertions?|\bPASS(?:ED)?\b|"status"\s*:\s*"PASS"|tests passed') {
            $candidate = $line.Trim()
            if ($candidate.Length -gt 240) { $candidate = $candidate.Substring(0, 240) }
            if ($candidate) { $markers.Add($candidate) | Out-Null }
            if ($markers.Count -ge 8) { break }
        }
    }
    return @($markers)
}

function Invoke-AcceptanceCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$File,
        [string[]]$Arguments = @(),
        [string]$PassBasis = 'SUITE_ASSERTIONS_ENFORCED_BY_PROCESS_EXIT',
        [int[]]$ExpectedExitCodes = @(0),
        [string]$ExecutionClassification = 'DETERMINISTIC_LOCAL',
        [int]$AssertionOrCriterionCount = 0
    )
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
    $stdoutPath = Join-Path $EvidenceRoot "$safeName.stdout.txt"
    $stderrPath = Join-Path $EvidenceRoot "$safeName.stderr.txt"
    $commandStarted = [datetimeoffset]::UtcNow
    $exitCode = -1
    $launchError = $null
    try {
        $process = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $exitCode = [int]$process.ExitCode
    } catch {
        $launchError = $_.Exception.ToString()
    }
    if (-not (Test-Path -LiteralPath $stdoutPath)) { [IO.File]::WriteAllText($stdoutPath, '', $utf8NoBom) }
    if (-not (Test-Path -LiteralPath $stderrPath)) { [IO.File]::WriteAllText($stderrPath, $(if ($launchError) { $launchError } else { '' }), $utf8NoBom) }
    $commandFinished = [datetimeoffset]::UtcNow
    $stdout = [IO.File]::ReadAllText($stdoutPath)
    $status = if ($ExpectedExitCodes -contains $exitCode -and -not $launchError) { 'PASS' } else { 'FAIL' }
    if ($status -eq 'FAIL') { $script:hasFailure = $true }
    $observedCount = $AssertionOrCriterionCount
    $countBasis = if ($observedCount -gt 0) { 'DECLARED_SUITE_COUNT' } else { 'PROCESS_EXIT_CRITERION' }
    if ($observedCount -le 0 -and $stdout -match '(?im)assertions?\s*[=:]\s*(?<count>[0-9]+)') {
        $observedCount = [int]$Matches.count
        $countBasis = 'OBSERVED_STDOUT_ASSERTION_MARKER'
    }
    if ($observedCount -le 0) { $observedCount = 1 }
    $row = [pscustomobject][ordered]@{
        check = $Name
        status = $status
        execution_classification = $ExecutionClassification
        started_utc = $commandStarted.ToString('o')
        finished_utc = $commandFinished.ToString('o')
        duration_ms = [math]::Round(($commandFinished - $commandStarted).TotalMilliseconds)
        command = (@($File) + $Arguments) -join ' '
        exit_code = $exitCode
        assertion_or_criterion_count = $observedCount
        count_basis = $countBasis
        result_identity = if ($status -eq 'PASS') { "EXPECTED_PROCESS_EXIT_$exitCode" } elseif ($launchError) { 'PROCESS_LAUNCH_FAILURE' } else { "UNEXPECTED_PROCESS_EXIT_$exitCode" }
        pass_basis = $PassBasis
        assertion_or_pass_markers = @(Get-OutputMarkers $stdout)
        candidate_head = $head
        candidate_tree = $tree
        stdout_path = Get-RelativeEvidencePath $stdoutPath
        stdout_bytes = (Get-Item -LiteralPath $stdoutPath).Length
        stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
        stderr_path = Get-RelativeEvidencePath $stderrPath
        stderr_bytes = (Get-Item -LiteralPath $stderrPath).Length
        stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $rows.Add($row) | Out-Null
    return $row
}

function Add-AssertionRow {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$Evidence,
        [string]$PassBasis = 'DIRECT_M4_ASSERTION'
    )
    if (-not $Passed) { $script:hasFailure = $true }
    $now = [datetimeoffset]::UtcNow.ToString('o')
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
    $stdoutPath = Join-Path $EvidenceRoot "$safeName.stdout.txt"
    $stderrPath = Join-Path $EvidenceRoot "$safeName.stderr.txt"
    [IO.File]::WriteAllText($stdoutPath, $Evidence + [Environment]::NewLine, $utf8NoBom)
    [IO.File]::WriteAllText($stderrPath, '', $utf8NoBom)
    $rows.Add([pscustomobject][ordered]@{
        check = $Name
        status = if ($Passed) { 'PASS' } else { 'FAIL' }
        execution_classification = 'DETERMINISTIC_LOCAL'
        started_utc = $now
        finished_utc = $now
        duration_ms = 0
        command = 'IN_PROCESS_ASSERTION'
        exit_code = if ($Passed) { 0 } else { 1 }
        assertion_or_criterion_count = 1
        count_basis = 'DIRECT_ASSERTION'
        result_identity = if ($Passed) { 'ASSERTION_PASS' } else { 'ASSERTION_FAILURE' }
        pass_basis = $PassBasis
        assertion_or_pass_markers = @($Evidence)
        candidate_head = $head
        candidate_tree = $tree
        stdout_path = Get-RelativeEvidencePath $stdoutPath
        stdout_bytes = (Get-Item -LiteralPath $stdoutPath).Length
        stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
        stderr_path = Get-RelativeEvidencePath $stderrPath
        stderr_bytes = 0
        stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }) | Out-Null
}

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$node = (Get-Command node.exe -ErrorAction Stop).Source
$git = (Get-Command git.exe -ErrorAction Stop).Source
$psBase = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File')

$gitState = Get-TsfFinalAcceptanceGitState -RepositoryRoot $repoRoot -GitExecutable $git
$head = [string]$gitState.head
$tree = [string]$gitState.tree
$branch = if ($gitState.classification -eq 'ATTACHED_BRANCH') { [string]$gitState.branch } else { $null }
$gitStatePath = Join-Path $EvidenceRoot 'git-state-evidence.json'
[IO.File]::WriteAllText($gitStatePath, ($gitState | ConvertTo-Json -Depth 20), $utf8NoBom)
Add-AssertionRow -Name 'final_acceptance_git_state' -Passed ($gitState.classification -in @('ATTACHED_BRANCH', 'DETACHED_COMMIT_PINNED')) -Evidence "classification=$($gitState.classification) detached=$($gitState.detached) branch=$(if($branch){$branch}else{'<null>'}) head=$head tree=$tree evidence_sha256=$($gitState.git_state_evidence_sha256)" -PassBasis 'CANONICAL_GIT_STATE_AND_CLOSED_COMMAND_DIAGNOSTICS'
$originMainCommand = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $repoRoot -GitExecutable $git -Arguments @('rev-parse', 'refs/remotes/origin/main') -Stage 'FINAL_ACCEPTANCE_ORIGIN_MAIN_PREFLIGHT'
$originMainLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $originMainCommand.stdout
$originMain = if ($originMainCommand.success -and $originMainLine.valid) { [string]$originMainLine.value } else { '' }
Add-AssertionRow -Name 'origin_main_identity_available' -Passed ($originMain -match '^[a-f0-9]{40,64}$') -Evidence "command=$($originMainCommand.command) exit=$($originMainCommand.exit_code) stderr_sha256=$($originMainCommand.stderr_sha256) origin_main=$originMain"
git -C $repoRoot merge-base --is-ancestor 952f30e137214735fe2513a7b068d9680ca882c7 HEAD
$baselineIsAncestor = $LASTEXITCODE -eq 0
Add-AssertionRow -Name 'required_baseline_ancestry' -Passed $baselineIsAncestor -Evidence "head=$head origin_main=$originMain"

$changedPaths = @(git -C $repoRoot diff --name-only refs/remotes/origin/main...HEAD; git -C $repoRoot diff --name-only)
$changedPaths = @($changedPaths | Where-Object { $_ } | Sort-Object -Unique)
$allowedPattern = '^(tools/(codex-fleet-enforcement-kernel\.ps1|TsfDurableContract(\.Canonical\.ps1|\.psm1)|hq-dispatch/v1/(Test-TsfHqDispatchDoctorV1\.ps1|doctor-format\.ps1))|tests/(run-tsf-hq-dispatch-reliability-v1\.ps1|run-tsf-v1-final-acceptance-v1\.ps1|run-tsf-hq-chokepoint-tests\.ps1|run-tsf-final-static-integrity-tests\.ps1|run-tsf-canonical-runtime-app-server-tests\.ps1|test-tsf-v1-m4-acceptance-corrections-v1\.ps1|test-tsf-hq-dispatch-start-stop-v1\.mjs|test-tsf-hq-dispatch-real-reliability-v1\.mjs|support/TsfParserEvidence\.ps1)|docs/hq/tsf_v1_final_acceptance_demo_v1_20260717/)'
$hotfixAllowedPattern = '^(\.gitattributes|\.gitignore|docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/mission_schema_v1\.json|docs/hq/tsf_v1_response_contract_runtime_cleanliness_hotfix_v1_20260718/.*|docs/hq/tsf_canonical_runtime_app_server_vertical_slice_v1_20260711/(APP_SERVER_CAPABILITY_REPORT\.json|APP_SERVER_EVENT_SUMMARY\.json|EXECUTED_TEST_COVERAGE\.csv|VALIDATION\.json)|fleet/control/(exact-literal-response-contract|mission-envelope|canonical-queue-document|worker-instruction-packet|policy-manifest)\.(schema\.)?v1\.json|fleet/control/hq-dispatch/hq-dispatch-(route-preview-response|interruption-evidence)\.schema\.v1\.json|tools/(Invoke-TsfMissionLifecycle|TsfJsonContract)\.ps1|tools/tsf-codex-app-server-adapter\.mjs|tools/hq-dispatch/v1/(Invoke-TsfHqDispatchRoutePreview|New-TsfHqDispatchGovernedMission|Test-TsfHqDispatchCanonicalQueueRecordsV1)\.ps1|tools/hq-dispatch/v1/(demo-fixtures|demo|mission-relay|reliability|reliability-cli|server)\.mjs|tools/hq-dispatch/v1/public/(app\.js|index\.html|styles\.css)|tests/fixtures/fleet/durable-contract/fake-codex-app-server\.mjs|tests/support/(New-TsfCanonicalQueueTestRecords\.ps1|TsfFinalAcceptanceGitState\.ps1|TsfPacketEvidencePath\.ps1|tsf-canonical-packet-hash\.mjs|tsf-hq-dispatch-initial-doctor-isolation\.mjs|tsf-hq-dispatch-m3-real-interruption-barrier\.mjs|tsf-hq-dispatch-recovery-result-contract-proof\.mjs|tsf-process-action-ledger\.mjs|tsf-proof-fetch-trace\.mjs|tsf-stop-receipt-contract\.mjs)|tests/(run-tsf-final-three-authority-tests|run-tsf-hq-dispatch-exact-result-evidence-tests|run-tsf-hq-dispatch-wrong-result-lifecycle-proof-v1|run-tsf-native-fast-fail-diagnostic-v1|run-tsf-response-runtime-hotfix-packet-self-check-v1|test-tsf-v1-final-acceptance-git-state-v1|test-tsf-response-runtime-hotfix-packet-evidence-paths-v1)\.ps1|tests/(run-tsf-hq-dispatch-real-readonly-v1|run-tsf-hq-dispatch-production-hotfix-proof-v1|run-tsf-response-runtime-hotfix-packet-hash-v1|test-tsf-response-runtime-hotfix-packet-hash-v1|test-tsf-hq-dispatch-initial-doctor-isolation-v1|test-tsf-hq-dispatch-demo-v1|test-tsf-hq-dispatch-exact-response-adapter-v1|test-tsf-hq-dispatch-interruption-barrier-safety-v1|test-tsf-hq-dispatch-recovery-result-contract-proof-v1|test-tsf-hq-dispatch-responsive-layout-v1|test-tsf-hq-dispatch-reliability-v1|test-tsf-hq-dispatch-real-reliability-v1|test-tsf-hq-dispatch-restart-tim-v1|test-tsf-hq-dispatch-request-result-relay-v1|test-tsf-hq-dispatch-exact-response-contract-v1|test-tsf-hq-dispatch-shutdown-coordinator-v1|test-tsf-owned-process-registration-synchronization-v1|test-tsf-owned-process-registry-v1|test-tsf-process-action-ledger-v1|test-tsf-proof-fetch-native-ladder-v1|test-tsf-proof-fetch-trace-v1|test-tsf-stop-receipt-contract-v1|test-tsf-runtime-queue-cleanliness-v1)\.mjs)$'
$unexpectedPaths = @($changedPaths | Where-Object { $_.Replace('\', '/') -notmatch $allowedPattern -and $_.Replace('\', '/') -notmatch $hotfixAllowedPattern })
Add-AssertionRow -Name 'protected_path_scope' -Passed ($unexpectedPaths.Count -eq 0) -Evidence $(if ($unexpectedPaths.Count) { 'unexpected=' + ($unexpectedPaths -join ',') } else { 'Only M4 acceptance, documentation, and localized caveat paths changed.' })

Invoke-AcceptanceCommand -Name 'm4_localized_corrections' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'test-tsf-v1-m4-acceptance-corrections-v1.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'm3_reliability_aggregate' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-hq-dispatch-reliability-v1.ps1'), '-EvidenceRoot', (Join-Path $EvidenceRoot 'm3-aggregate'), '-Milestone4Acceptance')) | Out-Null
Invoke-AcceptanceCommand -Name 'm1_route_preview' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-route-preview-v1.mjs')) | Out-Null
Invoke-AcceptanceCommand -Name 'm2a_exact_result' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-hq-dispatch-exact-result-evidence-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'exact_response_contract_propagation' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-exact-response-contract-v1.mjs')) -AssertionOrCriterionCount 43 | Out-Null
Invoke-AcceptanceCommand -Name 'doctor_canonical_runtime_cleanliness' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-runtime-queue-cleanliness-v1.mjs')) -AssertionOrCriterionCount 87 | Out-Null
Invoke-AcceptanceCommand -Name 'recovery_result_contract_modes' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-recovery-result-contract-proof-v1.mjs')) -PassBasis '36_ADVERSARIAL_CASES_WITH_90_EXACT_AND_66_GENERAL_INVARIANT_ASSERTIONS' -AssertionOrCriterionCount 36 | Out-Null
Invoke-AcceptanceCommand -Name 'initial_doctor_isolation' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-initial-doctor-isolation-v1.mjs')) -PassBasis 'FIRST_ATTEMPT_AND_NEGATIVE_CHECK_LEVEL_ISOLATION_ASSERTIONS' -AssertionOrCriterionCount 19 | Out-Null
Invoke-AcceptanceCommand -Name 'final_acceptance_git_state_contract' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'test-tsf-v1-final-acceptance-git-state-v1.ps1'))) -PassBasis 'DETACHED_ATTACHED_NORMALIZATION_AND_FAIL_CLOSED_GIT_DIAGNOSTICS' -AssertionOrCriterionCount 25 | Out-Null
Invoke-AcceptanceCommand -Name 'canonical_packet_git_blob_hashes' -File $node -Arguments @((Join-Path $PSScriptRoot 'run-tsf-response-runtime-hotfix-packet-hash-v1.mjs'), '--treeish', 'HEAD') -PassBasis 'CANONICAL_GIT_BLOB_HASH_AND_MATERIALIZATION_DOMAIN_ASSERTIONS' -AssertionOrCriterionCount 17 | Out-Null
Invoke-AcceptanceCommand -Name 'responsive_operator_ui' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-responsive-layout-v1.mjs'), '--evidence-root', (Join-Path $EvidenceRoot 'responsive-layout')) -PassBasis '333_ASSERTION_REAL_BROWSER_RESPONSIVE_AND_ACCESSIBILITY_PROOF' -ExecutionClassification 'REAL_LOCAL_HEADLESS_BROWSER' -AssertionOrCriterionCount 333 | Out-Null
Invoke-AcceptanceCommand -Name 'wrong_result_integrated_lifecycle' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-hq-dispatch-wrong-result-lifecycle-proof-v1.ps1'), '-TestOnlyIsolatedQueue')) -ExecutionClassification 'DETERMINISTIC_FAKE_APP_SERVER' -AssertionOrCriterionCount 46 | Out-Null
Invoke-AcceptanceCommand -Name 'project_main_bot_routing' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-project-main-bot-role-foundation-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'durable_contracts' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-durable-contract-tests.ps1'), '-EvidenceRoot', (Join-Path $EvidenceRoot 'durable-contracts'))) | Out-Null
Invoke-AcceptanceCommand -Name 'canonical_mission_queue' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-mission-queue-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'verifier_preservation_admission' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-final-three-authority-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'role_aware_lifecycle' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-role-aware-lifecycle-integration-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'minimum_kernel' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-minimum-viable-kernel-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'kernel_v2' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-kernel-v2-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'hq_chokepoint' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-hq-chokepoint-tests.ps1'), '-EvidenceRoot', (Join-Path $EvidenceRoot 'hq-chokepoint'))) | Out-Null
Invoke-AcceptanceCommand -Name 'canonical_app_server_matrix' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-canonical-runtime-app-server-tests.ps1'), '-EvidenceRoot', (Join-Path $EvidenceRoot 'canonical-app-server'))) | Out-Null
Invoke-AcceptanceCommand -Name 'final_static_integrity' -File $powershell -Arguments ($psBase + @((Join-Path $PSScriptRoot 'run-tsf-final-static-integrity-tests.ps1'))) | Out-Null
Invoke-AcceptanceCommand -Name 'committed_candidate_diff_check' -File $git -Arguments @('-C', $repoRoot, 'diff', '--check', 'refs/remotes/origin/main...HEAD') -PassBasis 'COMMITTED_CANDIDATE_DIFF_CHECK_EXIT_0' | Out-Null

$realProofRan = $false
if (-not $SkipRealAppServerProof -and -not $hasFailure) {
    $realProofRan = $true
    Invoke-AcceptanceCommand -Name 'real_app_server_interruption_recovery' -File $node -Arguments @((Join-Path $PSScriptRoot 'test-tsf-hq-dispatch-real-reliability-v1.mjs')) -PassBasis '186_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_FRESH_EXACT_STOP_MISSION_REVISION_RECOVERY_PROOF' -ExecutionClassification 'REAL_CODEX_APP_SERVER' -AssertionOrCriterionCount 186 | Out-Null
} elseif (-not $SkipRealAppServerProof) {
    Add-AssertionRow -Name 'real_app_server_interruption_recovery' -Passed $false -Evidence 'Blocked because an earlier acceptance gate failed; no real proof was started.'
}

$doctorRow = Invoke-AcceptanceCommand -Name 'final_doctor_json' -File $powershell -Arguments ($psBase + @((Join-Path $repoRoot 'tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1'), '-Json')) -PassBasis 'DOCTOR_EXPECTED_GREEN_ACTION_REQUIRED_OR_TIM_REQUIRED_EXIT_AND_CANONICAL_JSON_ASSERTIONS' -ExpectedExitCodes @(0, 2, 3)
$doctor = $null
try {
    if (@(0, 2, 3) -contains $doctorRow.exit_code) { $doctor = Get-Content -LiteralPath (Join-Path $EvidenceRoot 'final_doctor_json.stdout.txt') -Raw | ConvertFrom-Json }
} catch {
    $doctor = $null
}
$cleanupPassed = $null -ne $doctor -and $doctor.safe_to_start -and @($doctor.listener_state.listeners).Count -eq 0 -and $doctor.process_owner.disposition -eq 'ABSENT' -and @($doctor.active_child).Count -eq 0
Add-AssertionRow -Name 'final_no_owner_listener_or_owned_child' -Passed $cleanupPassed -Evidence $(if ($doctor) { "safe=$($doctor.safe_to_start) owner=$($doctor.process_owner.disposition) listeners=$(@($doctor.listener_state.listeners).Count) children=$(@($doctor.active_child).Count)" } else { 'Doctor JSON unavailable or non-GREEN.' })

$trackedStatus = @(git -C $repoRoot status --porcelain=v2 --untracked-files=all | Where-Object { $_ -notmatch '^\? \.codex-local/' })
Add-AssertionRow -Name 'final_tracked_worktree_clean' -Passed ($trackedStatus.Count -eq 0) -Evidence $(if ($trackedStatus.Count) { $trackedStatus -join ' | ' } else { 'No tracked or non-ignored untracked changes remain.' })

$finishedAt = [datetimeoffset]::UtcNow
$status = if ($hasFailure) { 'FAIL' } elseif ($SkipRealAppServerProof) { 'PASS_DETERMINISTIC_ONLY_REAL_PROOF_NOT_RERUN' } elseif ($realProofRan) { 'PASS' } else { 'FAIL' }
$summary = [pscustomobject][ordered]@{
    schema_version = 'tsf_v1_final_acceptance_result_v1'
    generated_at = $finishedAt.ToString('o')
    started_utc = $startedAt.ToString('o')
    finished_utc = $finishedAt.ToString('o')
    duration_seconds = [math]::Round(($finishedAt - $startedAt).TotalSeconds, 3)
    status = $status
    repository = [pscustomobject][ordered]@{
        worktree = $repoRoot
        branch = $branch
        head = $head
        tree = $tree
        git_state_classification = $gitState.classification
        detached = [bool]$gitState.detached
        branch_requirement_disposition = $gitState.branch_requirement_disposition
        git_state_evidence_path = Get-RelativeEvidencePath $gitStatePath
        git_state_evidence_sha256 = $gitState.git_state_evidence_sha256
        git_state_commands = $gitState.commands
        origin_main = $originMain
        required_baseline = '952f30e137214735fe2513a7b068d9680ca882c7'
        required_baseline_is_ancestor = $baselineIsAncestor
        changed_paths = $changedPaths
        unexpected_protected_paths = $unexpectedPaths
    }
    execution = [pscustomobject][ordered]@{
        evidence_root = Get-RelativeEvidencePath $EvidenceRoot
        checks = $rows.Count
        assertion_or_criterion_count = [int](($rows | Measure-Object -Property assertion_or_criterion_count -Sum).Sum)
        failed_checks = @($rows | Where-Object status -eq 'FAIL').Count
        real_app_server_proof_required = -not $SkipRealAppServerProof
        real_app_server_proof_ran = $realProofRan
        control_plane_network_policy = if ($realProofRan) { 'CODEX_SERVICE_ONLY' } else { 'NOT_USED_BY_THIS_RUN' }
        worker_tool_network = 'DISABLED'
    }
    checks = @($rows)
    final_cleanup = [pscustomobject][ordered]@{
        doctor_available = $null -ne $doctor
        doctor_status = if ($doctor) { $doctor.overall_status } else { $null }
        safe_to_start = if ($doctor) { [bool]$doctor.safe_to_start } else { $false }
        owner_disposition = if ($doctor) { $doctor.process_owner.disposition } else { $null }
        listener_count = if ($doctor) { @($doctor.listener_state.listeners).Count } else { $null }
        owned_child_count = if ($doctor) { @($doctor.active_child).Count } else { $null }
        tracked_status = $trackedStatus
    }
    authority_boundary = [pscustomobject][ordered]@{
        arbitrary_command_authority_added = $false
        arbitrary_repository_authority_added = $false
        production_deployment_authority_added = $false
        push_or_merge_authority_added = $false
        automatic_approval_added = $false
        background_or_persistent_execution_added = $false
        plugin_execution_added = $false
        credential_discovery_added = $false
        second_canonical_system_added = $false
    }
}

$summaryPath = Join-Path $EvidenceRoot 'acceptance-summary.json'
$summaryJson = $summary | ConvertTo-Json -Depth 30
[IO.File]::WriteAllText($summaryPath, $summaryJson, $utf8NoBom)
$csvPath = Join-Path $EvidenceRoot 'executed-tests.csv'
$rows | Select-Object check,status,execution_classification,started_utc,finished_utc,duration_ms,command,exit_code,assertion_or_criterion_count,count_basis,result_identity,pass_basis,candidate_head,candidate_tree,stdout_path,stdout_bytes,stdout_sha256,stderr_path,stderr_bytes,stderr_sha256 | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$humanLines = @(
    '# TSF V1 Final Acceptance Result',
    '',
    ('- Status: `{0}`' -f $status),
    ('- HEAD: `{0}`' -f $head),
    ('- Tree: `{0}`' -f $tree),
    ('- Git state: `{0}`' -f $gitState.classification),
    ('- Branch: `{0}`' -f $(if ($branch) { $branch } else { '<null>' })),
    "- Checks: $($rows.Count)",
    "- Failed: $(@($rows | Where-Object status -eq 'FAIL').Count)",
    "- Real app-server proof ran: $realProofRan",
    "- Final owner/listener/child cleanup: $cleanupPassed",
    '',
    '| Check | Status | Exit | Result identity |',
    '|---|---|---:|---|'
)
foreach ($row in $rows) { $humanLines += "| $($row.check) | $($row.status) | $($row.exit_code) | $($row.result_identity) |" }
$humanPath = Join-Path $EvidenceRoot 'acceptance-summary.md'
[IO.File]::WriteAllText($humanPath, ($humanLines -join "`n") + "`n", $utf8NoBom)

$indexRows = foreach ($file in Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File | Sort-Object FullName) {
    [pscustomobject]@{
        path = Get-RelativeEvidencePath $file.FullName
        bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$indexPath = Join-Path $EvidenceRoot 'evidence-index.csv'
$indexRows | Export-Csv -LiteralPath $indexPath -NoTypeInformation -Encoding UTF8

$summaryJson
if ($hasFailure -or (-not $SkipRealAppServerProof -and -not $realProofRan)) { exit 1 }
