function ConvertTo-FleetSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $safe = ($Name -replace "[^a-zA-Z0-9_.-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safe)) { return "unnamed" }
    return $safe
}

function Get-FleetShipStateValues {
    return @(
        "UNKNOWN",
        "READY",
        "RUNNING",
        "REVIEWING",
        "AUDIT_READY",
        "PACKET_READY",
        "REPAIRING",
        "BLOCKED",
        "TASTE_GATE",
        "RATE_LIMIT_PAUSED",
        "PARKED",
        "ARCHIVED"
    )
}

function Test-FleetShipStateStatus {
    param([Parameter(Mandatory = $true)][string]$Status)
    return ((Get-FleetShipStateValues) -contains $Status.ToUpperInvariant())
}

function Get-FleetShipStateTransitionMap {
    return @{
        UNKNOWN = @("READY", "BLOCKED", "PARKED", "ARCHIVED")
        READY = @("RUNNING", "PARKED", "BLOCKED", "ARCHIVED")
        RUNNING = @("REVIEWING", "REPAIRING", "BLOCKED", "RATE_LIMIT_PAUSED", "ARCHIVED")
        REVIEWING = @("AUDIT_READY", "TASTE_GATE", "REPAIRING", "BLOCKED", "PARKED", "ARCHIVED")
        AUDIT_READY = @("PACKET_READY", "PARKED", "BLOCKED", "ARCHIVED")
        PACKET_READY = @("READY", "BLOCKED", "ARCHIVED")
        REPAIRING = @("RUNNING", "BLOCKED", "PARKED", "ARCHIVED")
        BLOCKED = @("REPAIRING", "READY", "PARKED", "ARCHIVED")
        TASTE_GATE = @("PACKET_READY", "READY", "PARKED", "ARCHIVED")
        RATE_LIMIT_PAUSED = @("READY", "RUNNING", "PARKED", "BLOCKED", "ARCHIVED")
        PARKED = @("READY", "PACKET_READY", "ARCHIVED")
        ARCHIVED = @()
    }
}

function Test-FleetShipStateTransition {
    param(
        [Parameter(Mandatory = $true)][string]$FromStatus,
        [Parameter(Mandatory = $true)][string]$ToStatus
    )

    $from = $FromStatus.ToUpperInvariant()
    $to = $ToStatus.ToUpperInvariant()
    if (!(Test-FleetShipStateStatus -Status $from) -or !(Test-FleetShipStateStatus -Status $to)) {
        return $false
    }
    if ($from -eq $to) { return $true }
    $map = Get-FleetShipStateTransitionMap
    return @($map[$from]) -contains $to
}

function New-FleetShipStateRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Ship,
        [string]$Status = "UNKNOWN",
        [string]$PreviousStatus = "",
        [string]$Repo = "",
        [string]$Phase = "",
        [string]$RiskTier = "",
        [int]$ActivePid = 0,
        [string]$LockStatus = "unknown",
        [string]$HeartbeatFreshness = "unknown",
        [Nullable[bool]]$RepoClean = $null,
        [int]$TasksRemaining = 0,
        [int]$QuarantinedTasks = 0,
        [string]$LastRunId = "",
        [string]$LastRunResultPath = "",
        [string]$LastAuditPackagePath = "",
        [string]$LastTaskPacketPath = "",
        [hashtable]$Gates = @{},
        [string]$RateLimitPausedUntil = "",
        [string]$RateLimitReason = "",
        [string[]]$Blockers = @(),
        [string[]]$TasteGateReasons = @(),
        [string[]]$EvidencePaths = @(),
        [string]$Reason = "",
        [string]$NextSafeHumanAction = "Inspect state evidence before acting."
    )

    $normalizedStatus = $Status.ToUpperInvariant()
    if (!(Test-FleetShipStateStatus -Status $normalizedStatus)) {
        throw "Invalid ship state status: $Status"
    }
    if (![string]::IsNullOrWhiteSpace($PreviousStatus) -and !(Test-FleetShipStateStatus -Status $PreviousStatus.ToUpperInvariant())) {
        throw "Invalid previous ship state status: $PreviousStatus"
    }

    return [pscustomobject]@{
        schemaVersion = 1
        ship = $Ship
        repo = $Repo
        status = $normalizedStatus
        previousStatus = $PreviousStatus.ToUpperInvariant()
        phase = $Phase
        riskTier = $RiskTier
        activePid = $ActivePid
        lockStatus = $LockStatus
        heartbeatFreshness = $HeartbeatFreshness
        repoClean = $RepoClean
        tasksRemaining = $TasksRemaining
        quarantinedTasks = $QuarantinedTasks
        lastRunId = $LastRunId
        lastRunResultPath = $LastRunResultPath
        lastAuditPackagePath = $LastAuditPackagePath
        lastTaskPacketPath = $LastTaskPacketPath
        gates = [pscustomobject]$Gates
        rateLimit = [pscustomobject]@{
            pausedUntil = $RateLimitPausedUntil
            reason = $RateLimitReason
        }
        blockers = @($Blockers)
        tasteGateReasons = @($TasteGateReasons)
        evidence = @($EvidencePaths)
        reason = $Reason
        nextSafeHumanAction = $NextSafeHumanAction
        updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Read-FleetShipStateFile {
    param([string]$StatePath)

    if (!(Test-Path -LiteralPath $StatePath)) {
        return [pscustomobject]@{
            schemaVersion = 1
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            ships = @()
        }
    }
    return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
}

function Write-FleetCurrentStateMarkdown {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Repo
    )

    $docsPath = Join-Path ([System.IO.Path]::GetFullPath($Repo)) "docs\codex"
    New-Item -ItemType Directory -Force -Path $docsPath | Out-Null
    $path = Join-Path $docsPath "CURRENT_STATE.md"
    $blockers = if (@($State.blockers).Count -gt 0) { @($State.blockers) -join "; " } else { "None recorded." }
    $taste = if (@($State.tasteGateReasons).Count -gt 0) { @($State.tasteGateReasons) -join "; " } else { "None recorded." }
    $evidence = if (@($State.evidence).Count -gt 0) { @($State.evidence) } else { @("None recorded.") }
    $lines = @(
        "# Current State",
        "",
        "- Ship: $($State.ship)",
        "- Current status: $($State.status)",
        "- Previous status: $($State.previousStatus)",
        "- Last updated: $($State.updatedAt)",
        "- Current phase or lane: $($State.phase)",
        "- Risk tier: $($State.riskTier)",
        "- Repo clean: $($State.repoClean)",
        "- Active PID: $($State.activePid)",
        "- Lock status: $($State.lockStatus)",
        "- Heartbeat freshness: $($State.heartbeatFreshness)",
        "- Tasks remaining: $($State.tasksRemaining)",
        "- Quarantined tasks: $($State.quarantinedTasks)",
        "- Last run result: $($State.lastRunResultPath)",
        "- Latest audit package: $($State.lastAuditPackagePath)",
        "- Latest accepted task packet: $($State.lastTaskPacketPath)",
        "- Rate-limit pause: $($State.rateLimit.reason) $($State.rateLimit.pausedUntil)",
        "",
        "## Active Blockers",
        "",
        $blockers,
        "",
        "## Taste Gate Notes",
        "",
        $taste,
        "",
        "## Evidence",
        ""
    )
    foreach ($item in $evidence) { $lines += "- $item" }
    $lines += @(
        "",
        "## Next Safe Human Action",
        "",
        $State.nextSafeHumanAction,
        "",
        "## Reason",
        "",
        $(if ([string]::IsNullOrWhiteSpace([string]$State.reason)) { "No reason recorded." } else { [string]$State.reason })
    )
    $lines | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Set-FleetShipState {
    param(
        [Parameter(Mandatory = $true)][string]$FleetRoot,
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$WriteCurrentState
    )

    $stateRoot = Join-Path ([System.IO.Path]::GetFullPath($FleetRoot)) "fleet\state"
    New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
    $statePath = Join-Path $stateRoot "ship-state.json"
    $fleetState = Read-FleetShipStateFile -StatePath $statePath
    $ships = @($fleetState.ships | Where-Object { [string]$_.ship -ne [string]$State.ship })
    $ships += $State
    $out = [pscustomobject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        ships = @($ships | Sort-Object ship)
    }
    $out | ConvertTo-Json -Depth 12 | Set-Content -Path $statePath -Encoding UTF8
    $currentStatePath = ""
    if ($WriteCurrentState -and ![string]::IsNullOrWhiteSpace([string]$State.repo) -and (Test-Path -LiteralPath ([string]$State.repo))) {
        $currentStatePath = Write-FleetCurrentStateMarkdown -State $State -Repo ([string]$State.repo)
    }
    return [pscustomobject]@{ statePath = $statePath; currentStatePath = $currentStatePath; state = $State }
}

function Resolve-FleetShipStateFromEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Ship,
        [string]$Repo = "",
        [string]$RepoState = "",
        [bool]$RepoClean = $false,
        [bool]$ActiveOwnedWork = $false,
        [string]$LockStatus = "none",
        [string]$HeartbeatFreshness = "unknown",
        [int]$TasksRemaining = 0,
        [int]$QuarantinedTasks = 0,
        [string]$LastRunStatus = "",
        [string]$LastRunResultPath = "",
        [string]$LastAuditPackagePath = "",
        [string]$LastTaskPacketPath = "",
        [bool]$RepairTaskExists = $false,
        [bool]$TasteGateRequired = $false,
        [bool]$RateLimitPaused = $false,
        [bool]$Archived = $false,
        [string]$Phase = "",
        [string]$RiskTier = "",
        [string[]]$EvidencePaths = @()
    )

    $status = "UNKNOWN"
    $reason = "Evidence was incomplete or conflicting."
    $blockers = @()
    $tasteReasons = @()
    $nextAction = "Inspect state evidence before acting."
    $effectiveRepoState = if (![string]::IsNullOrWhiteSpace($RepoState)) { $RepoState } elseif (![string]::IsNullOrWhiteSpace($Repo) -and (Test-Path -LiteralPath $Repo)) { (Get-FleetRepoState -Repo $Repo).state } else { "" }

    if ($Archived) {
        $status = "ARCHIVED"; $reason = "Ship is archived."; $nextAction = "Do not act unless the captain reactivates it."
    } elseif ($RateLimitPaused) {
        $status = "RATE_LIMIT_PAUSED"; $reason = "Rate-limit pause evidence is present."; $nextAction = "Wait for approved budget/reset handling."
    } elseif ($ActiveOwnedWork) {
        $status = "RUNNING"; $reason = "Active owned PID, lock, or fresh heartbeat is present."; $nextAction = "Leave it alone; active work owns the repo."
    } elseif ($effectiveRepoState -in @("missing", "git-error")) {
        $status = "UNKNOWN"; $reason = "Repository state is $effectiveRepoState."; $blockers += $reason; $nextAction = "Fix repo/config evidence before launching."
    } elseif (!$RepoClean -and $effectiveRepoState -eq "dirty") {
        $status = "BLOCKED"; $reason = "Repo is dirty without active owned work."; $blockers += $reason; $nextAction = "Inspect ownership before touching files."
    } elseif ($QuarantinedTasks -gt 0 -or ($LastRunStatus -match "(?i)(fail|red|blocked)" -and $RepairTaskExists)) {
        $status = "REPAIRING"; $reason = "Failure/quarantine evidence has a bounded repair path."; $nextAction = "Review repair evidence before running a repair batch."
    } elseif ($LastRunStatus -match "(?i)(fail|red|blocked)") {
        $status = "BLOCKED"; $reason = "Latest deterministic gate failed without a safe repair path."; $blockers += $reason; $nextAction = "Human review required."
    } elseif ($TasteGateRequired) {
        $status = "TASTE_GATE"; $reason = "Deterministic gates passed but subjective taste remains."; $tasteReasons += $reason; $nextAction = "Captain should approve direction or import a task packet."
    } elseif (![string]::IsNullOrWhiteSpace($LastTaskPacketPath) -and $TasksRemaining -gt 0) {
        $status = "PACKET_READY"; $reason = "A valid imported packet exists with accepted tasks."; $nextAction = "Stage 6+ may decide readiness; Stage 5 only records this."
    } elseif (![string]::IsNullOrWhiteSpace($LastAuditPackagePath) -or $LastRunStatus -match "(?i)AUDIT") {
        $status = "AUDIT_READY"; $reason = "Run evidence is ready for audit or external review."; $nextAction = "Send audit package or wait for review."
    } elseif ($TasksRemaining -gt 0 -and ($RepoClean -or $effectiveRepoState -eq "clean")) {
        $status = "READY"; $reason = "Repo is clean and valid tasks remain."; $nextAction = "Eligible for a later-stage decision."
    } elseif (($RepoClean -or $effectiveRepoState -eq "clean") -and $TasksRemaining -eq 0) {
        $status = "PARKED"; $reason = "Clean repo with no remaining useful tasks."; $nextAction = "Leave parked until a new approved task packet or command."
    }

    return New-FleetShipStateRecord -Ship $Ship -Repo $Repo -Status $status -Phase $Phase -RiskTier $RiskTier -LockStatus $LockStatus -HeartbeatFreshness $HeartbeatFreshness -RepoClean $RepoClean -TasksRemaining $TasksRemaining -QuarantinedTasks $QuarantinedTasks -LastRunResultPath $LastRunResultPath -LastAuditPackagePath $LastAuditPackagePath -LastTaskPacketPath $LastTaskPacketPath -Blockers $blockers -TasteGateReasons $tasteReasons -EvidencePaths $EvidencePaths -Reason $reason -NextSafeHumanAction $nextAction
}

function Get-FleetRepoState {
    param([Parameter(Mandatory = $true)][string]$Repo)

    $fullPath = try { [System.IO.Path]::GetFullPath($Repo) } catch { $Repo }
    if (!(Test-Path -LiteralPath $fullPath)) {
        return [pscustomobject]@{
            state = "missing"
            repo = $fullPath
            clean = $false
            dirty = $false
            changedFiles = @()
            branch = ""
            head = ""
            message = "Repository path is missing."
            gitError = ""
        }
    }

    Push-Location $fullPath
    try {
        $topLevelOutput = @(git rev-parse --show-toplevel 2>&1 | ForEach-Object { [string]$_ })
        if ($LASTEXITCODE -ne 0) {
            return [pscustomobject]@{
                state = "git-error"
                repo = $fullPath
                clean = $false
                dirty = $false
                changedFiles = @()
                branch = ""
                head = ""
                message = "git rev-parse failed."
                gitError = ($topLevelOutput -join "`n")
            }
        }

        $topLevel = try { [System.IO.Path]::GetFullPath(($topLevelOutput | Select-Object -First 1)) } catch { ($topLevelOutput | Select-Object -First 1) }
        if ($topLevel.TrimEnd("\", "/") -ne $fullPath.TrimEnd("\", "/")) {
            return [pscustomobject]@{
                state = "git-error"
                repo = $fullPath
                clean = $false
                dirty = $false
                changedFiles = @()
                branch = ""
                head = ""
                message = "Path is not the configured git repository root."
                gitError = "Resolved git root is $topLevel"
            }
        }

        $statusOutput = @(git status --short 2>&1 | ForEach-Object { [string]$_ })
        if ($LASTEXITCODE -ne 0) {
            return [pscustomobject]@{
                state = "git-error"
                repo = $fullPath
                clean = $false
                dirty = $false
                changedFiles = @()
                branch = ""
                head = ""
                message = "git status failed."
                gitError = ($statusOutput -join "`n")
            }
        }

        $branch = ((git rev-parse --abbrev-ref HEAD 2>$null) | Select-Object -First 1)
        $head = ((git rev-parse --short HEAD 2>$null) | Select-Object -First 1)
        $changed = @($statusOutput | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        $state = if ($changed.Count -eq 0) { "clean" } else { "dirty" }
        return [pscustomobject]@{
            state = $state
            repo = $fullPath
            clean = ($state -eq "clean")
            dirty = ($state -eq "dirty")
            changedFiles = $changed
            branch = if ($branch) { [string]$branch } else { "" }
            head = if ($head) { [string]$head } else { "" }
            message = if ($state -eq "clean") { "Working tree is clean." } else { "Working tree has $($changed.Count) changed file(s)." }
            gitError = ""
        }
    } catch {
        return [pscustomobject]@{
            state = "git-error"
            repo = $fullPath
            clean = $false
            dirty = $false
            changedFiles = @()
            branch = ""
            head = ""
            message = "git status threw an exception."
            gitError = $_.Exception.Message
        }
    } finally {
        Pop-Location
    }
}

function New-FleetRepoFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$ShipId,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$WorktreePath = "",
        [string]$ExpectedHead = "",
        [string[]]$EvidenceRefs = @(),
        [string]$FixtureRoot = "",
        [int]$MaxChangedFiles = 50
    )

    $generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    $safeShip = ConvertTo-FleetSafeFileName -Name $ShipId
    $fullRepoRoot = try { [System.IO.Path]::GetFullPath($RepoRoot) } catch { $RepoRoot }
    $fullWorktreePath = if (![string]::IsNullOrWhiteSpace($WorktreePath)) {
        try { [System.IO.Path]::GetFullPath($WorktreePath) } catch { $WorktreePath }
    } else {
        $fullRepoRoot
    }

    $validationStatus = "valid"
    $reasons = [System.Collections.Generic.List[string]]::new()
    $dirtyState = "git-error"
    $branch = ""
    $head = ""
    $gitTopLevel = $fullRepoRoot
    $changedFiles = @()
    $changedFileCount = 0
    $truncated = $false

    $pathTraversal = $false
    if ([string]::IsNullOrWhiteSpace($ShipId) -or [string]$ShipId -in @("all", "ALL", "*") -or [string]$ShipId -match "[,*?]") {
        $pathTraversal = $true
    }
    if ([string]::IsNullOrWhiteSpace($RepoRoot) -or [string]$RepoRoot -match "[*?]" -or [string]$RepoRoot -match "(^|[\\/])\.\.([\\/]|$)") {
        $pathTraversal = $true
    }
    if (![string]::IsNullOrWhiteSpace($FixtureRoot)) {
        $fixtureFull = [System.IO.Path]::GetFullPath($FixtureRoot)
        if (!$fixtureFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $fixtureFull += [System.IO.Path]::DirectorySeparatorChar
        }
        $repoForCompare = $fullRepoRoot
        if (!$repoForCompare.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $repoForCompare += [System.IO.Path]::DirectorySeparatorChar
        }
        if (!$repoForCompare.StartsWith($fixtureFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $pathTraversal = $true
        }
    }

    if ($pathTraversal) {
        $dirtyState = "path-traversal"
        $validationStatus = "invalid"
        $reasons.Add("path-traversal") | Out-Null
    } else {
        $repoState = Get-FleetRepoState -Repo $fullRepoRoot
        $branch = [string]$repoState.branch
        $head = [string]$repoState.head
        $changedFiles = @($repoState.changedFiles | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        $changedFileCount = $changedFiles.Count
        if ($changedFiles.Count -gt $MaxChangedFiles) {
            $changedFiles = @($changedFiles | Select-Object -First $MaxChangedFiles)
            $truncated = $true
        }

        switch ([string]$repoState.state) {
            "clean" {
                $dirtyState = "clean"
                $reasons.Add("clean") | Out-Null
            }
            "dirty" {
                $dirtyState = "dirty"
                $reasons.Add("dirty") | Out-Null
            }
            "missing" {
                $dirtyState = "missing"
                $validationStatus = "invalid"
                $reasons.Add("missing-repo") | Out-Null
            }
            default {
                if ([string]$repoState.message -match "not the configured git repository root") {
                    $dirtyState = "wrong-root"
                    $reasons.Add("wrong-root") | Out-Null
                } else {
                    $dirtyState = "git-error"
                    $reasons.Add("git-error") | Out-Null
                }
                $validationStatus = "invalid"
            }
        }

        if ($dirtyState -in @("clean", "dirty")) {
            Push-Location $fullRepoRoot
            try {
                $topLevelOutput = @(git rev-parse --show-toplevel 2>$null | ForEach-Object { [string]$_ })
                if ($LASTEXITCODE -eq 0 -and $topLevelOutput.Count -gt 0) {
                    $gitTopLevel = [System.IO.Path]::GetFullPath(($topLevelOutput | Select-Object -First 1))
                }
            } finally {
                Pop-Location
            }
        } elseif ($dirtyState -eq "wrong-root" -and ![string]::IsNullOrWhiteSpace([string]$repoState.gitError) -and [string]$repoState.gitError -match "Resolved git root is (.+)$") {
            $gitTopLevel = [System.IO.Path]::GetFullPath($matches[1].Trim())
        }

        if (![string]::IsNullOrWhiteSpace($ExpectedHead) -and ![string]::IsNullOrWhiteSpace($head) -and $ExpectedHead -ne $head) {
            $dirtyState = "stale-head"
            $validationStatus = "invalid"
            if (!$reasons.Contains("stale-head")) { $reasons.Add("stale-head") | Out-Null }
        }
    }

    if ([string]::IsNullOrWhiteSpace($WorktreePath)) {
        $reasons.Add("worktree-missing") | Out-Null
    }
    if (@($EvidenceRefs).Count -eq 0) {
        $reasons.Add("evidence-missing") | Out-Null
        if ($dirtyState -eq "dirty") {
            $validationStatus = "unknown"
            $reasons.Add("dirty-state-ambiguous") | Out-Null
        }
    }

    $headForId = if (![string]::IsNullOrWhiteSpace($head)) { $head } else { "unknown" }
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    return [pscustomobject]@{
        schemaVersion = 1
        fingerprintId = "repo-$safeShip-$dirtyState-$($headForId.Substring(0, [Math]::Min(8, $headForId.Length)))-$stamp"
        shipId = $ShipId
        repoRoot = $fullRepoRoot
        gitTopLevel = $gitTopLevel
        branch = if (![string]::IsNullOrWhiteSpace($branch)) { $branch } else { "unknown" }
        head = $headForId
        dirtyState = $dirtyState
        changedFileSummary = [pscustomobject]@{
            count = $changedFileCount
            files = @($changedFiles)
            truncated = $truncated
        }
        worktreePath = $fullWorktreePath
        generatedAt = $generatedAt
        evidenceRefs = @($EvidenceRefs)
        validation = [pscustomobject]@{
            status = $validationStatus
            reasons = @($reasons)
        }
    }
}

function Test-FleetWorktreeBoundary {
    param(
        [Parameter(Mandatory = $true)][object]$Boundary,
        [string]$SelectedShipId = "",
        [string]$FixtureRoot = ""
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $status = "valid"
    $addReason = {
        param([string]$Reason)
        if (!$reasons.Contains($Reason)) { $reasons.Add($Reason) | Out-Null }
    }
    $normalizePath = {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
        try { return [System.IO.Path]::GetFullPath($Path).TrimEnd("\", "/") } catch { return $Path.TrimEnd("\", "/") }
    }
    $withTrailingSeparator = {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
        if ($Path.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or $Path.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) { return $Path }
        return ($Path + [System.IO.Path]::DirectorySeparatorChar)
    }

    $shipId = ([string]$Boundary.shipId).Trim()
    $selected = ([string]$SelectedShipId).Trim()
    if ([string]::IsNullOrWhiteSpace($selected)) { $selected = $shipId }

    if ([string]::IsNullOrWhiteSpace($shipId) -or $shipId -in @("all", "ALL", "*") -or $shipId -match "[,*?]") {
        $status = "invalid"
        & $addReason "broad-ship-selection"
    } else {
        & $addReason "single-selected-ship"
    }

    if (![string]::IsNullOrWhiteSpace($selected) -and $selected -ne $shipId) {
        $status = "invalid"
        & $addReason "ship-mismatch"
    }

    $sourceRepoRoot = ([string]$Boundary.sourceRepoRoot).Trim()
    $sourceGitTopLevel = ([string]$Boundary.sourceGitTopLevel).Trim()
    $worktreePath = ([string]$Boundary.worktreePath).Trim()

    if ([string]::IsNullOrWhiteSpace($worktreePath)) {
        $status = "invalid"
        & $addReason "missing-worktree"
    }

    $sourceFull = & $normalizePath $sourceRepoRoot
    $gitTopFull = & $normalizePath $sourceGitTopLevel
    $worktreeFull = & $normalizePath $worktreePath

    if (![string]::IsNullOrWhiteSpace($sourceFull) -and ![string]::IsNullOrWhiteSpace($gitTopFull) -and $sourceFull -ne $gitTopFull) {
        $status = "invalid"
        & $addReason "source-root-mismatch"
    }

    if (![string]::IsNullOrWhiteSpace($sourceFull) -and ![string]::IsNullOrWhiteSpace($worktreeFull) -and $sourceFull -eq $worktreeFull) {
        $status = "invalid"
        & $addReason "direct-product-root-mutation"
    }

    if (![string]::IsNullOrWhiteSpace($FixtureRoot)) {
        $fixtureFull = & $normalizePath $FixtureRoot
        $fixtureCompare = & $withTrailingSeparator $fixtureFull
        foreach ($candidate in @($sourceFull, $gitTopFull, $worktreeFull)) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            $candidateCompare = & $withTrailingSeparator $candidate
            if ($candidateCompare.StartsWith($fixtureCompare, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $status = "invalid"
            & $addReason "fixture-root-escape"
            break
        }
    }

    if ([string]$Boundary.cleanupPosture -eq "safe-dispose-fixture-only" -or [string]$Boundary.boundaryState -eq "fixture-only") {
        & $addReason "fixture-only-exception"
    }
    if ([string]$Boundary.cleanupPosture -eq "do-not-delete-locks") {
        & $addReason "lock-deletion-forbidden"
    }

    $branch = ([string]$Boundary.branch).Trim()
    $owner = ([string]$Boundary.owner).Trim()
    $leaseId = ([string]$Boundary.leaseId).Trim()
    $boundaryState = ([string]$Boundary.boundaryState).Trim()
    $evidenceRefs = @($Boundary.evidenceRefs | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })
    if (
        [string]::IsNullOrWhiteSpace($branch) -or
        [string]::IsNullOrWhiteSpace($owner) -or
        [string]::IsNullOrWhiteSpace($leaseId) -or
        $evidenceRefs.Count -eq 0 -or
        $boundaryState -in @("planned", "stale", "blocked")
    ) {
        if ($status -eq "valid") { $status = "unknown" }
        & $addReason "ambiguous-boundary"
    }

    return [pscustomobject]@{
        status = $status
        reasons = @($reasons | Select-Object -Unique)
        boundary = $Boundary
    }
}

function New-FleetRunId {
    param([string]$Prefix = "run")
    return ("{0}-{1}" -f $Prefix, (Get-Date -Format "yyyyMMdd-HHmmss"))
}

function Get-FleetTestSummaryStage {
    param([string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) { return "General" }
    if ($Message -match "(?i)\bStage\s+([0-9]+(?:\.[0-9]+)?)\b") { return "Stage $($matches[1])" }
    if ($Message -match "(?i)\bGolden\s+Gameplan\b") { return "Golden Gameplan" }
    if ($Message -match "(?i)\btemporary\s+audit\s+loop\b") { return "Audit Loop Mode" }
    if ($Message -match "(?i)\bpost[- ]golden\b") { return "Post-Golden Hardening" }
    return "General"
}

function ConvertTo-FleetTestSummary {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][object[]]$Checks
    )

    $testChecks = @($Checks | Where-Object {
        $command = [string]$_.command
        $name = [string]$_.name
        $evidenceText = (@($_.evidence) -join " ")
        $command -match "run-fleet-tests\.ps1" -or
        $name -match "(?i)test" -or
        $evidenceText -match "(?i)(test.*stdout|stdout.*test|run-fleet-tests)"
    })
    if ($testChecks.Count -eq 0) { return $null }

    $rows = [System.Collections.Generic.List[object]]::new()
    $fullLogs = [System.Collections.Generic.List[string]]::new()
    foreach ($check in $testChecks) {
        $evidencePaths = @($check.evidence | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        foreach ($path in $evidencePaths) {
            if ($fullLogs -notcontains $path) { $fullLogs.Add($path) | Out-Null }
            $fullPath = Join-Path $RepoPath $path
            if (!(Test-Path -LiteralPath $fullPath)) { continue }
            $lines = @(Get-Content -LiteralPath $fullPath -ErrorAction SilentlyContinue)
            foreach ($line in $lines) {
                if ($line -match "^(PASS|FAIL|WARN|YELLOW|RED):\s*(.+)$") {
                    $rawStatus = $matches[1].ToUpperInvariant()
                    $message = $matches[2].Trim()
                    $result = switch ($rawStatus) {
                        "PASS" { "GREEN" }
                        "FAIL" { "RED" }
                        "RED" { "RED" }
                        default { "YELLOW" }
                    }
                    $rows.Add([pscustomobject]@{
                        stage = Get-FleetTestSummaryStage -Message $message
                        scenario = $message
                        result = $result
                        check = [string]$check.name
                        command = [string]$check.command
                        exitCode = $check.exitCode
                        durationSeconds = $check.durationSeconds
                        evidence = $path
                    }) | Out-Null
                }
            }
        }
        if ($evidencePaths.Count -eq 0) {
            $rows.Add([pscustomobject]@{
                stage = "General"
                scenario = [string]$check.name
                result = if ([string]$check.status -match "(?i)pass|green|success") { "GREEN" } elseif ([string]$check.status -match "(?i)yellow|warn") { "YELLOW" } else { "RED" }
                check = [string]$check.name
                command = [string]$check.command
                exitCode = $check.exitCode
                durationSeconds = $check.durationSeconds
                evidence = ""
            }) | Out-Null
        }
    }

    if ($rows.Count -eq 0) {
        foreach ($check in $testChecks) {
            $rows.Add([pscustomobject]@{
                stage = "General"
                scenario = [string]$check.name
                result = if ([string]$check.status -match "(?i)pass|green|success") { "GREEN" } elseif ([string]$check.status -match "(?i)yellow|warn") { "YELLOW" } else { "RED" }
                check = [string]$check.name
                command = [string]$check.command
                exitCode = $check.exitCode
                durationSeconds = $check.durationSeconds
                evidence = (@($check.evidence) -join ", ")
            }) | Out-Null
        }
    }

    $groups = @($rows | Group-Object -Property stage | Sort-Object Name)
    $overall = if (@($rows | Where-Object { $_.result -eq "RED" }).Count -gt 0 -or @($testChecks | Where-Object { $null -ne $_.exitCode -and [int]$_.exitCode -ne 0 }).Count -gt 0) {
        "RED"
    } elseif (@($rows | Where-Object { $_.result -eq "YELLOW" }).Count -gt 0) {
        "YELLOW"
    } else {
        "GREEN"
    }

    return [pscustomobject]@{
        overall = $overall
        checks = @($testChecks)
        rows = @($rows)
        groups = @($groups)
        fullLogs = @($fullLogs)
    }
}

function Write-FleetTestSummary {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [Parameter(Mandatory = $true)][object[]]$Checks
    )

    $summary = ConvertTo-FleetTestSummary -RepoPath $RepoPath -Checks $Checks
    if ($null -eq $summary) { return "" }

    $lines = @(
        "# Test Summary",
        "",
        "- Generated: $((Get-Date).ToUniversalTime().ToString('o'))",
        "- Overall result: $($summary.overall)",
        "- Check runs: $(@($summary.checks).Count)",
        "- Scenario assertions parsed: $(@($summary.rows).Count)",
        "",
        "## Full Logs",
        ""
    )
    if (@($summary.fullLogs).Count -eq 0) {
        $lines += "- No full stdout/stderr paths were recorded."
    } else {
        foreach ($path in @($summary.fullLogs)) {
            $lines += "- $path"
        }
    }

    $lines += @(
        "",
        "## Stage And Scenario Results",
        "",
        "| Stage / group | Result | Green | Yellow | Red | Command | Exit | Duration | Evidence |",
        "| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | --- |"
    )
    foreach ($group in @($summary.groups)) {
        $items = @($group.Group)
        $red = @($items | Where-Object { $_.result -eq "RED" }).Count
        $yellow = @($items | Where-Object { $_.result -eq "YELLOW" }).Count
        $green = @($items | Where-Object { $_.result -eq "GREEN" }).Count
        $result = if ($red -gt 0) { "RED" } elseif ($yellow -gt 0) { "YELLOW" } else { "GREEN" }
        $first = $items[0]
        $command = ([string]$first.command).Replace("|", "\|")
        $evidence = ([string]$first.evidence).Replace("|", "\|")
        $lines += "| $($group.Name) | $result | $green | $yellow | $red | $command | $($first.exitCode) | $($first.durationSeconds) | $evidence |"
    }

    $lines += @(
        "",
        "## Scenario Samples",
        ""
    )
    foreach ($group in @($summary.groups)) {
        $lines += "### $($group.Name)"
        foreach ($row in @($group.Group | Select-Object -First 8)) {
            $scenario = ([string]$row.scenario).Replace("`r", " ").Replace("`n", " ")
            $lines += "- $($row.result): $scenario"
        }
        if (@($group.Group).Count -gt 8) {
            $lines += "- ... $(@($group.Group).Count - 8) more assertion(s); see full logs above."
        }
        $lines += ""
    }

    $path = Join-Path $DocsPath "test-summary.md"
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Write-FleetRunEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$Ship = "",
        [string]$RunId = "",
        [string]$Status = "UNKNOWN",
        [string]$Phase = "",
        [string[]]$TasksAttempted = @(),
        [string[]]$TasksCompleted = @(),
        [string[]]$TasksQuarantined = @(),
        [hashtable]$Checks = @{},
        [object[]]$CheckRecords = @(),
        [string[]]$EvidencePaths = @(),
        [string]$DecisionHint = "PARK",
        [string]$Notes = ""
    )

    $repoPath = [System.IO.Path]::GetFullPath($Repo)
    $docsPath = Join-Path $repoPath "docs\codex"
    New-Item -ItemType Directory -Force -Path $docsPath | Out-Null

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = New-FleetRunId -Prefix "run"
    }
    if ([string]::IsNullOrWhiteSpace($Ship)) {
        $Ship = Split-Path -Leaf $repoPath
    }

    $repoState = Get-FleetRepoState -Repo $repoPath
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    $checkObjects = @()
    if (@($CheckRecords).Count -gt 0) {
        foreach ($record in @($CheckRecords)) {
            if ($record -and !$record.PSObject.Properties["name"] -and $record.PSObject.Properties["value"]) {
                foreach ($nestedRecord in @($record.value)) {
                    if ($nestedRecord -and $nestedRecord.PSObject.Properties["value"] -and !$nestedRecord.PSObject.Properties["name"]) {
                        $checkObjects += @($nestedRecord.value)
                    } else {
                        $checkObjects += $nestedRecord
                    }
                }
            } else {
                $checkObjects += $record
            }
        }
    } else {
        foreach ($key in $Checks.Keys) {
            $checkObjects += [pscustomobject]@{
                name = [string]$key
                status = [string]$Checks[$key]
                command = ""
                exitCode = $null
                startedAt = ""
                endedAt = ""
                durationSeconds = $null
                evidence = @()
            }
        }
    }
    $testSummaryPath = Write-FleetTestSummary -RepoPath $repoPath -DocsPath $docsPath -Checks $checkObjects
    if (![string]::IsNullOrWhiteSpace($testSummaryPath)) {
        $testSummaryRelative = "docs/codex/test-summary.md"
        if (@($EvidencePaths) -notcontains $testSummaryRelative) {
            $EvidencePaths += $testSummaryRelative
        }
    }

    $evidenceObjects = @(
        foreach ($path in $EvidencePaths) {
            [pscustomobject]@{ path = [string]$path; exists = (Test-Path -LiteralPath (Join-Path $repoPath $path)) }
        }
    )

    $result = [pscustomobject]@{
        schemaVersion = 1
        runId = $RunId
        generatedAt = $startedAt
        ship = $Ship
        phase = $Phase
        status = $Status
        decision_hint = $DecisionHint
        repo = $repoState
        tasks = [pscustomobject]@{
            attempted = @($TasksAttempted)
            completed = @($TasksCompleted)
            quarantined = @($TasksQuarantined)
        }
        checks = @($checkObjects)
        evidence = @($evidenceObjects)
        notes = $Notes
    }

    $runResultPath = Join-Path $docsPath "RUN_RESULT.json"
    $result | ConvertTo-Json -Depth 12 | Set-Content -Path $runResultPath -Encoding UTF8

    $summaryLines = @(
        "# Run Summary",
        "",
        "- Run ID: $RunId",
        "- Ship: $Ship",
        "- Status: $Status",
        "- Phase: $Phase",
        "- Decision hint: $DecisionHint",
        "- Repo state: $($repoState.state)",
        "- Tasks attempted: $(@($TasksAttempted).Count)",
        "- Tasks completed: $(@($TasksCompleted).Count)",
        "- Tasks quarantined: $(@($TasksQuarantined).Count)",
        "",
        "## Checks",
        ""
    )
    if (@($checkObjects).Count -eq 0) {
        $summaryLines += "- No checks recorded."
    } else {
        foreach ($check in @($checkObjects)) {
            $command = if ($check.command) { " command: $($check.command)" } else { "" }
            $exitCode = if ($null -ne $check.exitCode) { " exit: $($check.exitCode)" } else { "" }
            $summaryLines += "- $($check.name): $($check.status)$exitCode$command"
        }
    }
    $summaryLines += @(
        "",
        "## Notes",
        "",
        $(if ([string]::IsNullOrWhiteSpace($Notes)) { "No notes recorded." } else { $Notes }),
        "",
        "## Test Summary",
        "",
        $(if ([string]::IsNullOrWhiteSpace($testSummaryPath)) { "No summarized test report generated for this run." } else { "Summarized test report: docs/codex/test-summary.md" })
    )
    $summaryPath = Join-Path $docsPath "RUN_SUMMARY.md"
    $summaryLines | Set-Content -Path $summaryPath -Encoding UTF8

    $indexLines = @(
        "# Evidence Index",
        "",
        "- Run result: docs/codex/RUN_RESULT.json",
        "- Run summary: docs/codex/RUN_SUMMARY.md",
        "",
        "## Referenced Evidence"
    )
    if ($evidenceObjects.Count -eq 0) {
        $indexLines += "- No additional evidence paths recorded."
    } else {
        foreach ($item in $evidenceObjects) {
            $indexLines += "- $($item.path) (exists: $($item.exists))"
        }
    }
    $indexLines += @(
        "",
        "## Checks"
    )
    if (@($checkObjects).Count -eq 0) {
        $indexLines += "- No checks recorded."
    } else {
        foreach ($check in @($checkObjects)) {
            $indexLines += "- $($check.name): $($check.status)"
            foreach ($path in @($check.evidence)) {
                if (![string]::IsNullOrWhiteSpace([string]$path)) {
                    $indexLines += "  - evidence: $path"
                }
            }
        }
    }
    $indexPath = Join-Path $docsPath "EVIDENCE_INDEX.md"
    $indexLines | Set-Content -Path $indexPath -Encoding UTF8

    return [pscustomobject]@{
        runResult = $runResultPath
        runSummary = $summaryPath
        evidenceIndex = $indexPath
        result = $result
    }
}

function Test-FleetTaskContractLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    $required = @("User pain:", "Skill:", "Target:", "Change:", "Guardrails:", "Acceptance:", "Proof:", "Stop if:", "Check:")
    $missing = @($required | Where-Object { $Line -notmatch [regex]::Escape($_) })
    $metadataOk = ($Line -match "\[.*class:[^\]\s]+.*risk:[^\]\s]+.*mode:[^\]\s]+.*scope:[^\]]+.*\]")
    return [pscustomobject]@{
        valid = ($missing.Count -eq 0 -and $metadataOk)
        missing = $missing
        metadataOk = $metadataOk
    }
}
