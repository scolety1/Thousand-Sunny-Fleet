function Get-FleetProjectManagementAutonomyProfileNames {
    return @(
        "review_only",
        "bounded_implementation",
        "batch_implementation",
        "away_safe"
    )
}

function ConvertTo-FleetPmStringArray {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        $text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { return @() }
        return @($text)
    }

    $items = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Value)) {
        if ($null -eq $item) { continue }
        $text = ([string]$item).Trim()
        if (![string]::IsNullOrWhiteSpace($text)) {
            $items.Add($text) | Out-Null
        }
    }
    return @($items)
}

function ConvertTo-FleetPmObjectArray {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object { $_ })
}

function Get-FleetPmPropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    if ($null -eq $property.Value) { return $Default }
    return $property.Value
}

function Test-FleetPmTruthy {
    param([object]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return [bool]$Value }
    $text = ([string]$Value).Trim()
    return ($text -match "^(?i:true|yes|1|approved|exact-approved|explicit)$")
}

function Test-FleetPmSafeProjectName {
    param([string]$ProjectName)

    if ([string]::IsNullOrWhiteSpace($ProjectName)) { return $false }
    $name = $ProjectName.Trim()
    if ($name -match "^(?i:all)$|[*?]|[\\/:\r\n\t]|\.\.|^\s|\s$") { return $false }
    return ($name -match "^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$")
}

function Test-FleetPmForbiddenActionText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return ($Text -match "(?i)(git\s+(add|commit|merge|push|reset|checkout|clean|revert)|npm\s+install|pnpm\s+install|yarn\s+install|deploy|migrations?|migrate\b|secrets?|auth\b|payments?|token|credential|private[-_]?key|remote\s+access|ssh\b|rdp\b|tailscale|run-fleet\.ps1|launch-proof-run|proof\s+run|launch-|start-overnight|overnight\s+runner|fleet-supervisor|fleet-remote-control|all-fleet)")
}

function Test-FleetPmSafeRelativePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $value = $Path.Trim()
    if ([System.IO.Path]::IsPathRooted($value)) { return $false }
    if ($value -match "(?i)(^|[\\/])\.\.([\\/]|$)|(^|[\\/])(\.git|\.env|node_modules|dist|build|secrets?|auth|payments?|deploy|migrations?)([\\/]|$)|secret|token|credential|private[-_]?key|[\x00-\x1F\x7F]") { return $false }
    if ($value -match "^\s|\s$") { return $false }
    return $true
}

function Get-FleetProjectManagementAutonomyProfile {
    param([string]$Profile)

    $name = ([string]$Profile).Trim().ToLowerInvariant()
    switch ($name) {
        "review_only" {
            return [pscustomobject]@{
                name = "review_only"
                canPatch = $false
                canAdvanceWithinBatch = $false
                maxBatchTasks = 1
                requiresValidationPerTask = $true
                asksOnlyForBlockers = $true
                questionPolicy = "report_questions"
                reportFormat = "review_report"
                description = "Read, inspect, summarize, and classify without patching."
            }
        }
        "bounded_implementation" {
            return [pscustomobject]@{
                name = "bounded_implementation"
                canPatch = $true
                canAdvanceWithinBatch = $false
                maxBatchTasks = 1
                requiresValidationPerTask = $true
                asksOnlyForBlockers = $true
                questionPolicy = "ask_true_blockers"
                reportFormat = "bounded_task_report"
                description = "Patch exactly one selected eligible task and stop after validation."
            }
        }
        "batch_implementation" {
            return [pscustomobject]@{
                name = "batch_implementation"
                canPatch = $true
                canAdvanceWithinBatch = $true
                maxBatchTasks = 5
                requiresValidationPerTask = $true
                asksOnlyForBlockers = $true
                questionPolicy = "batch_nonurgent_questions"
                reportFormat = "batch_queue_report"
                description = "Work through a bounded queue slice until the batch cap, assignment done, or a true blocker."
            }
        }
        "away_safe" {
            return [pscustomobject]@{
                name = "away_safe"
                canPatch = $true
                canAdvanceWithinBatch = $true
                maxBatchTasks = 3
                requiresValidationPerTask = $true
                asksOnlyForBlockers = $true
                questionPolicy = "collect_tim_question_queue"
                reportFormat = "away_mode_report"
                description = "Run a preapproved, low-risk assignment slice and collect nonurgent questions instead of pausing."
            }
        }
        default {
            return [pscustomobject]@{
                name = $name
                valid = $false
                canPatch = $false
                canAdvanceWithinBatch = $false
                maxBatchTasks = 0
                requiresValidationPerTask = $true
                asksOnlyForBlockers = $true
                questionPolicy = "block_unknown_profile"
                reportFormat = "blocked_report"
                description = "Unknown autonomy profile."
            }
        }
    }
}

function Resolve-FleetProjectBrainInboxPath {
    param(
        [string]$ProjectName,
        [string]$InboxRoot = "C:\TSF_INBOX"
    )

    $safeName = Test-FleetPmSafeProjectName -ProjectName $ProjectName
    $result = [pscustomobject]@{
        valid = $false
        projectName = ([string]$ProjectName).Trim()
        inboxRoot = ""
        projectInboxPath = ""
        exists = $false
        intakePath = ""
        manifestPath = ""
        status = "BLOCKED"
        reason = ""
        evidenceOnly = $true
        canApproveExecution = $false
    }

    if (!$safeName) {
        $result.reason = "Project name is missing or unsafe for C:\TSF_INBOX\<project_name>."
        return $result
    }

    $rootFull = [System.IO.Path]::GetFullPath($InboxRoot)
    if (!$rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $projectFull = [System.IO.Path]::GetFullPath((Join-Path $rootFull $ProjectName))
    if (!$projectFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.reason = "Resolved project inbox escapes the configured inbox root."
        $result.inboxRoot = $rootFull
        $result.projectInboxPath = $projectFull
        return $result
    }

    $result.inboxRoot = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $result.projectInboxPath = $projectFull
    $result.exists = Test-Path -LiteralPath $projectFull -PathType Container
    if (!$result.exists) {
        $result.status = "YELLOW"
        $result.reason = "Project inbox folder is not present; TSF can still use explicit packet metadata but cannot read local intake files."
        return $result
    }

    $intake = Join-Path $projectFull "INTAKE.md"
    $manifestMd = Join-Path $projectFull "MANIFEST.md"
    $manifestJson = Join-Path $projectFull "manifest.json"
    if (Test-Path -LiteralPath $intake -PathType Leaf) { $result.intakePath = $intake }
    if (Test-Path -LiteralPath $manifestMd -PathType Leaf) { $result.manifestPath = $manifestMd }
    elseif (Test-Path -LiteralPath $manifestJson -PathType Leaf) { $result.manifestPath = $manifestJson }

    if ([string]::IsNullOrWhiteSpace($result.intakePath) -or [string]::IsNullOrWhiteSpace($result.manifestPath)) {
        $result.status = "YELLOW"
        $result.reason = "Project inbox exists but should include INTAKE.md and MANIFEST.md or manifest.json before away-safe work."
        $result.valid = $true
        return $result
    }

    $result.status = "GREEN"
    $result.reason = "Project inbox intake and manifest are present as evidence-only context."
    $result.valid = $true
    return $result
}

function Resolve-FleetProjectTaskTerminalState {
    param([object]$Task)

    $status = ([string](Get-FleetPmPropertyValue -Object $Task -Name "status" -Default "pending")).Trim().ToLowerInvariant()
    switch -Regex ($status) {
        "^(done|pass|passed|green|item_finished_green|batch_finished_green|complete|completed)$" { return "GREEN" }
        "^(blocked|block|needs_human|human_required|requires_human|blocked_terminal|blocked_missing_context)$" { return "BLOCKED" }
        "^(red|fail|failed|failed_validation|scope_violation|forbidden|unsafe)$" { return "RED" }
        default { return "YELLOW" }
    }
}

function Resolve-FleetProjectBatchQueueStatus {
    param([object[]]$Tasks)

    $items = @(ConvertTo-FleetPmObjectArray -Value $Tasks)
    $counts = [ordered]@{
        GREEN = 0
        YELLOW = 0
        RED = 0
        BLOCKED = 0
    }
    $taskStates = @()

    foreach ($task in $items) {
        $state = Resolve-FleetProjectTaskTerminalState -Task $task
        $counts[$state] = [int]$counts[$state] + 1
        $taskStates += [pscustomobject]@{
            id = [string](Get-FleetPmPropertyValue -Object $task -Name "id" -Default "")
            title = [string](Get-FleetPmPropertyValue -Object $task -Name "title" -Default "")
            status = [string](Get-FleetPmPropertyValue -Object $task -Name "status" -Default "pending")
            terminalState = $state
        }
    }

    $terminalState = "BLOCKED"
    $reason = "Queue has no tasks."
    if ($items.Count -gt 0) {
        if ($counts["BLOCKED"] -gt 0) {
            $terminalState = "BLOCKED"
            $reason = "At least one queue item is blocked and needs a human, repacketization, or a known-fix route."
        } elseif ($counts["RED"] -gt 0) {
            $terminalState = "RED"
            $reason = "At least one queue item failed validation or crossed a safety boundary."
        } elseif ($counts["YELLOW"] -gt 0) {
            $terminalState = "YELLOW"
            $reason = "Queue still has pending, in-progress, deferred, or not-yet-validated work."
        } else {
            $terminalState = "GREEN"
            $reason = "All queue items are complete with GREEN evidence."
        }
    }

    return [pscustomobject]@{
        terminalState = $terminalState
        reason = $reason
        total = $items.Count
        counts = [pscustomobject]$counts
        tasks = @($taskStates)
    }
}

function Test-FleetProjectManagementPacket {
    param(
        [Parameter(Mandatory = $true)][object]$Packet,
        [string]$InboxRoot = "C:\TSF_INBOX"
    )

    $blockers = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $projectObject = Get-FleetPmPropertyValue -Object $Packet -Name "project" -Default $null
    $selectedObject = Get-FleetPmPropertyValue -Object $Packet -Name "selected" -Default $null
    $artifactsObject = Get-FleetPmPropertyValue -Object $Packet -Name "artifacts" -Default $null
    $approvalsObject = Get-FleetPmPropertyValue -Object $Packet -Name "approvals" -Default $null

    $projectName = [string](Get-FleetPmPropertyValue -Object $projectObject -Name "name" -Default (Get-FleetPmPropertyValue -Object $Packet -Name "projectName" -Default ""))
    $section = [string](Get-FleetPmPropertyValue -Object $projectObject -Name "section" -Default (Get-FleetPmPropertyValue -Object $Packet -Name "projectSection" -Default ""))
    $track = [string](Get-FleetPmPropertyValue -Object $selectedObject -Name "track" -Default (Get-FleetPmPropertyValue -Object $Packet -Name "selectedTrack" -Default ""))
    $selectedProject = [string](Get-FleetPmPropertyValue -Object $selectedObject -Name "project" -Default "")
    $profileName = [string](Get-FleetPmPropertyValue -Object $Packet -Name "autonomyProfile" -Default "")
    $profile = Get-FleetProjectManagementAutonomyProfile -Profile $profileName
    $queue = @(ConvertTo-FleetPmObjectArray -Value (Get-FleetPmPropertyValue -Object $Packet -Name "queue" -Default (Get-FleetPmPropertyValue -Object $Packet -Name "tasks" -Default @())))
    $researchFiles = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $artifactsObject -Name "researchFiles" -Default @()))
    $rootFiles = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $artifactsObject -Name "rootFiles" -Default @()))
    $requestedActions = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $Packet -Name "requestedActions" -Default @()))
    $inboxProjectName = [string](Get-FleetPmPropertyValue -Object $artifactsObject -Name "inboxProjectName" -Default $projectName)

    if ((Get-FleetProjectManagementAutonomyProfileNames) -notcontains $profile.name) {
        $blockers.Add("Unknown autonomy profile: $profileName") | Out-Null
    }
    if (!(Test-FleetPmSafeProjectName -ProjectName $projectName)) {
        $blockers.Add("Project name must be a single safe C:\TSF_INBOX\<project_name> folder name.") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($selectedProject) -or $selectedProject -ne $projectName) {
        $blockers.Add("Exactly one selected project must match the project brain record.") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($track)) {
        $blockers.Add("Exactly one selected track is required.") | Out-Null
    }

    $archived = Test-FleetPmTruthy -Value (Get-FleetPmPropertyValue -Object $projectObject -Name "archived" -Default $false)
    $reactivation = Get-FleetPmPropertyValue -Object $approvalsObject -Name "archivedReactivation" -Default $null
    $reactivationApproved = Test-FleetPmTruthy -Value (Get-FleetPmPropertyValue -Object $reactivation -Name "exactApproved" -Default $false)
    if ($archived -and !$reactivationApproved) {
        $blockers.Add("Archived project mutation is blocked unless an exact reactivation record is present.") | Out-Null
    }

    $eligibleSections = @("Active / Development", "Review / Release Candidate")
    if ($eligibleSections -notcontains $section) {
        $blockers.Add("Project section is not autonomous-eligible: $section") | Out-Null
    }

    $productMutationRequested = Test-FleetPmTruthy -Value (Get-FleetPmPropertyValue -Object $projectObject -Name "productRepoMutationRequested" -Default (Get-FleetPmPropertyValue -Object $Packet -Name "productRepoMutationRequested" -Default $false))
    $productMutation = Get-FleetPmPropertyValue -Object $approvalsObject -Name "productRepoMutation" -Default $null
    $productMutationApproved = Test-FleetPmTruthy -Value (Get-FleetPmPropertyValue -Object $productMutation -Name "exactApproved" -Default $false)
    if ($productMutationRequested) {
        if (!$productMutationApproved) {
            $blockers.Add("Product repo mutation is requested but lacks exact selected-project approval.") | Out-Null
        }
        if ($profile.name -eq "review_only") {
            $blockers.Add("review_only profile cannot mutate product repos.") | Out-Null
        }
    }

    if ($queue.Count -eq 0) {
        $blockers.Add("Project-management packet requires a queue of tasks.") | Out-Null
    }

    $taskIndex = 0
    foreach ($task in $queue) {
        $taskIndex += 1
        $taskId = [string](Get-FleetPmPropertyValue -Object $task -Name "id" -Default "task-$taskIndex")
        $allowedFiles = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $task -Name "allowedFiles" -Default @()))
        $validationCommands = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $task -Name "validationCommands" -Default @()))
        $stopIf = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $task -Name "stopIf" -Default @()))
        $readFirst = @(ConvertTo-FleetPmStringArray -Value (Get-FleetPmPropertyValue -Object $task -Name "readFirst" -Default @()))

        if ($allowedFiles.Count -eq 0 -and $profile.name -ne "review_only") {
            $blockers.Add("$taskId is missing allowedFiles.") | Out-Null
        }
        if ($validationCommands.Count -eq 0) {
            $blockers.Add("$taskId is missing validationCommands.") | Out-Null
        }
        if ($stopIf.Count -eq 0) {
            $blockers.Add("$taskId is missing stopIf conditions.") | Out-Null
        }

        foreach ($path in @($allowedFiles + $readFirst)) {
            if (!(Test-FleetPmSafeRelativePath -Path $path)) {
                $blockers.Add("$taskId contains unsafe relative path: $path") | Out-Null
            }
        }
        foreach ($command in $validationCommands) {
            if (Test-FleetPmForbiddenActionText -Text $command) {
                $blockers.Add("$taskId validation command includes forbidden action text: $command") | Out-Null
            }
        }
        foreach ($stop in $stopIf) {
            if (Test-FleetPmForbiddenActionText -Text $stop) {
                $warnings.Add("$taskId stop condition mentions a forbidden boundary and must remain a stop, not an action: $stop") | Out-Null
            }
        }
    }

    foreach ($path in @($researchFiles + $rootFiles)) {
        if (!(Test-FleetPmSafeRelativePath -Path $path)) {
            $blockers.Add("Research/root file must be a safe relative path, not broad or absolute: $path") | Out-Null
        }
    }

    foreach ($action in $requestedActions) {
        if (Test-FleetPmForbiddenActionText -Text $action) {
            $blockers.Add("Requested action is forbidden without separate exact approval: $action") | Out-Null
        }
    }

    $inbox = Resolve-FleetProjectBrainInboxPath -ProjectName $inboxProjectName -InboxRoot $InboxRoot
    if ($inbox.status -eq "BLOCKED") {
        $blockers.Add("Project inbox is blocked: $($inbox.reason)") | Out-Null
    } elseif ($inbox.status -eq "YELLOW") {
        $warnings.Add("Project inbox warning: $($inbox.reason)") | Out-Null
    }

    return [pscustomobject]@{
        valid = ($blockers.Count -eq 0)
        blockers = @($blockers)
        warnings = @($warnings)
        profile = $profile
        projectName = $projectName
        selectedProject = $selectedProject
        selectedTrack = $track
        section = $section
        archived = $archived
        productRepoMutationRequested = $productMutationRequested
        inbox = $inbox
        researchFiles = @($researchFiles)
        rootFiles = @($rootFiles)
        queue = @($queue)
    }
}

function Select-FleetProjectBatchQueueTasks {
    param(
        [object[]]$Tasks,
        [object]$Profile
    )

    $readyStates = @("ready", "todo", "pending", "not_started", "in_progress", "")
    $selected = [System.Collections.Generic.List[object]]::new()
    foreach ($task in @(ConvertTo-FleetPmObjectArray -Value $Tasks)) {
        $status = ([string](Get-FleetPmPropertyValue -Object $task -Name "status" -Default "")).Trim().ToLowerInvariant()
        if ($readyStates -contains $status) {
            $selected.Add($task) | Out-Null
        }
        if ($selected.Count -ge [int]$Profile.maxBatchTasks) { break }
    }
    return @($selected)
}

function New-FleetProjectManagementGuide {
    param(
        [Parameter(Mandatory = $true)][object]$Packet,
        [string]$InboxRoot = "C:\TSF_INBOX"
    )

    $validation = Test-FleetProjectManagementPacket -Packet $Packet -InboxRoot $InboxRoot
    $queueStatus = Resolve-FleetProjectBatchQueueStatus -Tasks $validation.queue
    $selectedTasks = @()
    $terminalState = $queueStatus.terminalState
    $shouldPause = $false
    $nextAction = ""

    if (!$validation.valid) {
        $terminalState = "BLOCKED"
        $shouldPause = $true
        $nextAction = "Stop for repacketization or exact approval before editing."
    } elseif ($queueStatus.terminalState -in @("BLOCKED", "RED")) {
        $terminalState = $queueStatus.terminalState
        $shouldPause = $true
        $nextAction = "Stop and report the queue blocker or failed validation."
    } elseif ($queueStatus.terminalState -eq "GREEN") {
        $terminalState = "GREEN"
        $shouldPause = $false
        $nextAction = "Report GREEN completion; do not start unrelated work."
    } else {
        $selectedTasks = @(Select-FleetProjectBatchQueueTasks -Tasks $validation.queue -Profile $validation.profile)
        if ($selectedTasks.Count -eq 0) {
            $terminalState = "YELLOW"
            $shouldPause = $true
            $nextAction = "No eligible pending queue item was found; repacketize the queue."
        } else {
            $terminalState = "YELLOW"
            $shouldPause = $false
            $nextAction = "Work through the selected bounded queue slice; pause only for true blockers, failed validation, or safety boundaries."
        }
    }

    $standardStopConditions = @(
        "missing or ambiguous selected project, track, task, allowed files, validation, or stopIf",
        "archived, paused, finished, blocked, idea-only, out-of-focus, or unreactivated project/track",
        "product repo mutation without exact selected-project approval",
        "push, deploy, package install, migration, secret/auth/payment/deploy, remote access, all-fleet, proof run, or overnight runner request without exact approval",
        "validation failure without a known-fix route inside allowed files",
        "same uncertainty, failure fingerprint, missing context, or scope question repeats twice",
        "scope expansion would be required to meet the definition of done"
    )

    return [pscustomobject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        projectName = $validation.projectName
        selectedProject = $validation.selectedProject
        selectedTrack = $validation.selectedTrack
        autonomyProfile = $validation.profile.name
        profile = $validation.profile
        terminalState = $terminalState
        shouldPause = $shouldPause
        pauseReasons = if ($shouldPause) { @($validation.blockers + @($queueStatus.reason)) } else { @() }
        warnings = @($validation.warnings)
        nextAction = $nextAction
        batchQueueStatus = $queueStatus
        selectedTaskIds = @($selectedTasks | ForEach-Object { [string](Get-FleetPmPropertyValue -Object $_ -Name "id" -Default "") })
        selectedTasks = @($selectedTasks)
        projectBrain = [pscustomobject]@{
            inbox = $validation.inbox
            researchFiles = @($validation.researchFiles)
            rootFiles = @($validation.rootFiles)
            evidenceOnly = $true
            canApproveExecution = $false
        }
        stopConditions = $standardStopConditions
        guardrailsPreserved = [pscustomobject]@{
            noProductRepoMutationUnlessSelectedAndApproved = $true
            noArchivedProjectMutationUnlessReactivated = $true
            noPushDeployInstallMigrationSecretsOrRemoteAccessUnlessExplicitlyApproved = $true
            noProofRunsWithoutExplicitApproval = $true
            noAllFleetOrUnboundedOvernight = $true
            evidenceIsNotAuthority = $true
        }
        continuePolicy = "Continue across selected eligible queue items only while validation stays GREEN and no true blocker or forbidden boundary appears."
        awayModeReportFormat = @(
            "Captain Summary",
            "Project / Track / Assignment",
            "Autonomy Profile And Batch Limits",
            "Batch Queue Status",
            "Completed / Blocked / Deferred / Skipped",
            "Validation Evidence",
            "Stop Conditions Encountered",
            "Tim Question Queue",
            "Boundaries Preserved",
            "Next Safe Action"
        )
    }
}

function New-FleetProjectManagementReportLines {
    param([Parameter(Mandatory = $true)][object]$Guide)

    $isAway = ([string]$Guide.autonomyProfile -eq "away_safe")
    $title = if ($isAway) { "# TSF Away Mode Report" } else { "# TSF Project Management Control Report" }
    $selectedTaskLine = if (@($Guide.selectedTaskIds).Count -gt 0) { @($Guide.selectedTaskIds) -join ", " } else { "None" }
    $pauseLine = if ([bool]$Guide.shouldPause) { "true" } else { "false" }

    $lines = @(
        $title,
        "",
        "## Captain Summary",
        "",
        "- Terminal state: $($Guide.terminalState)",
        "- Autonomy profile: $($Guide.autonomyProfile)",
        "- Project: $($Guide.projectName)",
        "- Track: $($Guide.selectedTrack)",
        "- Selected tasks: $selectedTaskLine",
        "- Should pause: $pauseLine",
        "- Next safe action: $($Guide.nextAction)",
        "",
        "## Project / Track / Assignment",
        "",
        "- Selected project: $($Guide.selectedProject)",
        "- Selected track: $($Guide.selectedTrack)",
        "- Project brain inbox: $($Guide.projectBrain.inbox.projectInboxPath)",
        "- Inbox status: $($Guide.projectBrain.inbox.status)",
        "- Research files: $(@($Guide.projectBrain.researchFiles) -join ', ')",
        "- Root files: $(@($Guide.projectBrain.rootFiles) -join ', ')",
        "",
        "## Autonomy Profile And Batch Limits",
        "",
        "- Can patch: $($Guide.profile.canPatch)",
        "- Can advance within batch: $($Guide.profile.canAdvanceWithinBatch)",
        "- Max batch tasks: $($Guide.profile.maxBatchTasks)",
        "- Question policy: $($Guide.profile.questionPolicy)",
        "",
        "## Batch Queue Status",
        "",
        "- Queue terminal state: $($Guide.batchQueueStatus.terminalState)",
        "- Queue reason: $($Guide.batchQueueStatus.reason)",
        "- Total tasks: $($Guide.batchQueueStatus.total)",
        "- GREEN: $($Guide.batchQueueStatus.counts.GREEN)",
        "- YELLOW: $($Guide.batchQueueStatus.counts.YELLOW)",
        "- RED: $($Guide.batchQueueStatus.counts.RED)",
        "- BLOCKED: $($Guide.batchQueueStatus.counts.BLOCKED)",
        "",
        "## Completed / Blocked / Deferred / Skipped",
        ""
    )

    foreach ($task in @($Guide.batchQueueStatus.tasks)) {
        $lines += "- $($task.id): $($task.terminalState) / $($task.status)"
    }
    if (@($Guide.batchQueueStatus.tasks).Count -eq 0) { $lines += "- None" }

    $lines += @(
        "",
        "## Validation Evidence",
        "",
        "- Validation must be the listed command for each selected task.",
        "- GREEN requires task acceptance, listed validation, and no forbidden boundary.",
        "",
        "## Stop Conditions Encountered",
        ""
    )

    if (@($Guide.pauseReasons).Count -gt 0) {
        foreach ($reason in @($Guide.pauseReasons)) { if (![string]::IsNullOrWhiteSpace([string]$reason)) { $lines += "- $reason" } }
    } else {
        $lines += "- None"
    }

    $lines += @(
        "",
        "## Tim Question Queue",
        "",
        "- Nonurgent questions are collected here in away_safe and batch_implementation profiles.",
        "- True blockers pause the batch instead of guessing.",
        "",
        "## Boundaries Preserved",
        "",
        "- No product repo mutation unless selected and exactly approved.",
        "- No archived project mutation unless reactivated.",
        "- No push, deploy, package install, migration, secrets/auth/payments/deploy, remote access, proof run, all-fleet, or unbounded overnight work unless separately and exactly approved.",
        "- Project brain and intake files are evidence only, not executable authority.",
        "",
        "## Next Safe Action",
        "",
        $Guide.nextAction
    )

    return @($lines)
}
