function Get-FleetAutonomyActionValues {
    return @(
        "WRITE_STATUS_REPORT",
        "RUN_ONE_BATCH",
        "MAKE_AUDIT_PACKAGE",
        "IMPORT_APPROVED_PACKET",
        "WRITE_REPAIR_TASK",
        "PARK_SHIP",
        "REQUEST_TASTE_GATE",
        "BLOCK_WITH_REASON"
    )
}

function New-FleetAutonomyBudget {
    param(
        [int]$MaxCycles = 1,
        [int]$MaxRuntimeMinutes = 10,
        [int]$MaxShips = 1,
        [int]$MaxRunBatchesPerShip = 1,
        [int]$MaxRepairAttempts = 1,
        [int]$MaxAuditPackages = 1,
        [int]$MaxTaskPacketImports = 1,
        [switch]$LowTokenMode,
        [int]$StopBeforeRateLimitPercent = 3
    )

    return [pscustomobject]@{
        maxCycles = [Math]::Max(1, $MaxCycles)
        maxRuntimeMinutes = [Math]::Max(1, $MaxRuntimeMinutes)
        maxShips = [Math]::Max(1, $MaxShips)
        maxRunBatchesPerShip = [Math]::Max(0, $MaxRunBatchesPerShip)
        maxRepairAttempts = [Math]::Max(0, $MaxRepairAttempts)
        maxAuditPackages = [Math]::Max(0, $MaxAuditPackages)
        maxTaskPacketImports = [Math]::Max(0, $MaxTaskPacketImports)
        lowTokenMode = [bool]$LowTokenMode
        stopBeforeRateLimitPercent = [Math]::Max(0, $StopBeforeRateLimitPercent)
    }
}

function Get-FleetAutonomyShortText {
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

function Test-FleetApprovedPacketEvidence {
    param(
        [string]$Path,
        [string]$FleetRoot = (Get-Location).Path
    )

    $result = [pscustomobject]@{
        valid = $false
        path = ""
        packetId = ""
        reason = "Approved packet evidence path is required."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) { return $result }

    $rootFull = [System.IO.Path]::GetFullPath($FleetRoot)
    if (!$rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $rootFull $Path))
    }

    if (!$fullPath.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.reason = "Approved packet evidence must stay inside the fleet root."
        $result.path = $fullPath
        return $result
    }
    if ($fullPath -match "(?i)([\\/]\.git[\\/]|[\\/]node_modules[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]\.env($|[\\/])|secret|token|credential|private[-_]?key)") {
        $result.reason = "Approved packet evidence path is forbidden by runtime scope policy."
        $result.path = $fullPath
        return $result
    }
    if (!(Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $result.reason = "Approved packet evidence file does not exist."
        $result.path = $fullPath
        return $result
    }
    if ($fullPath -notmatch "(?i)\.json$") {
        $result.reason = "Approved packet evidence must be a JSON validation artifact."
        $result.path = $fullPath
        return $result
    }

    try {
        $json = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
    } catch {
        $result.reason = "Approved packet evidence is not valid JSON: $($_.Exception.Message)"
        $result.path = $fullPath
        return $result
    }

    $valid = $false
    if ($null -ne $json.valid) { $valid = [bool]$json.valid }
    elseif ([string]$json.status -match "^(passed|valid|accepted)$") { $valid = $true }

    $acceptedCount = 0
    if ($null -ne $json.accepted) { $acceptedCount = @($json.accepted).Count }
    elseif ($null -ne $json.acceptedTasks) { $acceptedCount = [int]$json.acceptedTasks }

    if (!$valid) {
        $result.reason = "Approved packet evidence does not record a valid Stage 4 packet."
        $result.path = $fullPath
        return $result
    }
    if ($acceptedCount -lt 1) {
        $result.reason = "Approved packet evidence has no accepted task records."
        $result.path = $fullPath
        return $result
    }

    $result.valid = $true
    $result.path = $fullPath
    $result.packetId = if ($json.packetId) { [string]$json.packetId } else { "" }
    $result.reason = "Stage 4 packet validation evidence is present."
    return $result
}

function Resolve-FleetAutonomyAction {
    param(
        [Parameter(Mandatory = $true)][object]$Decision,
        [Parameter(Mandatory = $true)][object]$Budget,
        [switch]$AllowRunBatch,
        [switch]$AllowAuditPackage,
        [switch]$AllowTaskPacketImport,
        [switch]$AllowRepairTask,
        [switch]$AllowParkShip,
        [string]$ApprovedPacketEvidence = "",
        [string]$FleetRoot = (Get-Location).Path
    )

    $decisionValue = ([string]$Decision.decision).ToUpperInvariant()
    $blockedReason = ""
    $action = "WRITE_STATUS_REPORT"
    $approval = ""

    switch ($decisionValue) {
        "NOOP" { $action = "WRITE_STATUS_REPORT" }
        "RUN_AGAIN" {
            if ($Budget.lowTokenMode) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Low-token mode blocks implementation runs." }
            elseif (!$AllowRunBatch) { $action = "WRITE_STATUS_REPORT"; $approval = "Captain must pass -AllowRunBatch and -Execute for one bounded run." }
            elseif ($Budget.maxRunBatchesPerShip -lt 1) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Run batch budget is exhausted." }
            else { $action = "RUN_ONE_BATCH" }
        }
        "REPAIR" {
            if (!$AllowRepairTask) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Repair task creation is not approved." }
            elseif ($Budget.maxRepairAttempts -lt 1) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Repair budget is exhausted." }
            else { $action = "WRITE_REPAIR_TASK" }
        }
        "PACKAGE_AUDIT" {
            if (!$AllowAuditPackage) { $action = "WRITE_STATUS_REPORT"; $approval = "Captain must pass -AllowAuditPackage to create an audit package." }
            elseif ($Budget.maxAuditPackages -lt 1) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Audit package budget is exhausted." }
            else { $action = "MAKE_AUDIT_PACKAGE" }
        }
        "WAIT_FOR_EXTERNAL_AUDIT" { $action = "WRITE_STATUS_REPORT" }
        "WAIT_FOR_TASK_PACKET" {
            $packetEvidence = Test-FleetApprovedPacketEvidence -Path $ApprovedPacketEvidence -FleetRoot $FleetRoot
            if (!$AllowTaskPacketImport) { $action = "WRITE_STATUS_REPORT"; $approval = "Waiting for a Stage 4-validated task packet." }
            elseif (!$packetEvidence.valid) { $action = "BLOCK_WITH_REASON"; $blockedReason = $packetEvidence.reason }
            elseif ($Budget.maxTaskPacketImports -lt 1) { $action = "BLOCK_WITH_REASON"; $blockedReason = "Task packet import budget is exhausted." }
            else { $action = "IMPORT_APPROVED_PACKET"; $approval = $packetEvidence.path }
        }
        "USER_TASTE_GATE" { $action = "REQUEST_TASTE_GATE" }
        "WAIT_FOR_RATE_RESET" { $action = "WRITE_STATUS_REPORT"; $approval = "Stage 10 handles automatic resume; Stage 8 only reports the wait." }
        "PARK" {
            if ($AllowParkShip) { $action = "PARK_SHIP" }
            else { $action = "WRITE_STATUS_REPORT"; $approval = "Captain must pass -AllowParkShip to write a park transition." }
        }
        "BLOCK" { $action = "BLOCK_WITH_REASON"; $blockedReason = [string]$Decision.reason }
        "ARCHIVE" { $action = "BLOCK_WITH_REASON"; $blockedReason = "Archive requires a later explicit archive approval path." }
        default { $action = "BLOCK_WITH_REASON"; $blockedReason = "Unknown decision: $decisionValue" }
    }

    return [pscustomobject]@{
        action = $action
        decision = $decisionValue
        blockedReason = $blockedReason
        requiredApproval = $approval
        risk = if ($action -in @("RUN_ONE_BATCH", "IMPORT_APPROVED_PACKET", "WRITE_REPAIR_TASK", "PARK_SHIP")) { "bounded-approved" } elseif ($action -eq "BLOCK_WITH_REASON") { "blocked" } else { "report-only" }
    }
}

function Test-FleetAutonomyScope {
    param(
        [Parameter(Mandatory = $true)][object[]]$Projects,
        [string[]]$Ship = @(),
        [string]$Preset = "",
        [int]$MaxShips = 1
    )

    $selectedNames = @($Ship | ForEach-Object { [string]$_ } | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $excluded = @()
    if ($selectedNames.Count -eq 0 -and [string]::IsNullOrWhiteSpace($Preset)) {
        throw "Stage 8 requires explicit -Ship or -Preset. It never defaults to all ships."
    }

    $selectedProjects = @()
    if (![string]::IsNullOrWhiteSpace($Preset)) {
        if ($Preset -ne "fixture-only") { throw "Unknown Stage 8 preset: $Preset" }
        foreach ($project in $Projects) {
            $repo = [string]$project.repo
            if ([string]$project.name -match "^Fixture" -or $repo -match "(?i)(^|[\\/])\.codex-local[\\/]fixtures([\\/]|$)") {
                $selectedProjects += $project
            } else {
                $excluded += [pscustomobject]@{ ship = [string]$project.name; reason = "Not fixture-only scope." }
            }
        }
    } else {
        foreach ($name in $selectedNames) {
            $match = @($Projects | Where-Object { [string]$_.name -eq $name })
            if ($match.Count -eq 0) { throw "Unknown selected ship: $name" }
            $selectedProjects += $match[0]
        }
        foreach ($project in $Projects) {
            if ($selectedNames -notcontains [string]$project.name) {
                $excluded += [pscustomobject]@{ ship = [string]$project.name; reason = "Not selected." }
            }
        }
    }

    if ($selectedProjects.Count -eq 0) { throw "Selected scope resolved to zero ships." }
    if ($selectedProjects.Count -gt $MaxShips) { throw "Selected scope has $($selectedProjects.Count) ships, over MaxShips $MaxShips." }

    return [pscustomobject]@{
        selected = @($selectedProjects)
        excluded = @($excluded)
    }
}

function New-FleetRuntimePolicyDecisionDryRun {
    param(
        [string]$SelectedShipId = "",
        [string]$Entrypoint = "invoke-autonomy-wrapper.ps1",
        [string]$Action = "RUN_ONE_BATCH",
        [string]$RepoFingerprintRef = "",
        [string]$WorktreeBoundaryRef = "",
        [string]$BudgetRecordRef = "",
        [switch]$CaptainApproval,
        [switch]$StaleFingerprint,
        [string[]]$RequestedPaths = @(),
        [switch]$TaskPacketValidated,
        [switch]$ExternalReportInput,
        [switch]$MobileRequestInput,
        [switch]$DocxReportInput,
        [switch]$AuditPackageInput,
        [switch]$QueueProseInput,
        [switch]$MalformedInput,
        [switch]$UnauthorizedEvidence,
        [switch]$BroadInput,
        [string]$RawInputText = "",
        [switch]$IncludeEvidenceBundle,
        [string]$LeaseHeartbeatRef = "lease:heartbeat:fixture",
        [string]$FailureFingerprintRef = "failure:fingerprint:fixture",
        [string]$ApprovalEvidenceRef = "",
        [string]$SourceProvenanceType = "local_fixture",
        [string]$SourceProvenanceRef = "fixture://runtime-policy",
        [string]$PolicyVersion = "runtime-policy-v1",
        [datetime]$GeneratedAt = (Get-Date),
        [string[]]$EvidenceRefs = @()
    )

    $ship = ([string]$SelectedShipId).Trim()
    $entrypointValue = if ([string]::IsNullOrWhiteSpace($Entrypoint)) { "manual-captain-note" } else { [string]$Entrypoint }
    $actionValue = ([string]$Action).Trim().ToUpperInvariant()
    if ((Get-FleetAutonomyActionValues) -notcontains $actionValue) {
        $actionValue = "BLOCK_WITH_REASON"
    }

    $legacyEntrypoints = @(
        "fleet-supervisor.ps1",
        "fleet-remote-control.ps1",
        "run-fleet.ps1",
        "launch-overnight-run.ps1",
        "start-overnight-autopilot.ps1"
    )
    $mobileEntrypoints = @("invoke-mobile-console.ps1")
    $externalReviewEntrypoints = @(
        "new-external-agent-workflow.ps1",
        "invoke-audit-loop-package.ps1",
        "new-audit-loop-queue.ps1",
        "invoke-audit-loop-task.ps1"
    )

    $riskClass = switch ($entrypointValue) {
        { $_ -in $legacyEntrypoints } { "legacy_broad_requires_human"; break }
        { $_ -in $mobileEntrypoints } { "mobile_request_only"; break }
        { $_ -in $externalReviewEntrypoints } { "external_review_request_only"; break }
        "new-audit-package.ps1" { "audit_package"; break }
        "ingest-task-packet.ps1" { "packet_import"; break }
        default {
            switch ($actionValue) {
                "WRITE_STATUS_REPORT" { "report_only"; break }
                "MAKE_AUDIT_PACKAGE" { "audit_package"; break }
                "IMPORT_APPROVED_PACKET" { "packet_import"; break }
                "WRITE_REPAIR_TASK" { "repair_task_writer"; break }
                "PARK_SHIP" { "park_or_stop_request"; break }
                default { "bounded_selected_ship" }
            }
        }
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $denialReason = ""
    $decision = "ALLOW"
    $approvalRequirement = "none"
    $fixtureName = "validated-selected-ship-allowed"

    if ([string]::IsNullOrWhiteSpace($ship)) {
        $decision = "DENY"
        $denialReason = "blank-ship"
        $approvalRequirement = "not_approvable"
        $fixtureName = "blank-ship-denied"
        $reasons.Add("blank-ship") | Out-Null
    } elseif ($ship -in @("all", "ALL")) {
        $decision = "DENY"
        $denialReason = "all-ship"
        $approvalRequirement = "not_approvable"
        $fixtureName = "all-ship-denied"
        $reasons.Add("all-ship") | Out-Null
    } elseif ($ship -match "[*?]") {
        $decision = "DENY"
        $denialReason = "wildcard-ship"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
        $reasons.Add("wildcard-ship") | Out-Null
    } elseif ($ship -match ",|\s+\+\s+|\[|\]") {
        $decision = "DENY"
        $denialReason = "multi-ship"
        $approvalRequirement = "not_approvable"
        $fixtureName = "multi-ship-denied"
        $reasons.Add("multi-ship") | Out-Null
    } else {
        $reasons.Add("selected-ship-present") | Out-Null
    }

    $secretLikePath = @($RequestedPaths | Where-Object { ([string]$_) -match "(?i)(^|[\\/])\.env($|[\\/])|([\\/]\.git[\\/])|secret|token|credential|private[-_]?key|auth|payment|stripe|deploy" })
    if ($decision -eq "ALLOW" -and $secretLikePath.Count -gt 0) {
        $decision = "DENY"
        $denialReason = "secret-like-path"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
        $riskClass = "forbidden"
        $reasons.Add("secret-like-path") | Out-Null
        $reasons.Add("forbidden-scope") | Out-Null
    }

    if ($decision -eq "ALLOW" -and $entrypointValue -in $legacyEntrypoints) {
        $decision = "DEFER"
        $denialReason = "legacy-broad-entrypoint"
        $approvalRequirement = "captain_legacy_broad"
        $fixtureName = "legacy-broad-entrypoint-deferred"
        $reasons.Add("legacy-broad-entrypoint") | Out-Null
    }

    if ($decision -eq "ALLOW" -and ($MobileRequestInput -or $entrypointValue -in $mobileEntrypoints)) {
        $decision = "DENY"
        $denialReason = "mobile-request-non-executable"
        $approvalRequirement = "not_approvable"
        $fixtureName = "mobile-request-non-executable"
        $reasons.Add("mobile-request-non-executable") | Out-Null
    }

    if ($decision -eq "ALLOW" -and ($ExternalReportInput -or $entrypointValue -in $externalReviewEntrypoints)) {
        $decision = "DENY"
        $denialReason = "external-report-non-executable"
        $approvalRequirement = "external_audit_review"
        $fixtureName = "external-report-non-executable"
        $reasons.Add("external-report-non-executable") | Out-Null
    }

    $hasControlOrBidiText = (![string]::IsNullOrEmpty($RawInputText) -and $RawInputText -match "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u202A-\u202E\u2066-\u2069]")
    $ambiguousRequestedPath = @($RequestedPaths | Where-Object {
        $path = [string]$_
        $path -match "(^|[\\/])\.\.([\\/]|$)" -or
        $path -match "[\x00-\x1F\x7F\u202A-\u202E\u2066-\u2069]" -or
        $path -match "^[\\/]?~([\\/]|$)" -or
        $path -match "^[A-Za-z]:\s*$"
    })

    if ($decision -eq "ALLOW" -and ($DocxReportInput -or $AuditPackageInput -or $QueueProseInput -or $MalformedInput -or $UnauthorizedEvidence -or $BroadInput -or $hasControlOrBidiText -or $ambiguousRequestedPath.Count -gt 0)) {
        $decision = "DENY"
        $denialReason = "forbidden-scope"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
        $riskClass = "forbidden"
        $reasons.Add("forbidden-scope") | Out-Null
    }

    if ($decision -eq "ALLOW" -and $actionValue -eq "IMPORT_APPROVED_PACKET" -and !$TaskPacketValidated) {
        $decision = "DENY"
        $denialReason = "task-packet-not-validated"
        $approvalRequirement = "captain_packet_import"
        $fixtureName = "forbidden-scope-denied"
        $reasons.Add("task-packet-not-validated") | Out-Null
    }

    if ($decision -eq "ALLOW" -and [string]::IsNullOrWhiteSpace($RepoFingerprintRef)) {
        $decision = "DENY"
        $denialReason = "missing-repo-fingerprint"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
        $reasons.Add("missing-repo-fingerprint") | Out-Null
    }

    if ($decision -eq "ALLOW" -and [string]::IsNullOrWhiteSpace($WorktreeBoundaryRef)) {
        $decision = "DENY"
        $denialReason = "missing-worktree-boundary"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
        $reasons.Add("missing-worktree-boundary") | Out-Null
    }

    if ($decision -eq "ALLOW" -and $StaleFingerprint) {
        $decision = "DENY"
        $denialReason = "stale-fingerprint"
        $approvalRequirement = "not_approvable"
        $fixtureName = "stale-fingerprint-denied"
        $reasons.Add("stale-fingerprint") | Out-Null
    }

    if ($decision -eq "ALLOW" -and $actionValue -in @("RUN_ONE_BATCH", "MAKE_AUDIT_PACKAGE", "IMPORT_APPROVED_PACKET", "WRITE_REPAIR_TASK", "PARK_SHIP") -and !$CaptainApproval) {
        $decision = "DEFER"
        $denialReason = "missing-approval"
        $approvalRequirement = if ($actionValue -eq "IMPORT_APPROVED_PACKET") { "captain_packet_import" } elseif ($actionValue -eq "MAKE_AUDIT_PACKAGE") { "captain_selected_project" } else { "captain_exact_action" }
        $fixtureName = "missing-approval-deferred"
        $reasons.Add("missing-approval") | Out-Null
    }

    if ($PolicyVersion -ne "runtime-policy-v1") {
        $decision = "DENY"
        $denialReason = "unknown-policy-version"
        $approvalRequirement = "not_approvable"
        $fixtureName = "forbidden-scope-denied"
    }

    $dryRunResult = switch ($decision) {
        "ALLOW" { "ALLOW_DRY_RUN" }
        "DEFER" { "DEFER_NEEDS_HUMAN" }
        default { "DENY_UNSAFE" }
    }

    $reasons.Add("model-cannot-grant-permission") | Out-Null
    $reasons.Add("policy-version-recorded") | Out-Null
    if (@($EvidenceRefs).Count -gt 0) {
        $reasons.Add("evidence-recorded") | Out-Null
    }

    $record = [pscustomobject]@{
        schemaVersion = 1
        policyVersion = $PolicyVersion
        decisionId = "policy:$($ship -replace '[^A-Za-z0-9_.-]+','-'):$($GeneratedAt.ToUniversalTime().ToString("yyyyMMddHHmmss"))"
        selectedShipId = $ship
        entrypoint = $entrypointValue
        action = $actionValue
        riskClass = $riskClass
        decision = $decision
        dryRunResult = $dryRunResult
        approvalRequirement = $approvalRequirement
        denialReason = $denialReason
        repoFingerprintRef = $RepoFingerprintRef
        worktreeBoundaryRef = $WorktreeBoundaryRef
        budgetRecordRef = $BudgetRecordRef
        evidenceRefs = @($EvidenceRefs)
        generatedAt = $GeneratedAt.ToUniversalTime().ToString("o")
        validation = [pscustomobject]@{
            status = if ($decision -eq "ALLOW") { "valid" } else { "invalid" }
            reasons = @($reasons | Select-Object -Unique)
            fixtureName = $fixtureName
        }
    }

    if ($IncludeEvidenceBundle) {
        $approvalRef = if (![string]::IsNullOrWhiteSpace($ApprovalEvidenceRef)) { $ApprovalEvidenceRef } elseif ($CaptainApproval) { "approval:captain:fixture" } else { "approval:missing" }
        $bundleReasons = @(
            "bundle-local-dry-run-only",
            "selected-ship-ref-required",
            "repo-fingerprint-ref-required",
            "worktree-boundary-ref-required",
            "lease-heartbeat-ref-required",
            "failure-fingerprint-ref-required",
            "approval-evidence-ref-required",
            "budget-evidence-ref-required",
            "source-provenance-recorded",
            "generated-evidence-non-executable",
            "missing-or-stale-ref-denies-or-defers",
            "never-executes"
        )
        $record | Add-Member -NotePropertyName evidenceBundle -NotePropertyValue ([pscustomobject]@{
            selectedShipId = $ship
            entrypoint = $entrypointValue
            action = $actionValue
            repoFingerprintRef = $RepoFingerprintRef
            worktreeBoundaryRef = $WorktreeBoundaryRef
            leaseHeartbeatRef = $LeaseHeartbeatRef
            failureFingerprintRef = $FailureFingerprintRef
            approvalEvidenceRef = $approvalRef
            budgetEvidenceRef = $BudgetRecordRef
            sourceProvenance = [pscustomobject]@{
                sourceType = $SourceProvenanceType
                sourceRef = $SourceProvenanceRef
                nonExecutable = $true
            }
            generatedAt = $GeneratedAt.ToUniversalTime().ToString("o")
            validation = [pscustomobject]@{
                status = if ($decision -eq "ALLOW") { "valid" } else { "invalid" }
                reasons = $bundleReasons
            }
        })
    }

    return $record
}

function Write-FleetSelectedShipLedgerDryRun {
    param(
        [string]$SelectedShipId = "",
        [string]$RepoFingerprintRef = "",
        [string]$PolicyDecisionRef = "",
        [string]$Owner = "",
        [string]$FixtureRoot = "",
        [string]$OutPath = "",
        [string[]]$EvidenceRefs = @(),
        [string]$ExpiresAt = ""
    )

    $createdAt = (Get-Date).ToUniversalTime().ToString("o")
    if ([string]::IsNullOrWhiteSpace($ExpiresAt)) {
        $ExpiresAt = (Get-Date).ToUniversalTime().AddHours(4).ToString("o")
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $fixtureName = "valid-fixture-dry-run"
    $valid = $true

    $ship = ([string]$SelectedShipId).Trim()
    if ([string]::IsNullOrWhiteSpace($ship)) {
        $valid = $false
        $fixtureName = "blank-ship"
        $reasons.Add("blank-ship") | Out-Null
    } elseif ($ship -in @("all", "ALL")) {
        $valid = $false
        $fixtureName = "all-ship"
        $reasons.Add("all-ship") | Out-Null
    } elseif ($ship -match "[*?]") {
        $valid = $false
        $fixtureName = "wildcard-ship"
        $reasons.Add("wildcard-ship") | Out-Null
    } elseif ($ship -match ",|\s+\+\s+|\[|\]") {
        $valid = $false
        $fixtureName = "multi-ship"
        $reasons.Add("multi-ship") | Out-Null
    } else {
        $reasons.Add("single-selected-ship") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($RepoFingerprintRef)) {
        $valid = $false
        $reasons.Add("repo-fingerprint-ref-required") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($PolicyDecisionRef)) {
        $valid = $false
        $reasons.Add("policy-decision-ref-required") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($Owner)) {
        $valid = $false
        $reasons.Add("owner-required") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
        $valid = $false
        $reasons.Add("fixture-root-required") | Out-Null
    }

    $resolvedOutPath = ""
    if ($valid) {
        $fixtureFull = [System.IO.Path]::GetFullPath($FixtureRoot)
        if (!$fixtureFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $fixtureFull += [System.IO.Path]::DirectorySeparatorChar
        }
        if ([string]::IsNullOrWhiteSpace($OutPath)) {
            $OutPath = Join-Path $fixtureFull "selected-ship-ledger.json"
        }
        $resolvedOutPath = if ([System.IO.Path]::IsPathRooted($OutPath)) {
            [System.IO.Path]::GetFullPath($OutPath)
        } else {
            [System.IO.Path]::GetFullPath((Join-Path $fixtureFull $OutPath))
        }
        if (!$resolvedOutPath.StartsWith($fixtureFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $valid = $false
            $fixtureName = "fixture-root-escape"
            $reasons.Add("fixture-root-escape") | Out-Null
        }
    }

    if (@($EvidenceRefs).Count -gt 0) {
        $reasons.Add("evidence-recorded") | Out-Null
    }
    $reasons.Add("dry-run-only") | Out-Null

    $safeShip = if ([string]::IsNullOrWhiteSpace($ship)) { "none" } else { ($ship -replace "[^a-zA-Z0-9_.-]+", "-").Trim("-") }
    if ([string]::IsNullOrWhiteSpace($safeShip)) { $safeShip = "none" }
    $record = [pscustomobject]@{
        schemaVersion = 1
        ledgerId = "selected-$safeShip-$(Get-Date -Format 'yyyyMMddHHmmss')"
        selectedShipId = $ship
        repoFingerprintRef = $RepoFingerprintRef
        policyDecisionRef = $PolicyDecisionRef
        owner = $Owner
        createdAt = $createdAt
        expiresAt = $ExpiresAt
        status = if ($valid) { "dry-run-only" } else { "denied" }
        evidenceRefs = @($EvidenceRefs)
        dryRun = $true
        validation = [pscustomobject]@{
            status = if ($valid) { "valid" } else { "invalid" }
            reasons = @($reasons)
            fixtureName = $fixtureName
        }
    }

    $written = $false
    if ($valid) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutPath) | Out-Null
        $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutPath -Encoding UTF8
        $written = $true
    }

    return [pscustomobject]@{
        written = $written
        path = $resolvedOutPath
        record = $record
    }
}
