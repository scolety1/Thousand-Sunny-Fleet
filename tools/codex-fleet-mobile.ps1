function Get-FleetMobileShortText {
    param(
        [string]$Text,
        [int]$MaxLength = 220
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $normalized = ($Text -replace "(`r`n|`n|`r)", " ") -replace "\s+", " "
    $normalized = $normalized.Trim()
    if ($normalized.Length -le $MaxLength) { return $normalized }
    return $normalized.Substring(0, [Math]::Max(0, $MaxLength - 3)) + "..."
}

function Get-FleetMobileKnownActions {
    return @(
        "STATUS",
        "WHY",
        "DIGEST",
        "PARK_SHIP",
        "REQUEST_SAFE_STOP",
        "APPROVE_TASTE_DIRECTION",
        "APPROVE_PACKET_IMPORT",
        "APPROVE_PLAN",
        "REJECT_PLAN",
        "RUN_DRY_CHECK",
        "RUN_ONE_BOUNDED_BATCH",
        "PACKAGE_AUDIT",
        "CAPTURE_IDEA",
        "SET_OVERNIGHT_PRESET",
        "RESUME_AFTER_RESET",
        "MUTE_NOTIFICATIONS"
    )
}

function Test-FleetMobileForbiddenText {
    param([string]$Text)

    return ($Text -match "(?i)(\b(merge|push|deploy|delete\s+(user\s+)?work|delete\s+locks?|kill\s+process|manual\s+lock|remove-item|rm\s+-|del\s+\/|erase\s+|rd\s+\/|rmdir\s+|format\s+|shutdown|taskkill|stop-process|powershell|pwsh|cmd\.exe|bash|curl\s+|wget\s+|git\s+(reset|clean|checkout|push)|npm\s+(install|update)|pnpm\s+(install|update)|yarn\s+(add|install|upgrade)|\.env|secret|token|credential|auth|payment|stripe|migration|production\s+data|external\s+api|package\.json|package-lock|pnpm-lock|yarn\.lock|dependency)\b|[;&|`])")
}

function Resolve-FleetMobileShipScope {
    param(
        [string]$Message,
        [string[]]$KnownShips = @()
    )

    $ships = @()
    foreach ($ship in @($KnownShips)) {
        if ([string]::IsNullOrWhiteSpace($ship)) { continue }
        if ($Message -match "(?i)(^|[^A-Za-z0-9_-])$([regex]::Escape($ship))([^A-Za-z0-9_-]|$)") {
            $ships += $ship
        }
    }

    $implicitAll = ($Message -match "(?i)\b(all ships|everything|whole fleet|entire fleet|the fleet|cellar fleet|run all)\b")
    return [pscustomobject]@{
        ships = @($ships | Select-Object -Unique)
        implicitAll = [bool]$implicitAll
        missing = ($ships.Count -eq 0 -and !$implicitAll)
    }
}

function Resolve-FleetMobileIntent {
    param([string]$Message)

    $text = [string]$Message
    if ($text -match "(?i)\b(why|explain|what happened|what.*wrong|why.*stuck|why.*blocked)\b") { return "WHY" }
    if ($text -match "(?i)\b(how.*fleet|status|how.*going|check.*fleet|what.*stuck)\b") { return "STATUS" }
    if ($text -match "(?i)\b(digest|summary|morning report|overnight report)\b") { return "DIGEST" }
    if ($text -match "(?i)\b(safe stop|stop .*safely|pause .*safely)\b") { return "REQUEST_SAFE_STOP" }
    if ($text -match "(?i)\b(park)\b") { return "PARK_SHIP" }
    if ($text -match "(?i)\b(approve plan|approve generated plan|approve proposed plan)\b") { return "APPROVE_PLAN" }
    if ($text -match "(?i)\b(reject plan|deny plan|do not approve plan)\b") { return "REJECT_PLAN" }
    if ($text -match "(?i)\b(approve.*taste|taste direction|looks good|design approved)\b") { return "APPROVE_TASTE_DIRECTION" }
    if ($text -match "(?i)\b(approve.*packet|import.*packet|task packet)\b") { return "APPROVE_PACKET_IMPORT" }
    if ($text -match "(?i)\b(dry run|dry check|check only)\b") { return "RUN_DRY_CHECK" }
    if ($text -match "(?i)\b(run one|bounded batch|start batch|run batch)\b") { return "RUN_ONE_BOUNDED_BATCH" }
    if ($text -match "(?i)\b(package audit|audit package|make audit)\b") { return "PACKAGE_AUDIT" }
    if ($text -match "(?i)\b(mute|snooze)\b") { return "MUTE_NOTIFICATIONS" }
    if ($text -match "(?i)\b(overnight|tonight|preset)\b") { return "SET_OVERNIGHT_PRESET" }
    if ($text -match "(?i)\b(resume safe|resume.*safely|resume.*reset|after reset|limits reset|rate reset)\b") { return "RESUME_AFTER_RESET" }
    if ($text -match "(?i)\b(submit idea|new idea|idea|what if|we should|could we|add|make|build)\b") { return "CAPTURE_IDEA" }
    return "STATUS"
}

function Get-FleetMobileActionPolicy {
    param([string]$CommandType)

    switch ($CommandType) {
        "STATUS" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $false; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "WHY" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $false; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "DIGEST" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $false; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "CAPTURE_IDEA" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $false; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "REQUEST_SAFE_STOP" { [pscustomobject]@{ riskLevel = "moderate"; requiresApproval = $false; requiresScope = $true; requiresDryRun = $false; statusOnValid = "APPROVAL_REQUIRED" } }
        "PARK_SHIP" { [pscustomobject]@{ riskLevel = "moderate"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $false; statusOnValid = "APPROVAL_REQUIRED" } }
        "APPROVE_TASTE_DIRECTION" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $false; statusOnValid = "APPROVAL_REQUIRED" } }
        "APPROVE_PACKET_IMPORT" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $false; statusOnValid = "APPROVAL_REQUIRED" } }
        "APPROVE_PLAN" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $true; statusOnValid = "APPROVAL_REQUIRED" } }
        "REJECT_PLAN" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $true; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "RUN_DRY_CHECK" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $true; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "RUN_ONE_BOUNDED_BATCH" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $true; statusOnValid = "APPROVAL_REQUIRED" } }
        "PACKAGE_AUDIT" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $true; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        "SET_OVERNIGHT_PRESET" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $true; statusOnValid = "APPROVAL_REQUIRED" } }
        "RESUME_AFTER_RESET" { [pscustomobject]@{ riskLevel = "approval-required"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $true; statusOnValid = "APPROVAL_REQUIRED" } }
        "MUTE_NOTIFICATIONS" { [pscustomobject]@{ riskLevel = "safe"; requiresApproval = $false; requiresScope = $false; requiresDryRun = $false; statusOnValid = "ACCEPTED" } }
        default { [pscustomobject]@{ riskLevel = "unknown"; requiresApproval = $true; requiresScope = $true; requiresDryRun = $true; statusOnValid = "NEEDS_CLARIFICATION" } }
    }
}

function New-FleetMobileCommandRecord {
    param(
        [string]$Message,
        [string]$Source = "mobile",
        [string]$RequestedBy = "captain",
        [string[]]$KnownShips = @(),
        [datetime]$ReceivedAt = (Get-Date),
        [string]$ResponsePath = ""
    )

    $commandType = Resolve-FleetMobileIntent -Message $Message
    $scope = Resolve-FleetMobileShipScope -Message $Message -KnownShips $KnownShips
    $policy = Get-FleetMobileActionPolicy -CommandType $commandType
    $reasons = @()
    $validationStatus = "VALID"
    $status = $policy.statusOnValid

    if (Test-FleetMobileForbiddenText -Text $Message) {
        $validationStatus = "REJECTED_FORBIDDEN_REMOTE_ACTION"
        $status = "REJECTED"
        $reasons += "Message mentions forbidden or high-risk scope that cannot be approved casually from mobile."
    }

    if ($scope.implicitAll -and $commandType -notin @("STATUS", "DIGEST")) {
        $validationStatus = "REJECTED_IMPLICIT_ALL_FLEET"
        $status = "REJECTED"
        $reasons += "Remote commands cannot target all ships implicitly."
    }

    if ($policy.requiresScope -and @($scope.ships).Count -eq 0 -and !$scope.implicitAll) {
        $validationStatus = "NEEDS_EXPLICIT_SHIP_SCOPE"
        $status = "NEEDS_CLARIFICATION"
        $reasons += "Command requires an explicit ship name."
    }

    if ($commandType -eq "CAPTURE_IDEA") {
        $status = if ($validationStatus -eq "VALID") { "ACCEPTED" } else { $status }
        $reasons += "Captured as an idea only; it does not mutate TASK_QUEUE.md."
    }

    if ($policy.requiresDryRun -and $validationStatus -eq "VALID") {
        $reasons += "Requires local dry-run/state/budget validation before execution."
    }

    if ($policy.requiresApproval -and $validationStatus -eq "VALID") {
        $reasons += "Requires explicit local approval record; mobile text is a request, not execution authority."
    }

    if ($reasons.Count -eq 0) {
        $reasons += "Request accepted as a read-only or locally validated request."
    }

    return [pscustomobject]@{
        schemaVersion = 1
        commandId = "mobile-" + $ReceivedAt.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
        receivedAt = $ReceivedAt.ToUniversalTime().ToString("o")
        source = $Source
        requestedBy = $RequestedBy
        commandType = $commandType
        shipScope = @($scope.ships)
        implicitAllRequested = [bool]$scope.implicitAll
        message = Get-FleetMobileShortText -Text $Message -MaxLength 500
        parsedIntent = $commandType
        riskLevel = $policy.riskLevel
        requiresApproval = [bool]$policy.requiresApproval
        requiresDryRun = [bool]$policy.requiresDryRun
        validationStatus = $validationStatus
        status = $status
        responsePath = $ResponsePath
        reasons = @($reasons)
        executes = $false
    }
}

function New-FleetMobileIdeaRecord {
    param(
        [Parameter(Mandatory = $true)][object]$CommandRecord,
        [string]$Lane = "",
        [string]$Urgency = "normal"
    )

    $message = [string]$CommandRecord.message
    $highRisk = Test-FleetMobileForbiddenText -Text $message
    $vague = ($message.Length -lt 35 -or $message -match "(?i)\b(something|stuff|better|cooler|fix it|make it good)\b")
    $status = if ($highRisk) { "NEEDS_CLARIFICATION" } elseif ($vague) { "NEEDS_CLARIFICATION" } else { "READY_FOR_TASK_DRAFT" }

    return [pscustomobject]@{
        schemaVersion = 1
        ideaId = "idea-" + ([guid]::NewGuid().ToString("N").Substring(0, 10))
        sourceCommandId = $CommandRecord.commandId
        capturedAt = $CommandRecord.receivedAt
        originalMessage = $message
        targetShip = if (@($CommandRecord.shipScope).Count -eq 1) { [string]$CommandRecord.shipScope[0] } else { "" }
        lane = $Lane
        urgency = $Urgency
        status = $status
        needsResearch = ($message -match "(?i)\b(research|find|look up|reference|examples?)\b")
        needsCaptainFollowUp = ($status -ne "READY_FOR_TASK_DRAFT")
        queueMutationAllowed = $false
        nextStep = if ($status -eq "READY_FOR_TASK_DRAFT") { "Draft Task Contract V2 candidate in a validated packet." } else { "Ask a concise clarification before drafting." }
    }
}

function New-FleetMobileStatusMessage {
    param(
        [Parameter(Mandatory = $true)][object]$ControlRoomSnapshot,
        [string]$FullReportPath = ""
    )

    $runningCount = if ($ControlRoomSnapshot.counts) { [int]$ControlRoomSnapshot.counts.running } else { @($ControlRoomSnapshot.boards.running).Count }
    $blockedCount = if ($ControlRoomSnapshot.counts) { [int]$ControlRoomSnapshot.counts.blocked + [int]$ControlRoomSnapshot.counts.repair } else { @($ControlRoomSnapshot.boards.blockedRepair).Count }
    $needsApprovalCount = if ($ControlRoomSnapshot.counts) { [int]$ControlRoomSnapshot.counts.needs_captain + [int]$ControlRoomSnapshot.counts.taste } else { @($ControlRoomSnapshot.boards.needsCaptain).Count + @($ControlRoomSnapshot.boards.tasteGates).Count }
    $budgetText = "$($ControlRoomSnapshot.budget.level) -> $($ControlRoomSnapshot.budget.decision)"
    $incidentCount = $blockedCount
    if (($ControlRoomSnapshot.budget.decision -match "SAFE_LAND|BLOCK|WAIT") -or ($ControlRoomSnapshot.budget.level -match "critical|exhausted")) {
        $incidentCount += 1
    }

    $topActions = @($ControlRoomSnapshot.safeCommandSuggestions | Select-Object -First 3 | ForEach-Object {
        "$($_.ship): $($_.label)"
    })
    if ($topActions.Count -eq 0) { $topActions = @("No command suggestions available.") }

    $lines = @(
        "Fleet: $($ControlRoomSnapshot.captainSummary)",
        "Cards: Running $runningCount | Blocked $blockedCount | Needs Approval $needsApprovalCount | Budget $budgetText | Incidents $incidentCount",
        "Next: $($ControlRoomSnapshot.nextCaptainAction)",
        "Top actions:",
        ($topActions | ForEach-Object { "- $_" })
    )
    if (![string]::IsNullOrWhiteSpace($FullReportPath)) {
        $lines += "Full report: $FullReportPath"
    }

    return ($lines -join "`n")
}

function New-FleetMobileRateAlert {
    param(
        [Parameter(Mandatory = $true)][object]$Budget,
        [string[]]$AffectedShips = @(),
        [string]$ReportPath = ""
    )

    $level = ([string]$Budget.level).ToLowerInvariant()
    $decision = [string]$Budget.decision
    $severity = switch ($level) {
        "healthy" { "info" }
        "cautious" { "info" }
        "low" { "warning" }
        "critical" { "critical" }
        "exhausted" { "critical" }
        "reset_pending" { "warning" }
        "recovered" { "info" }
        default { "warning" }
    }
    $userAction = switch ($decision) {
        "SAFE_LAND_NOW" { "Let safe landing complete; do not start new work." }
        "WAIT_FOR_RESET" { "Wait for reset or provide recovered-budget evidence." }
        "BLOCK_NEW_WORK" { "Use status-only checks until budget improves." }
        "ALLOW_RUN" { "Dry-run selected ships before any bounded run." }
        default { "Use status-only checks." }
    }

    return [pscustomobject]@{
        alertType = if ($decision -eq "SAFE_LAND_NOW") { "SAFE_LANDING_STARTED" } elseif ($decision -eq "WAIT_FOR_RESET") { "RESET_PENDING" } elseif ($level -eq "low") { "BUDGET_LOW" } elseif ($level -eq "critical") { "BUDGET_CRITICAL" } elseif ($level -eq "recovered") { "RESUME_ELIGIBLE" } else { "BUDGET_" + $level.ToUpperInvariant() }
        severity = $severity
        budgetState = $level
        decision = $decision
        affectedShips = @($AffectedShips)
        actionTaken = if ($decision -eq "SAFE_LAND_NOW") { "Safe landing requested." } else { "No implementation action taken by mobile layer." }
        nextCheckTime = ""
        userActionNeeded = $userAction
        reportPath = $ReportPath
    }
}

function New-FleetMobileDigest {
    param(
        [Parameter(Mandatory = $true)][object]$ControlRoomSnapshot,
        [string]$FullReportPath = ""
    )

    $blocked = @($ControlRoomSnapshot.boards.blockedRepair)
    $taste = @($ControlRoomSnapshot.boards.tasteGates)
    $wins = @($ControlRoomSnapshot.boards.safeToInspect | Select-Object -First 2 | ForEach-Object { "$($_.ship) is safe to inspect." })
    if ($wins.Count -eq 0) { $wins = @("No completed inspectable ships reported.") }

    $lines = @(
        "Digest: $($ControlRoomSnapshot.captainSummary)",
        "Wins: $($wins -join " / ")",
        "Failures: $($blocked.Count) blocker/repair item(s)",
        "Taste: $($taste.Count) decision(s)",
        "Budget: $($ControlRoomSnapshot.budget.level) -> $($ControlRoomSnapshot.budget.decision)",
        "Next: $($ControlRoomSnapshot.nextCaptainAction)"
    )
    if (![string]::IsNullOrWhiteSpace($FullReportPath)) {
        $lines += "Full report: $FullReportPath"
    }
    return ($lines -join "`n")
}
