function Get-FleetControlRoomShortText {
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

function Normalize-FleetControlRoomStatus {
    param([string]$Status)

    $value = ([string]$Status).Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($value)) { return "UNKNOWN" }
    $known = @(
        "READY", "RUNNING", "BLOCKED", "REPAIRING", "TASTE_GATE",
        "PARKED", "AUDIT_READY", "PACKET_READY", "RATE_LIMIT_PAUSED",
        "ARCHIVED", "UNKNOWN"
    )
    if ($known -contains $value) { return $value }
    return "UNKNOWN"
}

function Get-FleetControlRoomBucket {
    param([string]$Status)

    $normalized = Normalize-FleetControlRoomStatus -Status $Status
    switch ($normalized) {
        "RUNNING" { "running" }
        "BLOCKED" { "blocked" }
        "REPAIRING" { "repair" }
        "TASTE_GATE" { "taste" }
        "PARKED" { "safe_to_inspect" }
        "AUDIT_READY" { "needs_captain" }
        "PACKET_READY" { "needs_captain" }
        "RATE_LIMIT_PAUSED" { "budget" }
        default { "other" }
    }
}

function New-FleetControlRoomCommandSuggestion {
    param([Parameter(Mandatory = $true)][object]$Ship)

    $shipName = [string]$Ship.ship
    $status = Normalize-FleetControlRoomStatus -Status ([string]$Ship.status)
    $decision = ([string]$Ship.decision).Trim().ToUpperInvariant()
    $lane = [string]$Ship.lane
    $packetStatus = ([string]$Ship.packetStatus).Trim().ToUpperInvariant()
    $approvalRequired = [bool]($Ship.backendApprovalRequired -or $Ship.captainApprovalRequired)

    $label = "Write status report"
    $risk = "safe"
    $requiredApprovals = @()
    $forbiddenIf = @("ship scope is ambiguous", "active PID/lock ownership is unknown")
    $expectedEffect = "Create or refresh a read-only status summary."
    $dryRun = "invoke-autonomy-wrapper.ps1 -Ship $shipName -DryRun"
    $reason = "Conservative default."

    switch ($status) {
        "RUNNING" {
            $label = "Leave running"
            $risk = "safe"
            $expectedEffect = "Do not touch the ship while active work owns it."
            $dryRun = "fleet-status.ps1"
            $reason = "Active ships should not be interrupted by the dashboard."
            $forbiddenIf += "captain has not requested a safe stop"
        }
        "BLOCKED" {
            $label = if ($approvalRequired -or $lane -eq "backend_sensitive") { "Request approval / write blocker note" } else { "Write repair task" }
            $risk = if ($approvalRequired -or $lane -eq "backend_sensitive") { "approval-required" } else { "moderate" }
            if ($approvalRequired -or $lane -eq "backend_sensitive") { $requiredApprovals += "captain approval" }
            $expectedEffect = "Explain the blocker and prepare a bounded repair path without launching."
            $dryRun = "fleet-decision.ps1 -Ship $shipName -NoWrite"
            $reason = "Blocked ships must not appear runnable."
            $forbiddenIf += "failed gate evidence is missing"
        }
        "REPAIRING" {
            $label = "Continue bounded repair if attempts remain"
            $risk = "moderate"
            $expectedEffect = "Run only the approved repair slice after evidence confirms attempts remain."
            $dryRun = "invoke-autonomy-wrapper.ps1 -Ship $shipName -DryRun"
            $reason = "Repairing ships need attempt limits and failed-gate evidence."
            $forbiddenIf += "repair attempt budget is exhausted"
        }
        "TASTE_GATE" {
            $label = "Request taste review"
            $risk = "safe"
            $expectedEffect = "Ask the captain a subjective design/product question."
            $dryRun = "fleet-decision.ps1 -Ship $shipName -NoWrite"
            $reason = "Deterministic gates passed; remaining work is subjective."
            $forbiddenIf += "build/test evidence is missing"
        }
        "AUDIT_READY" {
            $label = "Package or send audit package"
            $risk = "safe"
            $expectedEffect = "Prepare evidence for external review without changing the repo."
            $dryRun = "new-audit-package.ps1 -Ship $shipName -DryRun"
            $reason = "Audit-ready ships need evidence review before new tasks."
        }
        "PACKET_READY" {
            $label = "Import approved packet"
            $risk = "approval-required"
            $requiredApprovals += "valid Stage 4 packet evidence"
            $expectedEffect = "Append validated task packet items to the selected ship queue."
            $dryRun = "ingest-task-packet.ps1 -Ship $shipName -DryRun"
            $reason = "External packets are not trusted until validation evidence exists."
            if ($packetStatus -ne "VALIDATED") {
                $label = "Validate packet before import"
                $expectedEffect = "Reject or validate the packet before any queue change."
            }
            $forbiddenIf += "packet is stale, malformed, duplicate, or unvalidated"
        }
        "RATE_LIMIT_PAUSED" {
            $label = "Wait for budget recovery"
            $risk = "safe"
            $expectedEffect = "Keep the safe landing in place until Stage 10 resume eligibility is green."
            $dryRun = "invoke-overnight-mode.ps1 -Ship $shipName -ManualBudgetLevel recovered"
            $reason = "Rate-paused ships must not resume without confirmed budget and eligibility."
            $forbiddenIf += "budget recovery is unknown"
        }
        "PARKED" {
            $label = "Inspect parked result"
            $risk = "safe"
            $expectedEffect = "Review evidence and done contract; do not call it finished without proof."
            $dryRun = "fleet-status.ps1"
            $reason = "Parked ships are safe to inspect, not automatically complete."
        }
        "READY" {
            $label = "Dry-run selected ship"
            $risk = "safe"
            $expectedEffect = "Confirm the next bounded action before any implementation run."
            $dryRun = "invoke-autonomy-wrapper.ps1 -Ship $shipName -DryRun"
            $reason = "Ready ships can be considered only with explicit selected scope."
            $forbiddenIf += "command would expand to all ships"
        }
    }

    if ($decision -eq "USER_TASTE_GATE") {
        $label = "Request taste review"
        $risk = "safe"
        $reason = "Decision engine chose the captain/taste gate."
    }

    return [pscustomobject]@{
        label = $label
        ship = $shipName
        risk = $risk
        reason = $reason
        requiredApprovals = @($requiredApprovals)
        expectedEffect = $expectedEffect
        dryRunEquivalent = $dryRun
        forbiddenIf = @($forbiddenIf)
        executes = $false
    }
}

function New-FleetControlRoomSnapshot {
    param(
        [Parameter(Mandatory = $true)][object[]]$Ships,
        [object]$Budget = $null,
        [datetime]$GeneratedAt = (Get-Date)
    )

    $normalizedShips = @()
    foreach ($ship in @($Ships)) {
        $status = Normalize-FleetControlRoomStatus -Status ([string]$ship.status)
        $bucket = Get-FleetControlRoomBucket -Status $status
        $suggestion = New-FleetControlRoomCommandSuggestion -Ship $ship
        $normalizedShips += [pscustomobject]@{
            ship = [string]$ship.ship
            repo = [string]$ship.repo
            branch = [string]$ship.branch
            head = [string]$ship.head
            status = $status
            bucket = $bucket
            decision = [string]$ship.decision
            lane = [string]$ship.lane
            tasksRemaining = if ($null -ne $ship.tasksRemaining) { [int]$ship.tasksRemaining } else { 0 }
            dirty = [bool]$ship.dirty
            active = [bool]$ship.active
            latestEvidence = [string]$ship.latestEvidence
            latestAuditPackage = [string]$ship.latestAuditPackage
            latestTaskPacket = [string]$ship.latestTaskPacket
            packetStatus = [string]$ship.packetStatus
            blocker = Get-FleetControlRoomShortText -Text ([string]$ship.blocker) -MaxLength 220
            tasteQuestion = Get-FleetControlRoomShortText -Text ([string]$ship.tasteQuestion) -MaxLength 220
            overnightStatus = [string]$ship.overnightStatus
            rateStatus = [string]$ship.rateStatus
            safeCommand = $suggestion
        }
    }

    $counts = [ordered]@{}
    foreach ($bucketName in @("running", "needs_captain", "blocked", "repair", "taste", "safe_to_inspect", "budget", "other")) {
        $counts[$bucketName] = @($normalizedShips | Where-Object { $_.bucket -eq $bucketName }).Count
    }

    $needsCaptain = @($normalizedShips | Where-Object { $_.bucket -in @("needs_captain", "taste") })
    $blocked = @($normalizedShips | Where-Object { $_.bucket -in @("blocked", "repair") })
    $running = @($normalizedShips | Where-Object { $_.bucket -eq "running" })
    $safeInspect = @($normalizedShips | Where-Object { $_.bucket -eq "safe_to_inspect" })
    $budgetShips = @($normalizedShips | Where-Object { $_.bucket -eq "budget" })

    $budgetSummary = if ($null -ne $Budget) { $Budget } else { [pscustomobject]@{ level = "unknown"; decision = "ALLOW_STATUS_ONLY"; reason = "No budget evidence supplied." } }
    $captainSummary = @(
        "Running: $($running.Count)",
        "Needs captain: $($needsCaptain.Count)",
        "Blocked/repair: $($blocked.Count)",
        "Safe to inspect: $($safeInspect.Count)",
        "Budget: $($budgetSummary.level) -> $($budgetSummary.decision)"
    ) -join " | "

    return [pscustomobject]@{
        schemaVersion = 1
        stage = "Golden Gameplan Stage 12"
        generatedAt = $GeneratedAt.ToUniversalTime().ToString("o")
        status = "GREEN"
        mode = "read-only-control-room"
        captainSummary = $captainSummary
        counts = [pscustomobject]$counts
        budget = $budgetSummary
        ships = @($normalizedShips)
        boards = [pscustomobject]@{
            running = @($running)
            needsCaptain = @($needsCaptain)
            blockedRepair = @($blocked)
            tasteGates = @($normalizedShips | Where-Object { $_.bucket -eq "taste" })
            safeToInspect = @($safeInspect)
            budget = @($budgetShips)
            auditPackages = @($normalizedShips | Where-Object { ![string]::IsNullOrWhiteSpace($_.latestAuditPackage) -or $_.status -eq "AUDIT_READY" })
            taskPackets = @($normalizedShips | Where-Object { ![string]::IsNullOrWhiteSpace($_.latestTaskPacket) -or $_.status -eq "PACKET_READY" })
        }
        safeCommandSuggestions = @($normalizedShips | ForEach-Object { $_.safeCommand })
        forbiddenActions = @("implicit-all-fleet-launch", "merge", "push", "deploy", "manual-lock-delete", "unvalidated-packet-import")
        nextCaptainAction = if ($blocked.Count -gt 0) { "Review blocker/repair board first." } elseif ($needsCaptain.Count -gt 0) { "Answer taste/audit/packet questions." } else { "Use dry-run suggestions before any bounded run." }
    }
}

function New-FleetControlRoomReconciliationFixture {
    param(
        [string]$ShipId = "FixtureShip",
        [string]$RepoFingerprintRef = "repo:fingerprint:expected",
        [string]$ObservedRepoFingerprintRef = "repo:fingerprint:expected",
        [string]$RunArtifactRef = "run:artifact:current",
        [datetime]$RunArtifactGeneratedAt = (Get-Date),
        [string]$DbStateRef = "db:state:fixture",
        [string]$StatusSnapshotRef = "status:snapshot:fixture",
        [string]$ExpectedStatus = "READY",
        [string]$SnapshotStatus = "READY",
        [switch]$ContradictoryLease,
        [int]$StaleArtifactMinutes = 60,
        [datetime]$GeneratedAt = (Get-Date),
        [string[]]$EvidenceRefs = @()
    )

    $ship = ([string]$ShipId).Trim()
    if ([string]::IsNullOrWhiteSpace($ship) -or $ship -in @("all", "ALL", "*")) {
        $ship = "unknown-ship"
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $validationReasons = [System.Collections.Generic.List[string]]::new()
    $nowUtc = $GeneratedAt.ToUniversalTime()
    $runArtifactUtc = $RunArtifactGeneratedAt.ToUniversalTime()

    if ([string]::IsNullOrWhiteSpace($RepoFingerprintRef)) {
        $reasons.Add("missing-repo-fingerprint-ref") | Out-Null
        $validationReasons.Add("missing-repo-fingerprint-ref") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($RunArtifactRef)) {
        $reasons.Add("missing-run-artifact-ref") | Out-Null
        $validationReasons.Add("missing-run-artifact-ref") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($DbStateRef)) {
        $reasons.Add("missing-db-state-ref") | Out-Null
        $validationReasons.Add("missing-db-state-ref") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($StatusSnapshotRef)) {
        $reasons.Add("unknown-source") | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoFingerprintRef) -and
        -not [string]::IsNullOrWhiteSpace($ObservedRepoFingerprintRef) -and
        [string]$RepoFingerprintRef -ne [string]$ObservedRepoFingerprintRef) {
        $reasons.Add("repo-fingerprint-drift") | Out-Null
        $validationReasons.Add("repo-fingerprint-drift") | Out-Null
    }

    if ($runArtifactUtc -lt $nowUtc.AddMinutes(-1 * [Math]::Abs($StaleArtifactMinutes))) {
        $reasons.Add("stale-artifact") | Out-Null
        $validationReasons.Add("stale-artifact") | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedStatus) -and
        -not [string]::IsNullOrWhiteSpace($SnapshotStatus) -and
        (Normalize-FleetControlRoomStatus -Status $ExpectedStatus) -ne (Normalize-FleetControlRoomStatus -Status $SnapshotStatus)) {
        $reasons.Add("status-snapshot-mismatch") | Out-Null
        $validationReasons.Add("status-snapshot-mismatch") | Out-Null
    }

    if ($ContradictoryLease) {
        $reasons.Add("contradictory-lease") | Out-Null
        $validationReasons.Add("contradictory-lease") | Out-Null
    }

    $uniqueReasons = @($reasons | Select-Object -Unique)
    $uniqueValidationReasons = @($validationReasons | Select-Object -Unique)
    $hasMissingEvidence = @($uniqueReasons | Where-Object { $_ -in @("missing-db-state-ref", "missing-run-artifact-ref", "missing-repo-fingerprint-ref", "unknown-source") }).Count -gt 0
    $reconciliationStatus = if ($hasMissingEvidence) { "UNKNOWN" } elseif ($uniqueReasons.Count -gt 0) { "MISMATCH" } else { "MATCH" }
    $displayStatus = if ($reconciliationStatus -eq "MATCH") { "MATCH" } else { "UNKNOWN" }

    if ($reconciliationStatus -eq "MATCH") {
        $uniqueValidationReasons = @("matched")
    } elseif ($reconciliationStatus -eq "MISMATCH") {
        $uniqueValidationReasons = @($uniqueValidationReasons + "mismatch-shows-unknown" | Select-Object -Unique)
    } else {
        $uniqueValidationReasons = @($uniqueValidationReasons + "unknown-shows-unknown" | Select-Object -Unique)
    }

    return [pscustomobject]@{
        schemaVersion = 1
        reconciliationId = "reconcile:${ship}:$($nowUtc.ToString("yyyyMMddHHmmss"))"
        shipId = $ship
        repoFingerprintRef = if ([string]::IsNullOrWhiteSpace($RepoFingerprintRef)) { "missing:repo-fingerprint-ref" } else { [string]$RepoFingerprintRef }
        runArtifactRef = if ([string]::IsNullOrWhiteSpace($RunArtifactRef)) { "missing:run-artifact-ref" } else { [string]$RunArtifactRef }
        dbStateRef = if ([string]::IsNullOrWhiteSpace($DbStateRef)) { "missing:db-state-ref" } else { [string]$DbStateRef }
        statusSnapshotRef = if ([string]::IsNullOrWhiteSpace($StatusSnapshotRef)) { "missing:status-snapshot-ref" } else { [string]$StatusSnapshotRef }
        reconciliationStatus = $reconciliationStatus
        mismatchReasons = @($uniqueReasons)
        displayStatus = $displayStatus
        generatedAt = $nowUtc.ToString("o")
        evidenceRefs = @($EvidenceRefs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        validation = [pscustomobject]@{
            status = if ($reconciliationStatus -eq "MATCH") { "valid" } elseif ($reconciliationStatus -eq "UNKNOWN") { "unknown" } else { "invalid" }
            reasons = @($uniqueValidationReasons)
        }
    }
}

function New-FleetControlRoomMarkdown {
    param([Parameter(Mandatory = $true)][object]$Snapshot)

    $lines = @(
        "# Stage 12 Fleet Control Room",
        "",
        "Generated: $($Snapshot.generatedAt)",
        "",
        "## Captain Summary",
        "",
        $Snapshot.captainSummary,
        "",
        "Next captain action: $($Snapshot.nextCaptainAction)",
        "",
        "## First Screen",
        "",
        "| Card | Count | Meaning |",
        "| --- | ---: | --- |",
        "| Running | $($Snapshot.counts.running) | Active work owns these ships; leave them alone unless safe stop is requested. |",
        "| Needs Captain | $($Snapshot.counts.needs_captain + $Snapshot.counts.taste) | Audit, packet, or taste decisions need human judgment. |",
        "| Blocked / Repair | $($Snapshot.counts.blocked + $Snapshot.counts.repair) | Deterministic blockers or bounded repair work. |",
        "| Safe To Inspect | $($Snapshot.counts.safe_to_inspect) | Parked/inspectable, not automatically finished. |",
        "| Budget | $($Snapshot.counts.budget) | Rate paused or overnight budget attention. |",
        "",
        "## Ships",
        "",
        "| Ship | State | Lane | Decision | Tasks | Dirty | Evidence | Safe suggestion |",
        "| --- | --- | --- | --- | ---: | --- | --- | --- |"
    )

    foreach ($ship in @($Snapshot.ships)) {
        $evidence = if ([string]::IsNullOrWhiteSpace($ship.latestEvidence)) { "missing" } else { $ship.latestEvidence }
        $lines += "| $($ship.ship) | $($ship.status) | $($ship.lane) | $($ship.decision) | $($ship.tasksRemaining) | $($ship.dirty) | $evidence | $($ship.safeCommand.label) |"
    }

    $lines += @(
        "",
        "## Blocker / Repair Board",
        "",
        "| Ship | State | Blocker | Suggested action |",
        "| --- | --- | --- | --- |"
    )
    foreach ($ship in @($Snapshot.boards.blockedRepair)) {
        $blocker = if ([string]::IsNullOrWhiteSpace($ship.blocker)) { "See latest run evidence." } else { $ship.blocker }
        $lines += "| $($ship.ship) | $($ship.status) | $blocker | $($ship.safeCommand.label) |"
    }
    if (@($Snapshot.boards.blockedRepair).Count -eq 0) { $lines += "| none | - | - | - |" }

    $lines += @(
        "",
        "## Taste Gate Board",
        "",
        "| Ship | Question | Evidence |",
        "| --- | --- | --- |"
    )
    foreach ($ship in @($Snapshot.boards.tasteGates)) {
        $question = if ([string]::IsNullOrWhiteSpace($ship.tasteQuestion)) { "Captain taste review required." } else { $ship.tasteQuestion }
        $lines += "| $($ship.ship) | $question | $($ship.latestEvidence) |"
    }
    if (@($Snapshot.boards.tasteGates).Count -eq 0) { $lines += "| none | - | - |" }

    $lines += @(
        "",
        "## Budget / Overnight",
        "",
        "- Level: $($Snapshot.budget.level)",
        "- Decision: $($Snapshot.budget.decision)",
        "- Reason: $($Snapshot.budget.reason)",
        "",
        "## Audit Packages And Task Packets",
        "",
        "| Ship | Audit package | Task packet | Packet status |",
        "| --- | --- | --- | --- |"
    )
    foreach ($ship in @($Snapshot.ships | Where-Object { ![string]::IsNullOrWhiteSpace($_.latestAuditPackage) -or ![string]::IsNullOrWhiteSpace($_.latestTaskPacket) -or $_.status -in @("AUDIT_READY", "PACKET_READY") })) {
        $lines += "| $($ship.ship) | $($ship.latestAuditPackage) | $($ship.latestTaskPacket) | $($ship.packetStatus) |"
    }

    $lines += @(
        "",
        "## Safe Command Suggestions",
        "",
        "| Ship | Suggestion | Risk | Executes? | Dry-run equivalent |",
        "| --- | --- | --- | --- | --- |"
    )
    foreach ($suggestion in @($Snapshot.safeCommandSuggestions)) {
        $lines += "| $($suggestion.ship) | $($suggestion.label) | $($suggestion.risk) | $($suggestion.executes) | `$($suggestion.dryRunEquivalent)` |"
    }

    $lines += @(
        "",
        "## Forbidden Actions",
        "",
        ($Snapshot.forbiddenActions | ForEach-Object { "- $_" })
    )

    return ($lines -join "`n")
}
