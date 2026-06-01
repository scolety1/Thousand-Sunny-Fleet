function Get-FleetOvernightShortText {
    param(
        [string]$Text,
        [int]$MaxLength = 180
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $normalized = ($Text -replace "(`r`n|`n|`r)", " ") -replace "\s+", " "
    $normalized = $normalized.Trim()
    if ($normalized.Length -le $MaxLength) { return $normalized }
    return $normalized.Substring(0, [Math]::Max(0, $MaxLength - 3)) + "..."
}

function New-FleetOvernightContract {
    param(
        [int]$CheckCadenceMinutes = 20,
        [int]$LowBudgetThresholdPercent = 10,
        [int]$SafeLandingThresholdPercent = 3,
        [int]$WeeklyResetPauseThresholdPercent = 5,
        [int]$MaxShips = 1,
        [int]$MaxCyclesPerShip = 1,
        [int]$MaxRepairAttempts = 1,
        [int]$MaxResumeAttempts = 1,
        [string]$BudgetMode = "conservative"
    )

    return [pscustomobject]@{
        schemaVersion = 1
        mode = "overnight"
        selectedScopeRequired = $true
        checkCadenceMinutes = [Math]::Max(1, $CheckCadenceMinutes)
        lowBudgetThresholdPercent = [Math]::Max(0, $LowBudgetThresholdPercent)
        safeLandingThresholdPercent = [Math]::Max(0, $SafeLandingThresholdPercent)
        weeklyResetPauseThresholdPercent = [Math]::Max(0, $WeeklyResetPauseThresholdPercent)
        maxShips = [Math]::Max(1, $MaxShips)
        maxCyclesPerShip = [Math]::Max(1, $MaxCyclesPerShip)
        maxRepairAttempts = [Math]::Max(0, $MaxRepairAttempts)
        maxResumeAttempts = [Math]::Max(0, $MaxResumeAttempts)
        budgetMode = $BudgetMode
        forbiddenActions = @("merge", "push", "deploy", "delete-locks", "implicit-all-fleet")
    }
}

function Resolve-FleetRateGovernor {
    param(
        [double]$RemainingPercent = -1,
        [double]$WeeklyRemainingPercent = -1,
        [ValidateSet("unknown", "healthy", "cautious", "low", "critical", "exhausted", "reset_pending", "recovered")]
        [string]$ManualBudgetLevel = "unknown",
        [int]$LowBudgetThresholdPercent = 10,
        [int]$SafeLandingThresholdPercent = 3,
        [int]$WeeklyResetPauseThresholdPercent = 5,
        [datetime]$Now = (Get-Date),
        [datetime]$ResetAt = [datetime]::MinValue,
        [switch]$StopNewWork,
        [switch]$StatusOnlyMode
    )

    $source = "manual"
    $level = $ManualBudgetLevel
    $decision = "ALLOW_STATUS_ONLY"
    $reason = "Budget is unknown, so overnight mode stays conservative."
    $modelHeavyAllowed = $false
    $safeLandingRequired = $false

    if ($WeeklyRemainingPercent -ge 0 -and $WeeklyRemainingPercent -le $WeeklyResetPauseThresholdPercent) {
        $source = "configured_weekly_percent"
        $level = "weekly_low"
        $decision = "WEEKLY_PREVIEW_PAUSE"
        $reason = "Configured weekly budget is at or below the preview-pause threshold."
        $safeLandingRequired = $true
    } elseif ($RemainingPercent -ge 0) {
        $source = "configured_percent"
        if ($RemainingPercent -le 0) {
            $level = "exhausted"
            $decision = "WAIT_FOR_RESET"
            $reason = "Configured budget is exhausted."
        } elseif ($RemainingPercent -le $SafeLandingThresholdPercent) {
            $level = "critical"
            $decision = "SAFE_LAND_NOW"
            $reason = "Configured budget is at or below the safe-landing threshold."
            $safeLandingRequired = $true
        } elseif ($RemainingPercent -le $LowBudgetThresholdPercent) {
            $level = "low"
            $decision = "BLOCK_NEW_WORK"
            $reason = "Configured budget is low; new model-heavy work is blocked."
        } else {
            $level = "healthy"
            $decision = "ALLOW_RUN"
            $reason = "Configured budget is above the low-budget threshold."
            $modelHeavyAllowed = $true
        }
    } else {
        switch ($ManualBudgetLevel) {
            "healthy" { $decision = "ALLOW_RUN"; $reason = "Manual budget level is healthy."; $modelHeavyAllowed = $true }
            "recovered" { $decision = "ALLOW_RUN"; $reason = "Manual budget level is recovered."; $modelHeavyAllowed = $true }
            "cautious" { $decision = "ALLOW_STATUS_ONLY"; $reason = "Manual budget level is cautious; status-only checks are allowed." }
            "low" { $decision = "BLOCK_NEW_WORK"; $reason = "Manual budget level is low." }
            "critical" { $decision = "SAFE_LAND_NOW"; $reason = "Manual budget level is critical."; $safeLandingRequired = $true }
            "exhausted" { $decision = "WAIT_FOR_RESET"; $reason = "Manual budget level is exhausted." }
            "reset_pending" { $decision = "WAIT_FOR_RESET"; $reason = "Manual budget level is reset_pending." }
            default { $decision = "ALLOW_STATUS_ONLY"; $reason = "Budget level is unknown." }
        }
    }

    if ($StopNewWork) {
        $decision = "BLOCK_NEW_WORK"
        $modelHeavyAllowed = $false
        $reason = "Stop-new-work switch is active."
    }
    if ($StatusOnlyMode -and $decision -eq "ALLOW_RUN") {
        $decision = "ALLOW_STATUS_ONLY"
        $modelHeavyAllowed = $false
        $reason = "Status-only mode is active."
    }

    $resetStatus = "not_configured"
    if ($ResetAt -ne [datetime]::MinValue) {
        $resetStatus = if ($Now -ge $ResetAt) { "passed" } else { "pending" }
        if ($decision -eq "WAIT_FOR_RESET" -and $resetStatus -eq "passed") {
            $reason = "Reset window has passed, but resume still requires eligibility checks."
        }
    }

    return [pscustomobject]@{
        level = $level
        decision = $decision
        reason = $reason
        source = $source
        remainingPercent = if ($RemainingPercent -ge 0) { $RemainingPercent } else { $null }
        weeklyRemainingPercent = if ($WeeklyRemainingPercent -ge 0) { $WeeklyRemainingPercent } else { $null }
        lowBudgetThresholdPercent = $LowBudgetThresholdPercent
        safeLandingThresholdPercent = $SafeLandingThresholdPercent
        weeklyResetPauseThresholdPercent = $WeeklyResetPauseThresholdPercent
        modelHeavyAllowed = $modelHeavyAllowed
        safeLandingRequired = $safeLandingRequired
        resetAt = if ($ResetAt -ne [datetime]::MinValue) { $ResetAt.ToUniversalTime().ToString("o") } else { "" }
        resetStatus = $resetStatus
    }
}

function New-FleetModelBudgetState {
    param(
        [double]$CurrentRemainingPercent = -1,
        [double]$ForecastRemainingPercent = -1,
        [double]$WeeklyRemainingPercent = -1,
        [int]$ForecastWarningThresholdPercent = 20,
        [int]$LowBudgetThresholdPercent = 10,
        [int]$SafeLandingThresholdPercent = 3,
        [int]$WeeklyResetPauseThresholdPercent = 5,
        [ValidateSet("implementation", "repair", "status", "audit", "taste", "backend-sensitive", "maintenance")]
        [string]$TaskClass = "implementation",
        [switch]$ManualLowTokenMode,
        [switch]$ResetConfirmed
    )

    $signals = [System.Collections.Generic.List[string]]::new()
    $level = "unknown"
    $decision = "STATUS_ONLY"
    $reason = "Budget is unknown; stay conservative."
    $implementationAllowed = $false
    $statusAllowed = $true
    $resumeAfterReset = $false
    $maxConcurrentShips = 1
    $modelTier = "cheap-status"

    if ($ForecastRemainingPercent -ge 0 -and $ForecastRemainingPercent -le $ForecastWarningThresholdPercent) {
        $signals.Add("FORECAST_WARNING") | Out-Null
    }
    if ($WeeklyRemainingPercent -ge 0 -and $WeeklyRemainingPercent -le $WeeklyResetPauseThresholdPercent) {
        $signals.Add("WEEKLY_RESET_PREVIEW_PAUSE") | Out-Null
    }
    if ($CurrentRemainingPercent -ge 0) {
        if ($CurrentRemainingPercent -le 0) {
            $signals.Add("HARD_STOP_IMMINENT") | Out-Null
        } elseif ($CurrentRemainingPercent -le $SafeLandingThresholdPercent) {
            $signals.Add("SAFE_LANDING") | Out-Null
        } elseif ($CurrentRemainingPercent -le $LowBudgetThresholdPercent) {
            $signals.Add("ACTUAL_THRESHOLD_WARNING") | Out-Null
        }
    }
    if ($ManualLowTokenMode) {
        $signals.Add("MANUAL_LOW_TOKEN_MODE") | Out-Null
    }

    if (@($signals) -contains "HARD_STOP_IMMINENT") {
        $level = "exhausted"
        $decision = "WAIT_FOR_RESET"
        $reason = "Current budget is exhausted or at hard stop."
        $statusAllowed = $true
    } elseif (@($signals) -contains "WEEKLY_RESET_PREVIEW_PAUSE") {
        $level = "weekly_low"
        $decision = "WEEKLY_PREVIEW_PAUSE"
        $reason = "Weekly budget is at or below preview-pause threshold."
    } elseif (@($signals) -contains "SAFE_LANDING") {
        $level = "critical"
        $decision = "SAFE_LAND_NOW"
        $reason = "Current budget is at or below safe-landing threshold."
    } elseif (@($signals) -contains "ACTUAL_THRESHOLD_WARNING" -or @($signals) -contains "MANUAL_LOW_TOKEN_MODE") {
        $level = "low"
        $decision = "BLOCK_IMPLEMENTATION"
        $reason = "Current budget is low or manual low-token mode is active."
    } elseif (@($signals) -contains "FORECAST_WARNING") {
        $level = "cautious"
        $decision = "STATUS_AND_LIGHT_REPAIR_ONLY"
        $reason = "Forecast says budget may run low before the next check."
    } elseif ($CurrentRemainingPercent -ge 0 -or $ForecastRemainingPercent -ge 0 -or $WeeklyRemainingPercent -ge 0) {
        $level = "healthy"
        $decision = "ALLOW_BOUNDED_RUN"
        $reason = "Budget state is above configured thresholds."
        $implementationAllowed = $true
        $maxConcurrentShips = 2
        $modelTier = "balanced"
    }

    if ($TaskClass -in @("status", "audit", "maintenance") -and $decision -in @("STATUS_ONLY", "STATUS_AND_LIGHT_REPAIR_ONLY", "BLOCK_IMPLEMENTATION")) {
        $modelTier = "cheap-status"
    } elseif ($TaskClass -eq "repair" -and $decision -eq "STATUS_AND_LIGHT_REPAIR_ONLY") {
        $modelTier = "cheap-repair"
    } elseif ($TaskClass -in @("taste", "backend-sensitive")) {
        $modelTier = "premium-review-only"
        if ($decision -ne "ALLOW_BOUNDED_RUN") {
            $implementationAllowed = $false
        }
    }

    if ($ResetConfirmed -and $decision -in @("WAIT_FOR_RESET", "WEEKLY_PREVIEW_PAUSE")) {
        $resumeAfterReset = $true
        $reason = "Reset is confirmed; resume still requires explicit ship eligibility and bounded approval."
    }

    return [pscustomobject]@{
        level = $level
        decision = $decision
        reason = $reason
        signals = @($signals)
        currentRemainingPercent = if ($CurrentRemainingPercent -ge 0) { $CurrentRemainingPercent } else { $null }
        forecastRemainingPercent = if ($ForecastRemainingPercent -ge 0) { $ForecastRemainingPercent } else { $null }
        weeklyRemainingPercent = if ($WeeklyRemainingPercent -ge 0) { $WeeklyRemainingPercent } else { $null }
        thresholds = [pscustomobject]@{
            forecastWarningPercent = $ForecastWarningThresholdPercent
            lowBudgetPercent = $LowBudgetThresholdPercent
            safeLandingPercent = $SafeLandingThresholdPercent
            weeklyResetPausePercent = $WeeklyResetPauseThresholdPercent
        }
        taskClass = $TaskClass
        modelTier = $modelTier
        maxConcurrentShips = $maxConcurrentShips
        implementationAllowed = $implementationAllowed
        statusAllowed = $statusAllowed
        resumeAfterReset = $resumeAfterReset
        manualLowTokenMode = [bool]$ManualLowTokenMode
        productLaunchAllowed = $false
        requiresExplicitShipSelection = $true
    }
}

function New-FleetWeeklyResetPreviewPlan {
    param(
        [object[]]$Ships,
        [datetime]$ResetAt = [datetime]::MinValue,
        [string]$PreviewReportPath = "",
        [string]$BugDocPath = ""
    )

    $unfinished = @($Ships | Where-Object {
        $status = ([string]$($_.state)).ToUpperInvariant()
        $action = ([string]$($_.action)).ToUpperInvariant()
        ($status -in @("READY", "RUNNING", "REVIEWING", "REPAIRING", "QUARANTINED")) -or
            ($action -in @("PAUSE_FOR_WEEKLY_PREVIEW", "SAFE_LANDING", "BLOCK_NEW_WORK"))
    })

    return [pscustomobject]@{
        state = "WEEKLY_RESET_PREVIEW_PAUSE"
        resetAt = if ($ResetAt -ne [datetime]::MinValue) { $ResetAt.ToUniversalTime().ToString("o") } else { "" }
        holdPreviewUntilReset = $true
        previewAction = "KEEP_PREVIEW_AVAILABLE"
        captainInspectionDoc = if (![string]::IsNullOrWhiteSpace($BugDocPath)) { $BugDocPath } else { "docs/codex/WEEKLY_RESET_REVIEW_NOTES.md" }
        previewReportPath = $PreviewReportPath
        unfinishedShips = @($unfinished | ForEach-Object {
            [pscustomobject]@{
                ship = $_.ship
                state = $_.state
                action = $_.action
                reason = $_.reason
            }
        })
        nextCaptainAction = "Inspect the held preview, write bugs/errors in the review notes doc, then resume only after weekly reset recovery is confirmed."
    }
}

function New-FleetSafeLandingPlan {
    param(
        [string[]]$SelectedShips,
        [Parameter(Mandatory = $true)][object]$Governor,
        [datetime]$PausedAt = (Get-Date),
        [int]$MaxResumeAttempts = 1,
        [int]$ResumeAttemptsUsed = 0,
        [string]$EvidencePath = ""
    )

    $ships = @($SelectedShips | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    return [pscustomobject]@{
        state = "RATE_LIMIT_PAUSED"
        pausedAt = $PausedAt.ToUniversalTime().ToString("o")
        pauseReason = $Governor.reason
        budgetLevelAtPause = $Governor.level
        selectedShips = $ships
        resumableShips = $ships
        nonResumableShips = @()
        lastDecision = $Governor.decision
        lastSafeAction = "SAFE_LANDING"
        lastEvidencePath = $EvidencePath
        maxResumeAttempts = [Math]::Max(0, $MaxResumeAttempts)
        resumeAttemptsUsed = [Math]::Max(0, $ResumeAttemptsUsed)
    }
}

function Resolve-FleetHeartbeatLeaseRecovery {
    param(
        [datetime]$Now = (Get-Date),
        [datetime]$HeartbeatAt = [datetime]::MinValue,
        [datetime]$LeaseExpiresAt = [datetime]::MinValue,
        [string]$LeaseOwner = "",
        [ValidateSet("none", "transient", "deterministic", "environment", "policy", "ambiguous")]
        [string]$FailureSignal = "none",
        [int]$StaleHeartbeatMinutes = 15
    )

    $heartbeatKnown = $HeartbeatAt -ne [datetime]::MinValue
    $leaseKnown = $LeaseExpiresAt -ne [datetime]::MinValue
    $heartbeatAgeMinutes = if ($heartbeatKnown) { [Math]::Round(($Now.ToUniversalTime() - $HeartbeatAt.ToUniversalTime()).TotalMinutes, 2) } else { $null }
    $heartbeatState = if (!$heartbeatKnown) {
        "missing"
    } elseif ($heartbeatAgeMinutes -gt $StaleHeartbeatMinutes) {
        "stale"
    } else {
        "fresh"
    }
    $leaseState = if (!$leaseKnown) {
        "missing"
    } elseif ($Now.ToUniversalTime() -lt $LeaseExpiresAt.ToUniversalTime()) {
        "active"
    } else {
        "expired"
    }

    $recoveryClass = "transient"
    $decision = "RECOVER_WITH_BACKOFF"
    $nextAction = "Detect, classify, recover with bounded backoff, then learn from evidence."
    $reviewRequired = $false

    switch ($FailureSignal) {
        "deterministic" {
            $recoveryClass = "deterministic-code-defect"
            $decision = "STOP_FOR_REPAIR"
            $nextAction = "Do not retry automatically. Write a bounded repair task with evidence."
            $reviewRequired = $true
        }
        "environment" {
            $recoveryClass = "environment-fault"
            $decision = "WAIT_FOR_ENVIRONMENT"
            $nextAction = "Wait for environment or dependency recovery before retrying."
        }
        "policy" {
            $recoveryClass = "policy-failure"
            $decision = "BLOCK_FOR_POLICY_REVIEW"
            $nextAction = "Stop and require captain approval or scope correction."
            $reviewRequired = $true
        }
        "ambiguous" {
            $recoveryClass = "ambiguous-state"
            $decision = "REQUIRE_REVIEW"
            $nextAction = "Do not resume ambiguous state without review."
            $reviewRequired = $true
        }
    }

    if ($leaseState -eq "active" -and $heartbeatState -eq "fresh" -and $FailureSignal -eq "none") {
        $recoveryClass = "active-with-child-work"
        $decision = "LEAVE_RUNNING"
        $nextAction = "Leave the active owner alone."
    } elseif ($leaseState -eq "active" -and $heartbeatState -eq "stale") {
        $recoveryClass = "ambiguous-state"
        $decision = "REQUIRE_REVIEW"
        $nextAction = "Heartbeat is stale but lease is active; do not delete locks or resume automatically."
        $reviewRequired = $true
    } elseif ($leaseState -eq "expired" -and $heartbeatState -eq "stale" -and $FailureSignal -eq "none") {
        $recoveryClass = "transient"
        $decision = "RECOVER_WITH_BACKOFF"
        $nextAction = "Lease expired and heartbeat is stale; schedule one bounded recovery attempt."
    } elseif ($leaseState -eq "missing" -and $heartbeatState -eq "missing") {
        $recoveryClass = "ambiguous-state"
        $decision = "REQUIRE_REVIEW"
        $nextAction = "No heartbeat or lease evidence exists; require review before resume."
        $reviewRequired = $true
    }

    return [pscustomobject]@{
        heartbeatState = $heartbeatState
        heartbeatAgeMinutes = $heartbeatAgeMinutes
        leaseState = $leaseState
        leaseOwner = $LeaseOwner
        recoveryClass = $recoveryClass
        decision = $decision
        nextAction = $nextAction
        reviewRequired = $reviewRequired
        invariant = "detect -> classify -> recover -> learn"
        deletesLocks = $false
        blindRetryAllowed = ($decision -eq "RECOVER_WITH_BACKOFF")
    }
}

function New-FleetLeaseHeartbeatClassification {
    param(
        [string]$ShipId = "FixtureShip",
        [string]$LeaseId = "lease-fixture",
        [string]$Owner = "worker-fixture",
        [string]$ExpectedOwner = "",
        [string]$FenceToken = "fence-fixture",
        [string]$ExpectedFenceToken = "",
        [datetime]$Now = (Get-Date),
        [datetime]$HeartbeatAt = [datetime]::MinValue,
        [datetime]$LeaseCreatedAt = [datetime]::MinValue,
        [datetime]$LeaseExpiresAt = [datetime]::MinValue,
        [ValidateSet("none", "deterministic", "environment", "policy")]
        [string]$FailureSignal = "none",
        [int]$StaleHeartbeatMinutes = 15,
        [string[]]$EvidenceRefs = @()
    )

    $utcNow = $Now.ToUniversalTime()
    $heartbeatKnown = $HeartbeatAt -ne [datetime]::MinValue
    $leaseCreatedKnown = $LeaseCreatedAt -ne [datetime]::MinValue
    $leaseKnown = $LeaseExpiresAt -ne [datetime]::MinValue
    $heartbeatAgeMinutes = if ($heartbeatKnown) { [Math]::Round(($utcNow - $HeartbeatAt.ToUniversalTime()).TotalMinutes, 2) } else { 0 }
    $clockSkewSuspicion = $false
    if ($heartbeatKnown -and $HeartbeatAt.ToUniversalTime() -gt $utcNow.AddMinutes(1)) { $clockSkewSuspicion = $true }
    if ($leaseCreatedKnown -and $LeaseCreatedAt.ToUniversalTime() -gt $utcNow.AddMinutes(1)) { $clockSkewSuspicion = $true }
    if ($leaseCreatedKnown -and $leaseKnown -and $LeaseExpiresAt.ToUniversalTime() -lt $LeaseCreatedAt.ToUniversalTime()) { $clockSkewSuspicion = $true }
    if ($heartbeatAgeMinutes -lt 0) { $heartbeatAgeMinutes = 0 }

    $heartbeatState = if (!$heartbeatKnown) {
        "missing"
    } elseif ($heartbeatAgeMinutes -gt $StaleHeartbeatMinutes) {
        "stale"
    } else {
        "fresh"
    }
    $leaseState = if (!$leaseKnown) {
        "missing"
    } elseif ($utcNow -lt $LeaseExpiresAt.ToUniversalTime()) {
        "active"
    } else {
        "expired"
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $validationStatus = "valid"
    if ([string]::IsNullOrWhiteSpace($Owner)) {
        $validationStatus = "invalid"
        $reasons.Add("owner-required") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($FenceToken)) {
        $validationStatus = "invalid"
        $reasons.Add("fence-token-required") | Out-Null
    }

    $ownerMismatch = (![string]::IsNullOrWhiteSpace($ExpectedOwner) -and $ExpectedOwner -ne $Owner)
    $fenceMismatch = (![string]::IsNullOrWhiteSpace($ExpectedFenceToken) -and $ExpectedFenceToken -ne $FenceToken)
    if ($ownerMismatch -or $fenceMismatch) {
        $heartbeatState = "ambiguous"
        $leaseState = "ambiguous"
        $reasons.Add("ambiguous") | Out-Null
        $reasons.Add("review-required") | Out-Null
        if ($fenceMismatch) { $reasons.Add("fence-token-mismatch") | Out-Null }
    }
    if ($clockSkewSuspicion) {
        $heartbeatState = "ambiguous"
        $leaseState = "ambiguous"
        $reasons.Add("ambiguous") | Out-Null
        $reasons.Add("clock-skew-suspicion") | Out-Null
        $reasons.Add("review-required") | Out-Null
        if ($validationStatus -eq "valid") { $validationStatus = "unknown" }
    }

    $recoveryClass = "ambiguous"
    $decision = "REQUIRE_REVIEW"
    if ($FailureSignal -eq "deterministic") {
        $recoveryClass = "deterministic-failure"
        $decision = "STOP_FOR_REPAIR"
        $reasons.Add("deterministic-failure") | Out-Null
        $reasons.Add("review-required") | Out-Null
    } elseif ($FailureSignal -eq "environment") {
        $recoveryClass = "environment-fault"
        $decision = "WAIT_FOR_ENVIRONMENT"
        $reasons.Add("review-required") | Out-Null
    } elseif ($FailureSignal -eq "policy") {
        $recoveryClass = "policy-failure"
        $decision = "BLOCK_FOR_POLICY_REVIEW"
        $reasons.Add("review-required") | Out-Null
    } elseif ($ownerMismatch -or $fenceMismatch -or $clockSkewSuspicion -or $leaseState -eq "ambiguous" -or $heartbeatState -eq "ambiguous") {
        $recoveryClass = "ambiguous"
        $decision = "REQUIRE_REVIEW"
    } elseif ($leaseState -eq "active" -and $heartbeatState -eq "fresh") {
        $recoveryClass = "fresh"
        $decision = "LEAVE_RUNNING"
        $reasons.Add("fresh") | Out-Null
    } elseif ($leaseState -eq "active" -and $heartbeatState -eq "stale") {
        $recoveryClass = "stale"
        $decision = "REQUIRE_REVIEW"
        $reasons.Add("stale") | Out-Null
        $reasons.Add("ambiguous") | Out-Null
        $reasons.Add("review-required") | Out-Null
    } elseif ($leaseState -eq "expired" -and $heartbeatState -eq "stale") {
        $recoveryClass = "expired"
        $decision = "RECOVER_WITH_BACKOFF"
        $reasons.Add("expired") | Out-Null
        $reasons.Add("stale") | Out-Null
    } else {
        $recoveryClass = "ambiguous"
        $decision = "REQUIRE_REVIEW"
        $reasons.Add("ambiguous") | Out-Null
        $reasons.Add("review-required") | Out-Null
    }

    $reasons.Add("lock-deletion-forbidden") | Out-Null
    $heartbeatAtText = if ($heartbeatKnown) { $HeartbeatAt.ToUniversalTime().ToString("o") } else { $utcNow.ToString("o") }
    $leaseCreatedAtText = if ($leaseCreatedKnown) { $LeaseCreatedAt.ToUniversalTime().ToString("o") } else { $utcNow.ToString("o") }
    $leaseExpiresAtText = if ($leaseKnown) { $LeaseExpiresAt.ToUniversalTime().ToString("o") } else { $utcNow.ToString("o") }

    return [pscustomobject]@{
        schemaVersion = 1
        leaseId = $LeaseId
        shipId = $ShipId
        owner = $Owner
        fenceToken = $FenceToken
        heartbeatAt = $heartbeatAtText
        heartbeatAgeMinutes = $heartbeatAgeMinutes
        heartbeatState = $heartbeatState
        leaseCreatedAt = $leaseCreatedAtText
        leaseExpiresAt = $leaseExpiresAtText
        leaseState = $leaseState
        recoveryClass = $recoveryClass
        decision = $decision
        deletesLocks = $false
        evidenceRefs = @($EvidenceRefs)
        validation = [pscustomobject]@{
            status = $validationStatus
            reasons = @($reasons | Select-Object -Unique)
        }
    }
}

function Test-FleetOvernightResumeEligibility {
    param(
        [Parameter(Mandatory = $true)][object]$ShipState,
        [Parameter(Mandatory = $true)][object]$ResumeMetadata,
        [Parameter(Mandatory = $true)][object]$Governor,
        [string]$ShipName = "",
        [switch]$AllowConfiguredResetResume
    )

    $shipName = if (![string]::IsNullOrWhiteSpace($ShipName)) { $ShipName } else { [string]$($ShipState.ship) }
    $status = ([string]$($ShipState.status)).ToUpperInvariant()
    $reasons = @()

    if (@($ResumeMetadata.resumableShips) -notcontains $shipName) { $reasons += "Ship was not in the original resumable set." }
    if ($status -in @("TASTE_GATE", "BLOCKED", "ARCHIVED", "PARKED")) { $reasons += "Ship state $status is not auto-resumable." }
    if ($null -ne $ShipState.repoClean -and ![bool]$ShipState.repoClean) { $reasons += "Repo is not clean/owned for resume." }
    if ([int]$ResumeMetadata.resumeAttemptsUsed -ge [int]$ResumeMetadata.maxResumeAttempts) { $reasons += "Max resume attempts reached." }

    $budgetRecovered = $Governor.level -in @("healthy", "recovered") -and $Governor.decision -in @("ALLOW_RUN", "ALLOW_STATUS_ONLY")
    $configuredWindowPassed = $AllowConfiguredResetResume -and $Governor.resetStatus -eq "passed"
    if (!$budgetRecovered -and !$configuredWindowPassed) {
        $reasons += "Budget is not confirmed recovered and no approved configured reset window has passed."
    }
    if ($configuredWindowPassed -and !$budgetRecovered -and $Governor.source -ne "manual") {
        $reasons += "Configured reset resume must stay conservative unless manual/configured source is explicit."
    }

    return [pscustomobject]@{
        ship = $shipName
        eligible = ($reasons.Count -eq 0)
        reasons = $reasons
        nextAction = if ($reasons.Count -eq 0) { "AUTO_RESUME_READY" } else { "DO_NOT_RESUME" }
    }
}

function New-FleetOvernightMorningReport {
    param(
        [Parameter(Mandatory = $true)][object]$Result
    )

    $lines = @(
        "# Stage 10 Overnight Report",
        "",
        "## Captain Summary",
        "",
        "- Status: $($Result.status)",
        "- Governor: $($Result.governor.level) -> $($Result.governor.decision)",
        "- Selected ships: $(@($Result.selectedShips).Count)",
        "- Safe landing: $([bool]$Result.safeLanding)",
        "- Weekly preview pause: $([bool]$Result.weeklyPreviewPause)",
        "- Auto-resume ready: $(@($Result.resumeEligibility | Where-Object { $_.eligible }).Count)",
        "- Next: $($Result.nextCaptainAction)",
        "",
        "## Ship Outcomes",
        "",
        "| Ship | Overnight action | Resume | Reason |",
        "| --- | --- | --- | --- |"
    )

    foreach ($ship in @($Result.ships)) {
        $resume = @($Result.resumeEligibility | Where-Object { $_.ship -eq $ship.ship } | Select-Object -First 1)
        $resumeText = if ($resume.Count -gt 0) { $resume[0].nextAction } else { "N/A" }
        $reason = if ($resume.Count -gt 0 -and @($resume[0].reasons).Count -gt 0) { ($resume[0].reasons -join "; ") } else { $ship.reason }
        $lines += "| $($ship.ship) | $($ship.action) | $resumeText | $(Get-FleetOvernightShortText -Text $reason -MaxLength 160) |"
    }

    $lines += @(
        "",
        "## Evidence",
        "",
        "- JSON report: $($Result.jsonReportPath)",
        "- Markdown report: $($Result.reportPath)",
        "- Resume metadata: $($Result.resumeMetadataPath)",
        "- Weekly preview plan: $($Result.weeklyPreviewPlanPath)",
        "",
        "## Limits",
        "",
        "- This Stage 10 wrapper does not create phone commands.",
        "- This Stage 10 wrapper does not schedule real overnight automations in tests.",
        "- Product ships remain denied unless explicitly selected by a later approved run."
    )

    return ($lines -join "`n")
}
