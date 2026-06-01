function Get-FleetDecisionValues {
    return @(
        "NOOP",
        "RUN_AGAIN",
        "REPAIR",
        "PACKAGE_AUDIT",
        "WAIT_FOR_EXTERNAL_AUDIT",
        "WAIT_FOR_TASK_PACKET",
        "USER_TASTE_GATE",
        "WAIT_FOR_RATE_RESET",
        "PARK",
        "BLOCK",
        "ARCHIVE"
    )
}

function Test-FleetDecisionValue {
    param([Parameter(Mandatory = $true)][string]$Decision)
    return ((Get-FleetDecisionValues) -contains $Decision.ToUpperInvariant())
}

function New-FleetDecisionInput {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Nullable[bool]]$RepoClean = $null,
        [bool]$ActiveWorkOwned = $false,
        [int]$ValidTasksRemaining = -1,
        [string]$DeterministicGateStatus = "unknown",
        [string]$VisualGateStatus = "unknown",
        [string]$CopyGateStatus = "unknown",
        [string]$FormulaGateStatus = "unknown",
        [bool]$AuditPackageReady = $false,
        [bool]$ExternalPacketPending = $false,
        [bool]$AcceptedPacketReady = $false,
        [bool]$RateLimitPaused = $false,
        [bool]$ExplicitStopRequested = $false,
        [bool]$ExplicitArchiveRequested = $false,
        [bool]$RepairPathAvailable = $false,
        [bool]$BudgetRemaining = $true,
        [bool]$MaterialProgressOrPacket = $false,
        [bool]$DoneEnough = $false,
        [bool]$TasteGateRequired = $false,
        [string[]]$Blockers = @(),
        [string]$EvidenceFreshness = "unknown",
        [string[]]$Evidence = @()
    )

    $stateName = ([string]$State.status).ToUpperInvariant()
    $tasksRemaining = if ($null -ne $State.tasksRemaining) { [int]$State.tasksRemaining } else { 0 }
    if ($ValidTasksRemaining -lt 0) { $ValidTasksRemaining = $tasksRemaining }
    if ($null -eq $RepoClean -and $null -ne $State.repoClean) { $RepoClean = [bool]$State.repoClean }
    if (!$AuditPackageReady) { $AuditPackageReady = ![string]::IsNullOrWhiteSpace([string]$State.lastAuditPackagePath) }
    if (!$AcceptedPacketReady) { $AcceptedPacketReady = ![string]::IsNullOrWhiteSpace([string]$State.lastTaskPacketPath) }
    if (!$RateLimitPaused) { $RateLimitPaused = ($stateName -eq "RATE_LIMIT_PAUSED") }
    if (!$TasteGateRequired) { $TasteGateRequired = ($stateName -eq "TASTE_GATE") }
    if (!$ExplicitArchiveRequested) { $ExplicitArchiveRequested = ($stateName -eq "ARCHIVED") }
    $stateBlockers = @($State.blockers | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    $allBlockers = @($Blockers + $stateBlockers | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $stateEvidence = @($State.evidence | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    $allEvidence = @($Evidence + $stateEvidence | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    return [pscustomobject]@{
        ship = [string]$State.ship
        state = $stateName
        repoClean = $RepoClean
        activeWorkOwned = ($ActiveWorkOwned -or $stateName -eq "RUNNING")
        tasksRemaining = $tasksRemaining
        validTasksRemaining = $ValidTasksRemaining
        quarantinedTasks = if ($null -ne $State.quarantinedTasks) { [int]$State.quarantinedTasks } else { 0 }
        deterministicGateStatus = $DeterministicGateStatus
        visualGateStatus = $VisualGateStatus
        copyGateStatus = $CopyGateStatus
        formulaGateStatus = $FormulaGateStatus
        auditPackageReady = $AuditPackageReady
        externalPacketPending = $ExternalPacketPending
        acceptedPacketReady = $AcceptedPacketReady
        rateLimitPaused = $RateLimitPaused
        explicitStopRequested = $ExplicitStopRequested
        explicitArchiveRequested = $ExplicitArchiveRequested
        repairPathAvailable = $RepairPathAvailable
        budgetRemaining = $BudgetRemaining
        materialProgressOrPacket = ($MaterialProgressOrPacket -or $AcceptedPacketReady)
        doneEnough = $DoneEnough
        tasteGateRequired = $TasteGateRequired
        blockers = @($allBlockers)
        evidenceFreshness = $EvidenceFreshness
        evidence = @($allEvidence)
    }
}

function New-FleetDecision {
    param(
        [Parameter(Mandatory = $true)][string]$Ship,
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][string]$Decision,
        [Parameter(Mandatory = $true)][string]$Reason,
        [string]$Confidence = "medium",
        [string[]]$Evidence = @(),
        [string]$RequiredHumanAction = "",
        [string[]]$AllowedNextCommands = @(),
        [string[]]$ForbiddenNextCommands = @("merge", "push", "deploy", "delete locks", "touch product repos"),
        [string]$BudgetNotes = "",
        [string]$SafetyNotes = ""
    )

    $normalizedDecision = $Decision.ToUpperInvariant()
    if (!(Test-FleetDecisionValue -Decision $normalizedDecision)) { throw "Invalid fleet decision: $Decision" }
    return [pscustomobject]@{
        schemaVersion = 1
        ship = $Ship
        state = $State
        decision = $normalizedDecision
        reason = $Reason
        confidence = $Confidence
        evidence = @($Evidence)
        requiredHumanAction = $RequiredHumanAction
        allowedNextCommands = @($AllowedNextCommands)
        forbiddenNextCommands = @($ForbiddenNextCommands)
        budgetNotes = $BudgetNotes
        safetyNotes = $SafetyNotes
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Resolve-FleetDecision {
    param([Parameter(Mandatory = $true)][Alias("Input")][object]$DecisionInput)

    $state = ([string]$DecisionInput.state).ToUpperInvariant()
    $failedDeterministic = ([string]$DecisionInput.deterministicGateStatus -match "(?i)fail|red|blocked")
    $unknownEvidence = ([string]$DecisionInput.evidenceFreshness -eq "unknown" -and $state -eq "UNKNOWN")
    $commonEvidence = @($DecisionInput.evidence)

    if ($DecisionInput.explicitArchiveRequested -or $state -eq "ARCHIVED") {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "ARCHIVE" -Reason "Ship is explicitly archived." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Leave archived unless the captain reactivates it."
    }
    if ($DecisionInput.activeWorkOwned -or $state -eq "RUNNING") {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "NOOP" -Reason "Active owned work is present; do not touch the repo." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Let active work continue or request a safe stop later."
    }
    if ($DecisionInput.explicitStopRequested) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "PARK" -Reason "Explicit stop/park request is present and no active owned work is running." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Inspect parked evidence before any new launch."
    }
    if (@($DecisionInput.blockers).Count -gt 0 -and !$DecisionInput.repairPathAvailable) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "BLOCK" -Reason ("Blocking evidence: " + (@($DecisionInput.blockers) -join "; ")) -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Resolve blocker before running again."
    }
    if ($DecisionInput.rateLimitPaused -or $state -eq "RATE_LIMIT_PAUSED") {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "WAIT_FOR_RATE_RESET" -Reason "Rate-limit pause or low-budget state is active." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Wait for reset/budget evidence; do not auto-resume in Stage 6." -BudgetNotes "Stage 6 records the wait decision only."
    }
    if ($DecisionInput.quarantinedTasks -gt 0 -or ($failedDeterministic -and $DecisionInput.repairPathAvailable) -or $state -eq "REPAIRING") {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "REPAIR" -Reason "Deterministic failure or quarantined work has a bounded repair path." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Review/approve repair task; Stage 6 does not execute it."
    }
    if ($failedDeterministic -or $state -eq "BLOCKED" -or $unknownEvidence) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "BLOCK" -Reason "Deterministic failure, blocked state, or unknown evidence prevents safe progress." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Human review required before more work."
    }
    if ($state -eq "REVIEWING" -and !$DecisionInput.auditPackageReady) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "PACKAGE_AUDIT" -Reason "Run is in review and needs an audit package before new planning." -Confidence "medium" -Evidence $commonEvidence -RequiredHumanAction "Create or review an audit package."
    }
    if (($state -eq "AUDIT_READY" -or $DecisionInput.auditPackageReady) -and !$DecisionInput.acceptedPacketReady) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "WAIT_FOR_EXTERNAL_AUDIT" -Reason "Audit evidence exists and no accepted task packet is ready." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Send audit package or wait for external review."
    }
    if ($DecisionInput.tasteGateRequired -or $state -eq "TASTE_GATE") {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "USER_TASTE_GATE" -Reason "Deterministic gates can pass, but remaining work is subjective taste." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Captain should choose taste direction or approve a task packet."
    }
    if ($state -eq "PARKED" -or ($DecisionInput.doneEnough -and $DecisionInput.validTasksRemaining -eq 0 -and $DecisionInput.repoClean)) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "PARK" -Reason "Ship is intentionally idle or done enough with no valid tasks remaining." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Leave parked until new approved work exists."
    }
    if ($DecisionInput.validTasksRemaining -le 0 -and !$DecisionInput.acceptedPacketReady) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "WAIT_FOR_TASK_PACKET" -Reason "No valid tasks remain and no accepted packet is ready." -Confidence "medium" -Evidence $commonEvidence -RequiredHumanAction "Provide or import a valid task packet."
    }
    if (($state -eq "READY" -or $state -eq "PACKET_READY") -and $DecisionInput.repoClean -and $DecisionInput.validTasksRemaining -gt 0 -and $DecisionInput.budgetRemaining -and $DecisionInput.materialProgressOrPacket -and $DecisionInput.quarantinedTasks -eq 0) {
        return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "RUN_AGAIN" -Reason "Ship is clean, has valid tasks, budget remains, and progress/new packet evidence exists." -Confidence "high" -Evidence $commonEvidence -RequiredHumanAction "Stage 8+ may execute one bounded run; Stage 6 only recommends." -AllowedNextCommands @("bounded run after captain/stage approval") -BudgetNotes "Budget remaining is true in normalized input."
    }
    return New-FleetDecision -Ship $DecisionInput.ship -State $state -Decision "BLOCK" -Reason "No safe decision path matched; conservative block." -Confidence "medium" -Evidence $commonEvidence -RequiredHumanAction "Inspect normalized input and add missing evidence."
}
