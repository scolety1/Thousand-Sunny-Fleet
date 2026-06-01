function Get-FleetStage14RequiredStages {
    return 1..13
}

function Get-FleetStage14RequiredScenarios {
    return @(
        "happy_path_full_loop",
        "failed_build",
        "failed_tests",
        "dirty_unowned_repo",
        "active_owned_repo",
        "stale_lock",
        "missing_evidence",
        "invalid_task_packet",
        "stale_task_packet",
        "bad_external_audit_advice",
        "low_budget_safe_landing",
        "reset_eligible_resume",
        "taste_gate",
        "backend_sensitive_block",
        "formula_fixture_mismatch",
        "rollback_recovery_report",
        "morning_report",
        "mobile_request_rejection",
        "dashboard_control_room_summary",
        "mixed_mobile_overnight_safe_landing",
        "audit_package_failure_blocked_state",
        "stale_approval_after_budget_reset",
        "taste_gate_low_budget"
    )
}

function Get-FleetStage14EdgeCaseScenarios {
    return @(
        [pscustomobject]@{
            scenario = "mixed_mobile_overnight_safe_landing"
            category = "mixed-edge-case"
            evidence = "fixture:mixed-mobile-overnight-safe-landing"
            openRisk = "Mobile resume request arrives while overnight mode is safe-landing for low budget."
            requiredFix = "Reject execution, keep request-only mobile record, and show next captain action: wait for reset or inspect preview evidence."
        },
        [pscustomobject]@{
            scenario = "audit_package_failure_blocked_state"
            category = "mixed-edge-case"
            evidence = "fixture:audit-package-failure-blocked-state"
            openRisk = "Audit package creation fails while the ship is already blocked."
            requiredFix = "Contain the packaging failure per ship, do not rerun implementation, and report the blocked state plus package error."
        },
        [pscustomobject]@{
            scenario = "stale_approval_after_budget_reset"
            category = "mixed-edge-case"
            evidence = "fixture:stale-approval-after-budget-reset"
            openRisk = "A previously approved phone plan is replayed after budget reset."
            requiredFix = "Reject stale approval, require fresh local revalidation, and preserve the idempotency/expiry evidence."
        },
        [pscustomobject]@{
            scenario = "taste_gate_low_budget"
            category = "mixed-edge-case"
            evidence = "fixture:taste-gate-low-budget"
            openRisk = "A product-quality taste gate is reached while budget is low."
            requiredFix = "Stop implementation, keep preview/evidence available, and ask captain for taste direction after budget recovery."
        }
    )
}

function New-FleetStage14FixtureSuite {
    $fixtures = @(
        @("clean_ready_website", "READY", "RUN_AGAIN", "Disposable website fixture with clean repo."),
        @("dirty_unowned_ship", "BLOCKED", "BLOCK", "Dirty repo without ownership evidence."),
        @("active_running_ship", "RUNNING", "NOOP", "Active PID owns work; leave it alone."),
        @("build_failing_ship", "REPAIRING", "REPAIR", "Build gate failed with repair budget."),
        @("test_failing_ship", "REPAIRING", "REPAIR", "Test gate failed with repair budget."),
        @("audit_ready_ship", "AUDIT_READY", "WAIT_FOR_EXTERNAL_AUDIT", "Evidence package ready."),
        @("packet_ready_ship", "PACKET_READY", "WAIT_FOR_TASK_PACKET", "Validated packet evidence required."),
        @("rate_paused_ship", "RATE_LIMIT_PAUSED", "WAIT_FOR_RATE_RESET", "Safe landing/resume metadata."),
        @("taste_gated_ship", "TASTE_GATE", "USER_TASTE_GATE", "Deterministic gates passed; subjective choice remains."),
        @("backend_sensitive_blocked_ship", "BLOCKED", "BLOCK", "Auth/payment/deploy/package scope requires approval."),
        @("analytical_formula_blocked_ship", "BLOCKED", "BLOCK", "Formula fixture mismatch or missing golden values.")
    )

    return @($fixtures | ForEach-Object {
        [pscustomobject]@{
            fixture = $_[0]
            expectedState = $_[1]
            expectedDecision = $_[2]
            setup = $_[3]
            cleanup = "Disposable fixture only; remove only inside approved fixture root."
            mustNotTouch = @("real product repos", "user work", ".git", "locks", "secrets", "deploy config")
        }
    })
}

function Test-FleetStage14ReadinessInput {
    param([Parameter(Mandatory = $true)][object[]]$Checks)

    $missingStages = @()
    foreach ($stage in Get-FleetStage14RequiredStages) {
        if (@($Checks | Where-Object { [int]$_.stage -eq $stage }).Count -eq 0) {
            $missingStages += $stage
        }
    }

    $missingScenarios = @()
    foreach ($scenario in Get-FleetStage14RequiredScenarios) {
        if (@($Checks | Where-Object { [string]$_.scenario -eq $scenario }).Count -eq 0) {
            $missingScenarios += $scenario
        }
    }

    return [pscustomobject]@{
        valid = ($missingStages.Count -eq 0 -and $missingScenarios.Count -eq 0)
        missingStages = @($missingStages)
        missingScenarios = @($missingScenarios)
    }
}

function New-FleetStage14ReadinessScorecard {
    param(
        [Parameter(Mandatory = $true)][object[]]$Checks,
        [datetime]$GeneratedAt = (Get-Date)
    )

    $validation = Test-FleetStage14ReadinessInput -Checks $Checks
    $normalized = @()
    foreach ($check in @($Checks)) {
        $status = ([string]$check.status).Trim().ToUpperInvariant()
        if ($status -notin @("PASS", "PASS_WITH_FIXES", "FAIL")) {
            $status = "FAIL"
        }
        $normalized += [pscustomobject]@{
            stage = [int]$check.stage
            scenario = [string]$check.scenario
            category = [string]$check.category
            status = $status
            evidence = [string]$check.evidence
            openRisk = [string]$check.openRisk
            requiredFix = [string]$check.requiredFix
        }
    }

    $failCount = @($normalized | Where-Object { $_.status -eq "FAIL" }).Count
    $fixCount = @($normalized | Where-Object { $_.status -eq "PASS_WITH_FIXES" }).Count
    $verdict = "READY_FOR_CONTROLLED_USE"
    $status = "PASS"
    $next = "Create final external audit package."

    if (!$validation.valid) {
        $verdict = "NOT_READY"
        $status = "FAIL"
        $next = "Add missing stage/scenario evidence before final audit."
    } elseif ($failCount -gt 0) {
        $verdict = "NOT_READY"
        $status = "FAIL"
        $next = "Fix failed readiness checks before controlled use."
    } elseif ($fixCount -gt 0) {
        $verdict = "READY_WITH_LIMITS"
        $status = "PASS_WITH_FIXES"
        $next = "Proceed to final external audit with limits documented."
    }

    return [pscustomobject]@{
        schemaVersion = 1
        stage = "Golden Gameplan Stage 14"
        generatedAt = $GeneratedAt.ToUniversalTime().ToString("o")
        status = $status
        finalVerdict = $verdict
        checkCount = @($normalized).Count
        passCount = @($normalized | Where-Object { $_.status -eq "PASS" }).Count
        passWithFixesCount = $fixCount
        failCount = $failCount
        validation = $validation
        fixtureSuite = @(New-FleetStage14FixtureSuite)
        checks = @($normalized)
        forbiddenActions = @("real-product-failure-injection", "merge", "push", "deploy", "delete-user-work", "manual-lock-delete")
        nextCaptainAction = $next
    }
}

function New-FleetStage14MarkdownReport {
    param([Parameter(Mandatory = $true)][object]$Scorecard)

    $lines = @(
        "# Stage 14 Final Readiness Report",
        "",
        "Generated: $($Scorecard.generatedAt)",
        "",
        "## Verdict",
        "",
        "- Status: $($Scorecard.status)",
        "- Final verdict: $($Scorecard.finalVerdict)",
        "- Checks: $($Scorecard.checkCount)",
        "- PASS: $($Scorecard.passCount)",
        "- PASS_WITH_FIXES: $($Scorecard.passWithFixesCount)",
        "- FAIL: $($Scorecard.failCount)",
        "- Next: $($Scorecard.nextCaptainAction)",
        "",
        "## Missing Coverage",
        "",
        "- Missing stages: $((@($Scorecard.validation.missingStages) -join ', '))",
        "- Missing scenarios: $((@($Scorecard.validation.missingScenarios) -join ', '))",
        "",
        "## Scorecard",
        "",
        "| Stage | Scenario | Category | Status | Evidence | Risk / Fix |",
        "| ---: | --- | --- | --- | --- | --- |"
    )

    foreach ($check in @($Scorecard.checks | Sort-Object stage, scenario)) {
        $riskFix = @($check.openRisk, $check.requiredFix | Where-Object { ![string]::IsNullOrWhiteSpace($_) }) -join " / "
        $lines += "| $($check.stage) | $($check.scenario) | $($check.category) | $($check.status) | $($check.evidence) | $riskFix |"
    }

    $lines += @(
        "",
        "## Fixture Suite",
        "",
        "| Fixture | Expected State | Expected Decision | Must Not Touch |",
        "| --- | --- | --- | --- |"
    )

    foreach ($fixture in @($Scorecard.fixtureSuite)) {
        $lines += "| $($fixture.fixture) | $($fixture.expectedState) | $($fixture.expectedDecision) | $((@($fixture.mustNotTouch) -join ', ')) |"
    }

    $lines += @(
        "",
        "## Forbidden Actions",
        "",
        ($Scorecard.forbiddenActions | ForEach-Object { "- $_" })
    )

    return ($lines -join "`n")
}

function New-FleetStage14ExampleChecks {
    $checks = @()
    foreach ($stage in Get-FleetStage14RequiredStages) {
        $checks += [pscustomobject]@{
            stage = $stage
            scenario = "stage_${stage}_coverage"
            category = "stage-coverage"
            status = "PASS"
            evidence = "tests/run-fleet-tests.ps1"
            openRisk = ""
            requiredFix = ""
        }
    }
    foreach ($scenario in Get-FleetStage14RequiredScenarios) {
        $edgeCase = @(Get-FleetStage14EdgeCaseScenarios | Where-Object { [string]$_.scenario -eq [string]$scenario } | Select-Object -First 1)
        $checks += [pscustomobject]@{
            stage = 14
            scenario = $scenario
            category = if ($edgeCase.Count -gt 0) { [string]$edgeCase[0].category } else { "stress-scenario" }
            status = "PASS"
            evidence = if ($edgeCase.Count -gt 0) { [string]$edgeCase[0].evidence } else { "fixture:$scenario" }
            openRisk = if ($edgeCase.Count -gt 0) { [string]$edgeCase[0].openRisk } else { "" }
            requiredFix = if ($edgeCase.Count -gt 0) { [string]$edgeCase[0].requiredFix } else { "" }
        }
    }
    return $checks
}

function New-FleetControlledUseRehearsalChecks {
    $checks = @(New-FleetStage14ExampleChecks)
    $rehearsalEvidence = @{
        "dashboard_control_room_summary" = "controlled-use-rehearsal/status-control-room.json"
        "bad_external_audit_advice" = "controlled-use-rehearsal/audit-package-created.json"
        "mobile_request_rejection" = "controlled-use-rehearsal/mobile-request-capture.json"
        "invalid_task_packet" = "controlled-use-rehearsal/plan-approval-rejected.json"
        "low_budget_safe_landing" = "controlled-use-rehearsal/low-budget-safe-landing.json"
        "stale_lock" = "controlled-use-rehearsal/heartbeat-stale-classification.json"
        "rollback_recovery_report" = "controlled-use-rehearsal/no-op-rollback-report.md"
    }

    foreach ($check in @($checks)) {
        $scenario = [string]$check.scenario
        if ($rehearsalEvidence.ContainsKey($scenario)) {
            $check.category = "controlled-use-rehearsal"
            $check.evidence = $rehearsalEvidence[$scenario]
        }
    }

    return $checks
}
