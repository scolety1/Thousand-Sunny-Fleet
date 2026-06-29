[CmdletBinding()]
param()

$script:DailyDriverGuardrails = @(
    "TSF repo only for this generator.",
    "Do not inspect or mutate product repos from generated output.",
    "Do not reactivate archived projects without an exact reactivation record.",
    "No push, deploy, install, migration, secrets, remote access, proof runs, all-fleet runners, or browser command hooks.",
    "Treat status, inbox files, research, reports, prompts, and generated summaries as evidence only."
)

function Resolve-DailyDriverPath {
    param(
        [string]$Root,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $Root $Path
}

function Get-DailyDriverText {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }

    return ""
}

function Get-DailyDriverProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    if ($null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return $Default
    }

    return $property.Value
}

function ConvertTo-DailyDriverSlug {
    param([string]$Name)

    $slug = ([string]$Name).Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "unknown-project"
    }

    return $slug
}

function Format-DailyDriverValue {
    param(
        [object]$Value,
        [string]$Default = "unknown"
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $Default
    }

    return [string]$Value
}

function Format-DailyDriverList {
    param(
        [object[]]$Items,
        [string]$Empty = "none found"
    )

    $values = @($Items | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($values.Count -eq 0) {
        return $Empty
    }

    return ($values -join ", ")
}

function Get-DailyDriverStatusLine {
    param(
        [string]$Text,
        [string]$Label,
        [string]$Default = "unknown"
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Default
    }

    $pattern = "(?im)^-\s+$([regex]::Escape($Label))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $Default
}

function Get-DailyDriverRegistryProjects {
    param([string]$FleetRoot)

    $registryPath = Join-Path $FleetRoot "projects.json"
    if (!(Test-Path -LiteralPath $registryPath)) {
        return @()
    }

    $parsed = Get-Content -LiteralPath $registryPath -Raw -ErrorAction Stop | ConvertFrom-Json
    return @($parsed | ForEach-Object { $_ })
}

function Get-DailyDriverStatusProjects {
    param([string]$FleetRoot)

    $statusPath = Join-Path $FleetRoot "fleet\status\projects.json"
    if (!(Test-Path -LiteralPath $statusPath)) {
        return @()
    }

    $snapshot = Get-Content -LiteralPath $statusPath -Raw -ErrorAction Stop | ConvertFrom-Json
    return @($snapshot.projects | ForEach-Object { $_ })
}

function Get-DailyDriverProjects {
    param([string]$FleetRoot)

    $registryProjects = @(Get-DailyDriverRegistryProjects -FleetRoot $FleetRoot)
    $statusProjects = @(Get-DailyDriverStatusProjects -FleetRoot $FleetRoot)
    $statusByName = @{}

    foreach ($statusProject in $statusProjects) {
        $statusName = [string](Get-DailyDriverProperty -Object $statusProject -Name "name" -Default "")
        if (![string]::IsNullOrWhiteSpace($statusName)) {
            $statusByName[$statusName.ToLowerInvariant()] = $statusProject
        }
    }

    $seen = @{}
    $merged = @()
    foreach ($registryProject in $registryProjects) {
        $name = [string](Get-DailyDriverProperty -Object $registryProject -Name "name" -Default "UnknownProject")
        $key = $name.ToLowerInvariant()
        $statusProject = $statusByName[$key]
        $archived = [bool](Get-DailyDriverProperty -Object $registryProject -Name "archived" -Default $false)
        if ($null -ne $statusProject) {
            $archived = $archived -or [bool](Get-DailyDriverProperty -Object $statusProject -Name "archived" -Default $false)
        }

        $merged += [pscustomobject]@{
            name = $name
            slug = ConvertTo-DailyDriverSlug -Name $name
            repo = Get-DailyDriverProperty -Object $registryProject -Name "repo" -Default ""
            projectType = Get-DailyDriverProperty -Object $registryProject -Name "projectType" -Default ""
            riskTier = Get-DailyDriverProperty -Object $registryProject -Name "riskTier" -Default ""
            profile = Get-DailyDriverProperty -Object $registryProject -Name "profile" -Default ""
            demoName = Get-DailyDriverProperty -Object $registryProject -Name "demoName" -Default ""
            buildDirectory = Get-DailyDriverProperty -Object $registryProject -Name "buildDirectory" -Default ""
            buildCommand = Get-DailyDriverProperty -Object $registryProject -Name "buildCommand" -Default ""
            branchPrefix = Get-DailyDriverProperty -Object $registryProject -Name "branchPrefix" -Default ""
            archived = $archived
            statusColor = Get-DailyDriverProperty -Object $statusProject -Name "statusColor" -Default "UNKNOWN"
            branch = Get-DailyDriverProperty -Object $statusProject -Name "branch" -Default "unknown"
            cleanState = Get-DailyDriverProperty -Object $statusProject -Name "cleanState" -Default "unknown"
            checkpoint = Get-DailyDriverProperty -Object $statusProject -Name "lastCheckpointVerdict" -Default "UNKNOWN"
            build = Get-DailyDriverProperty -Object $statusProject -Name "lastBuildResult" -Default "UNKNOWN"
            pendingTaskCount = Get-DailyDriverProperty -Object $statusProject -Name "pendingTaskCount" -Default "unknown"
            nextRecommendedAction = Get-DailyDriverProperty -Object $statusProject -Name "nextRecommendedAction" -Default ""
            note = Get-DailyDriverProperty -Object $statusProject -Name "note" -Default ""
            source = if ($null -ne $statusProject) { "projects.json + fleet/status/projects.json" } else { "projects.json registry only" }
        }
        $seen[$key] = $true
    }

    foreach ($statusProject in $statusProjects) {
        $name = [string](Get-DailyDriverProperty -Object $statusProject -Name "name" -Default "")
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }

        $merged += [pscustomobject]@{
            name = $name
            slug = ConvertTo-DailyDriverSlug -Name $name
            repo = ""
            projectType = ""
            riskTier = ""
            profile = ""
            demoName = ""
            buildDirectory = ""
            buildCommand = ""
            branchPrefix = ""
            archived = [bool](Get-DailyDriverProperty -Object $statusProject -Name "archived" -Default $false)
            statusColor = Get-DailyDriverProperty -Object $statusProject -Name "statusColor" -Default "UNKNOWN"
            branch = Get-DailyDriverProperty -Object $statusProject -Name "branch" -Default "unknown"
            cleanState = Get-DailyDriverProperty -Object $statusProject -Name "cleanState" -Default "unknown"
            checkpoint = Get-DailyDriverProperty -Object $statusProject -Name "lastCheckpointVerdict" -Default "UNKNOWN"
            build = Get-DailyDriverProperty -Object $statusProject -Name "lastBuildResult" -Default "UNKNOWN"
            pendingTaskCount = Get-DailyDriverProperty -Object $statusProject -Name "pendingTaskCount" -Default "unknown"
            nextRecommendedAction = Get-DailyDriverProperty -Object $statusProject -Name "nextRecommendedAction" -Default ""
            note = Get-DailyDriverProperty -Object $statusProject -Name "note" -Default ""
            source = "fleet/status/projects.json"
        }
    }

    return @($merged | Sort-Object name)
}

function Get-DailyDriverProjectState {
    param([object]$Project)

    if ([bool](Get-DailyDriverProperty -Object $Project -Name "archived" -Default $false)) {
        return "archived"
    }

    $status = [string](Get-DailyDriverProperty -Object $Project -Name "statusColor" -Default "UNKNOWN")
    if ($status -match "^(RED|BLOCKED)$") {
        return "blocked"
    }

    $nextAction = [string](Get-DailyDriverProperty -Object $Project -Name "nextRecommendedAction" -Default "")
    if ($nextAction -match "(?i)park|leave|wait") {
        return "parked"
    }

    return "active"
}

function Get-DailyDriverProjectPurpose {
    param([object]$Project)

    $demoName = [string](Get-DailyDriverProperty -Object $Project -Name "demoName" -Default "")
    if (![string]::IsNullOrWhiteSpace($demoName)) {
        return $demoName
    }

    $type = Format-DailyDriverValue -Value (Get-DailyDriverProperty -Object $Project -Name "projectType" -Default "") -Default "project"
    $profile = Format-DailyDriverValue -Value (Get-DailyDriverProperty -Object $Project -Name "profile" -Default "") -Default "TSF"
    return "TSF-registered $type using the $profile profile."
}

function Get-DailyDriverCurrentSources {
    param([string]$FleetRoot)

    $currentText = Get-DailyDriverText -Path (Join-Path $FleetRoot "fleet\status\current.md")
    $todayText = Get-DailyDriverText -Path (Join-Path $FleetRoot "fleet\status\today.md")
    $returnReviewText = Get-DailyDriverText -Path (Join-Path $FleetRoot "fleet\status\return-review.md")

    return [pscustomobject]@{
        fleetMode = Get-DailyDriverStatusLine -Text $currentText -Label "Fleet mode" -Default (Get-DailyDriverStatusLine -Text $todayText -Label "Fleet mode" -Default "unknown")
        supervisor = Get-DailyDriverStatusLine -Text $currentText -Label "Supervisor cycle" -Default (Get-DailyDriverStatusLine -Text $todayText -Label "Supervisor" -Default "unknown")
        emergency = Get-DailyDriverStatusLine -Text $currentText -Label "Emergency stop" -Default (Get-DailyDriverStatusLine -Text $todayText -Label "Emergency" -Default "unknown")
        returnReviewSummary = if ($returnReviewText -match "(?is)## Top recommendation\s+(.+?)(\r?\n## |\z)") { $Matches[1].Trim() } else { "Open Fleet Console and choose one bounded work order." }
    }
}

function New-DailyDriverProjectPassportLines {
    param(
        [object]$Project,
        [object]$Sources
    )

    $state = Get-DailyDriverProjectState -Project $Project
    $name = [string]$Project.name
    $repo = Format-DailyDriverValue -Value $Project.repo -Default "not stored in TSF registry"
    $purpose = Get-DailyDriverProjectPurpose -Project $Project
    $statusColor = Format-DailyDriverValue -Value $Project.statusColor -Default "UNKNOWN"
    $branch = Format-DailyDriverValue -Value $Project.branch -Default "unknown"
    $head = "not stored in TSF-local status"
    $checkpoint = Format-DailyDriverValue -Value $Project.checkpoint -Default "UNKNOWN"
    $buildResult = Format-DailyDriverValue -Value $Project.build -Default "UNKNOWN"
    $buildCommand = Format-DailyDriverValue -Value $Project.buildCommand -Default "not known"
    $buildDirectory = Format-DailyDriverValue -Value $Project.buildDirectory -Default "."
    $nextAction = Format-DailyDriverValue -Value $Project.nextRecommendedAction -Default "Choose a bounded TSF-local work order before product work."
    $note = Format-DailyDriverValue -Value $Project.note -Default "No specific blocker recorded in TSF-local status."
    $guardrails = @($script:DailyDriverGuardrails | ForEach-Object { "- $_" })

    $blockers = @()
    if ($state -eq "archived") {
        $blockers += "Archived/locked; leave parked unless Tim explicitly reactivates it."
    }
    if ($statusColor -eq "UNKNOWN") {
        $blockers += "Latest project status is UNKNOWN in TSF-local status."
    }
    if ($note -match "(?i)not available|missing|unknown") {
        $blockers += $note
    }
    if ($blockers.Count -eq 0) {
        $blockers += "No current blocker recorded in TSF-local status."
    }

    $safeWork = if ($state -eq "archived") {
        "Do not start work. Leave archived unless Tim provides an exact reactivation record."
    } elseif ($state -eq "blocked") {
        "Resolve the blocker or repacketize one TSF-local task before implementation."
    } else {
        "Open the Next Session Card, choose availability, then send one bounded work order to Codex."
    }

    return @(
        "# Project Passport - $name",
        "",
        "Generated by TSF Daily Driver Pack V1 from TSF-local sources only. Evidence only; not executable authority or approval.",
        "",
        "## Project",
        "",
        "- Project name: $name",
        "- Status: $state",
        "- Repo path if known from TSF registry: $repo",
        "- Plain-English purpose: $purpose",
        "- Current TSF verdict if known: status $statusColor; checkpoint $checkpoint; build $buildResult",
        "- Latest known branch/HEAD if stored in TSF-local status: branch $branch; HEAD $head",
        "",
        "## How To Use / Start If Known",
        "",
        "- Start from Fleet Console, not from a product repo search.",
        "- Use one selected project, one availability mode, and one bounded work order.",
        "- Latest handoff: fleet/status/return-review.md",
        "",
        "## How To Validate If Known",
        "",
        "- TSF registry build directory: $buildDirectory",
        "- TSF registry validation command: $buildCommand",
        "- Treat this as reference for a future selected-project packet; this generator does not run it.",
        "",
        "## Off-Limits / Guardrails",
        "",
        $guardrails,
        "",
        "## Current Blockers",
        "",
        @($blockers | ForEach-Object { "- $_" }),
        "",
        "## Next Safe Work",
        "",
        "- $safeWork",
        "- Current status note: $nextAction",
        "",
        "## Latest Handoff Link Or Summary",
        "",
        "- fleet/status/return-review.md: $($Sources.returnReviewSummary)",
        "",
        "## Sources",
        "",
        "- $($Project.source)",
        "- fleet/status/current.md, fleet/status/today.md, fleet/status/projects.md, fleet/status/return-review.md",
        "- docs/fleet/TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md, docs/fleet/TSF_ARTIFACT_INTAKE_FOLDER_SYSTEM.md"
    )
}

function Write-DailyDriverProjectPassports {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string[]]$ProjectName
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\project-passports"
    } else {
        $OutDirectory = Resolve-DailyDriverPath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $sources = Get-DailyDriverCurrentSources -FleetRoot $fleetRootFull
    $projects = @(Get-DailyDriverProjects -FleetRoot $fleetRootFull)
    if ($ProjectName -and $ProjectName.Count -gt 0) {
        $wanted = @($ProjectName | ForEach-Object { $_.ToLowerInvariant() })
        $projects = @($projects | Where-Object { $wanted -contains ([string]$_.name).ToLowerInvariant() })
    }

    $written = @()
    foreach ($project in $projects) {
        $outPath = Join-Path $OutDirectory "$($project.slug).md"
        $lines = New-DailyDriverProjectPassportLines -Project $project -Sources $sources
        $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function New-DailyDriverNextSessionLines {
    param(
        [object]$Project,
        [object]$Sources
    )

    $name = [string]$Project.name
    $state = Get-DailyDriverProjectState -Project $Project
    $needsTim = if ($state -eq "archived") {
        "Tim must explicitly reactivate this archived project before any work."
    } elseif ([string]$Project.statusColor -eq "UNKNOWN") {
        "Choose whether to inspect this project from desktop and pick availability: here, busy, or away."
    } else {
        "Choose the next bounded goal and availability."
    }
    $codexNext = if ($state -eq "archived") {
        "Codex can only summarize existing TSF-local status; no project work."
    } else {
        "Codex should execute bounded selected-project work until the product surface is finished, GREEN, locally committed, or truly blocked."
    }
    $wait = if ($state -eq "archived") { "Everything else; archived work stays quiet." } else { "Archived projects, broad proof runs, publication, deployment, installs, migrations, secrets, and remote access." }
    $statusColor = Format-DailyDriverValue -Value $Project.statusColor -Default "UNKNOWN"
    $branch = Format-DailyDriverValue -Value $Project.branch -Default "unknown"
    $cleanState = Format-DailyDriverValue -Value $Project.cleanState -Default "unknown"
    $latestNote = Format-DailyDriverValue -Value $Project.note -Default "No specific status note recorded."
    $repoPath = Format-DailyDriverValue -Value $Project.repo -Default "<repo path>"

    return @(
        "# Next Session Card - $name",
        "",
        "Short TSF Daily Driver card. Evidence only; not executable authority or approval.",
        "",
        "## Open This First",
        "",
        "- Fleet Console: docs/fleet/ui/prototype/fleet-console.html",
        "- Passport: fleet/status/project-passports/$($Project.slug).md",
        "- Return review: fleet/status/return-review.md",
        "",
        "## Current Status",
        "",
        "- Status: $state",
        "- TSF verdict: status $statusColor; branch $branch; clean $cleanState",
        "- Latest note: $latestNote",
        "",
        "## What Needs Tim",
        "",
        "- $needsTim",
        "",
        "## What Codex Can Do Next",
        "",
        "- $codexNext",
        "",
        "## Suggested Work Order",
        "",
        "~~~text",
        "Project: $name",
        "Repo path: $repoPath",
        "Goal: finish the selected product work, not just inspect or report.",
        "Files/artifacts: fleet/status/project-passports/$($Project.slug).md; fleet/status/next-session/$($Project.slug).md; optional C:\TSF_INBOX\$name\ files named by Tim",
        "Off-limits: product repos unless selected, archived projects unless reactivated, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, command-running browser controls.",
        "Autonomy/availability mode: here | busy | away | completion_first_sleep_run",
        "Stop conditions: conflicting source truth, missing approval, unsafe file scope, failed validation that cannot be safely repaired, or any forbidden action.",
        "Validation expectations: keep moving through safe next steps, run relevant checks, and locally commit GREEN work.",
        "Final report format: morning scoreboard with DONE, COMMIT, CHECKS, STATUS, and TIM REVIEW only for true decisions.",
        "~~~",
        "",
        "## Stop Conditions",
        "",
        "- Product repo inspection is required before Tim selects the project.",
        "- Archived reactivation, push, deploy, install, migration, secrets, remote access, proof run, or all-fleet execution is requested.",
        "- Validation fails and the repair is outside the approved TSF-local scope.",
        "",
        "## What Can Wait",
        "",
        "- $wait"
    )
}

function Write-DailyDriverNextSessionCards {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\next-session"
    } else {
        $OutDirectory = Resolve-DailyDriverPath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $sources = Get-DailyDriverCurrentSources -FleetRoot $fleetRootFull
    $projects = @(Get-DailyDriverProjects -FleetRoot $fleetRootFull)
    if ($ProjectName -and $ProjectName.Count -gt 0) {
        $wanted = @($ProjectName | ForEach-Object { $_.ToLowerInvariant() })
        $projects = @($projects | Where-Object { $wanted -contains ([string]$_.name).ToLowerInvariant() })
    } elseif (!$IncludeArchived) {
        $projects = @($projects | Where-Object { ![bool]$_.archived })
    }

    $written = @()
    foreach ($project in $projects) {
        $outPath = Join-Path $OutDirectory "$($project.slug).md"
        $lines = New-DailyDriverNextSessionLines -Project $project -Sources $sources
        $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function Get-DailyDriverInboxProjectPath {
    param(
        [string]$FleetRoot,
        [string]$InboxRoot,
        [string]$ProjectName
    )

    $candidates = @()
    if (![string]::IsNullOrWhiteSpace($InboxRoot)) {
        $candidates += (Join-Path (Resolve-DailyDriverPath -Root $FleetRoot -Path $InboxRoot) $ProjectName)
    }

    $candidates += (Join-Path "C:\TSF_INBOX" $ProjectName)
    $candidates += (Join-Path (Join-Path $FleetRoot "tests\fixtures\fleet\daily-driver\TSF_INBOX") $ProjectName)
    $candidates += (Join-Path (Join-Path $FleetRoot "intake") $ProjectName)

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $candidates[0]
}

function Get-DailyDriverInboxFiles {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
}

function Get-DailyDriverInboxSummary {
    param(
        [string]$FleetRoot,
        [string]$InboxRoot,
        [string]$ProjectName
    )

    $projectPath = Get-DailyDriverInboxProjectPath -FleetRoot $FleetRoot -InboxRoot $InboxRoot -ProjectName $ProjectName
    $folderNames = @("00_ROOT_CONTEXT", "01_DEEP_RESEARCH", "02_DECISIONS", "03_TASK_REQUESTS", "04_OUTPUTS_FROM_CODEX")
    $folders = @{}
    $missing = @()

    foreach ($folderName in $folderNames) {
        $folderPath = Join-Path $projectPath $folderName
        $files = @(Get-DailyDriverInboxFiles -Path $folderPath)
        $folders[$folderName] = [pscustomobject]@{
            path = $folderPath
            files = $files
            exists = Test-Path -LiteralPath $folderPath
        }
        if (!(Test-Path -LiteralPath $folderPath)) {
            $missing += $folderName
        }
    }

    $decisionFiles = @($folders["02_DECISIONS"].files)
    $approved = @($decisionFiles | Where-Object { $_ -match "(?i)approved|accepted|decided|green" })
    $open = @($decisionFiles | Where-Object { $_ -notmatch "(?i)approved|accepted|decided|green" })

    $fixtureRoot = Join-Path $FleetRoot "tests\fixtures\fleet\daily-driver\TSF_INBOX"
    $preferredRoot = "C:\TSF_INBOX"
    $sourceKind = if ($projectPath.StartsWith($fixtureRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        "safe fixture fallback"
    } elseif ($projectPath.StartsWith($preferredRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        "preferred local inbox"
    } elseif ($projectPath.StartsWith((Join-Path $FleetRoot "intake"), [System.StringComparison]::OrdinalIgnoreCase)) {
        "repo-local intake fallback"
    } else {
        "missing inbox placeholder"
    }

    return [pscustomobject]@{
        projectName = $ProjectName
        projectPath = $projectPath
        sourceKind = $sourceKind
        model = "C:\TSF_INBOX\<project_name>\ with 00_ROOT_CONTEXT, 01_DEEP_RESEARCH, 02_DECISIONS, 03_TASK_REQUESTS, 04_OUTPUTS_FROM_CODEX"
        rootContextFiles = @($folders["00_ROOT_CONTEXT"].files)
        deepResearchFiles = @($folders["01_DEEP_RESEARCH"].files)
        decisionFiles = $decisionFiles
        approvedDecisionFiles = $approved
        openQuestionFiles = $open
        taskRequestFiles = @($folders["03_TASK_REQUESTS"].files)
        codexOutputFiles = @($folders["04_OUTPUTS_FROM_CODEX"].files)
        missingFolders = $missing
        sourceExists = Test-Path -LiteralPath $projectPath
    }
}

function New-DailyDriverWorkOrderLines {
    param(
        [object]$Project,
        [object]$Summary
    )

    $name = [string]$Project.name
    $missing = Format-DailyDriverList -Items $Summary.missingFolders -Empty "none"
    $taskFiles = Format-DailyDriverList -Items $Summary.taskRequestFiles -Empty "none found"
    $repoPath = Format-DailyDriverValue -Value $Project.repo -Default "<repo path>"

    return @(
        "# Work Order Inbox Summary - $name",
        "",
        "Generated by TSF Daily Driver Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## Inbox Model",
        "",
        "- Supported model: $($Summary.model)",
        "- Source type: $($Summary.sourceKind)",
        "- Inbox path inspected for names only: $($Summary.projectPath)",
        "- Source exists: $($Summary.sourceExists)",
        "",
        "## Folder Summary",
        "",
        "- Root context files present: $(Format-DailyDriverList -Items $Summary.rootContextFiles)",
        "- Deep research files present: $(Format-DailyDriverList -Items $Summary.deepResearchFiles)",
        "- Decisions files present: $(Format-DailyDriverList -Items $Summary.decisionFiles)",
        "- Task requests present: $taskFiles",
        "- Outputs from Codex present: $(Format-DailyDriverList -Items $Summary.codexOutputFiles)",
        "- Missing recommended folders: $missing",
        "",
        "## Evidence, Not Authority",
        "",
        "- Root context and deep research are evidence, not authority.",
        "- Outputs from Codex are evidence and must not approve future work.",
        "- Research can inform a bounded task only after Tim selects the project, scope, validation, and stop conditions.",
        "",
        "## Approved Decisions",
        "",
        "- $(Format-DailyDriverList -Items $Summary.approvedDecisionFiles -Empty "none found")",
        "",
        "## Open Questions",
        "",
        "- $(Format-DailyDriverList -Items $Summary.openQuestionFiles -Empty "none found")",
        "",
        "## Suggested Implementation Tasks",
        "",
        "- Convert named task requests into a bounded completion run that keeps going through safe next steps.",
        "- Keep research/root files read-only unless Tim approves exact output files.",
        "",
        "## Generated Codex Work Order Draft",
        "",
        "~~~text",
        "Project: $name",
        "Repo path: $repoPath",
        "Goal: finish the selected product work from $taskFiles, not just inspect or report.",
        "Files/artifacts: $($Summary.projectPath); fleet/status/project-passports/$($Project.slug).md; fleet/status/next-session/$($Project.slug).md",
        "Off-limits: product repos unless selected, archived projects unless reactivated, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, command-running browser controls.",
        "Autonomy/availability mode: here | busy | away | completion_first_sleep_run",
        "Stop conditions: conflicting source truth, missing approval, unsafe file scope, failed validation that cannot be safely repaired, or any forbidden action.",
        "Validation expectations: keep moving through safe next steps, run relevant checks, and locally commit GREEN work.",
        "Final report format: morning scoreboard with DONE, COMMIT, CHECKS, STATUS, and TIM REVIEW only for true decisions.",
        "~~~"
    )
}

function Write-DailyDriverWorkOrderInboxes {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string]$InboxRoot,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\work-orders"
    } else {
        $OutDirectory = Resolve-DailyDriverPath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $projects = @(Get-DailyDriverProjects -FleetRoot $fleetRootFull)
    if ($ProjectName -and $ProjectName.Count -gt 0) {
        $wanted = @($ProjectName | ForEach-Object { $_.ToLowerInvariant() })
        $projects = @($projects | Where-Object { $wanted -contains ([string]$_.name).ToLowerInvariant() })
    } elseif (!$IncludeArchived) {
        $projects = @($projects | Where-Object { ![bool]$_.archived })
    }

    $written = @()
    foreach ($project in $projects) {
        $summary = Get-DailyDriverInboxSummary -FleetRoot $fleetRootFull -InboxRoot $InboxRoot -ProjectName ([string]$project.name)
        $outPath = Join-Path $OutDirectory "$($project.slug)-work-order.md"
        $lines = New-DailyDriverWorkOrderLines -Project $project -Summary $summary
        $lines | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function Resolve-DailyDriverTriageClassification {
    param([object]$Item)

    $archived = [bool](Get-DailyDriverProperty -Object $Item -Name "archived" -Default $false)
    $text = @(
        (Get-DailyDriverProperty -Object $Item -Name "statusColor" -Default ""),
        (Get-DailyDriverProperty -Object $Item -Name "note" -Default ""),
        (Get-DailyDriverProperty -Object $Item -Name "nextRecommendedAction" -Default ""),
        (Get-DailyDriverProperty -Object $Item -Name "status" -Default "")
    ) -join " "
    $status = [string](Get-DailyDriverProperty -Object $Item -Name "statusColor" -Default "UNKNOWN")

    if ($archived) {
        return [pscustomobject]@{ classification = "ARCHIVED_LOCKED"; priority = 60; reason = "Archived projects stay locked unless Tim explicitly reactivates them." }
    }

    if ($status -match "^(RED|BLOCKED)$" -or $text -match "(?i)unsafe|secret|migration|deploy|release|push|remote access|forbidden") {
        return [pscustomobject]@{ classification = "BLOCKED"; priority = 10; reason = "Safety, release, secret, migration, remote, or blocked-state risk comes first." }
    }

    if ($status -match "^(GREEN|READY)$" -or $text -match "(?i)ready to approve|review/approve") {
        return [pscustomobject]@{ classification = "READY_TO_APPROVE"; priority = 30; reason = "Completed or ready work can be reviewed after blockers." }
    }

    if ($text -match "(?i)needs tim|decision|approval|required|unknown|not available|missing" -or $status -eq "UNKNOWN") {
        return [pscustomobject]@{ classification = "NEEDS_TIM_NOW"; priority = 20; reason = "Tim needs to choose, confirm, or resolve unclear status before work proceeds." }
    }

    if ($text -match "(?i)safe to ignore|routine green|collapsed") {
        return [pscustomobject]@{ classification = "SAFE_TO_IGNORE"; priority = 50; reason = "Routine completed work can stay quiet." }
    }

    return [pscustomobject]@{ classification = "NEXT_SAFE_BATCH"; priority = 40; reason = "Active product momentum is eligible after safety and Tim decisions." }
}

function Write-DailyDriverTriageScore {
    param(
        [string]$FleetRoot,
        [string]$OutFile,
        [string]$JsonOutFile
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        $OutFile = Join-Path $fleetRootFull "fleet\status\return-triage-score.md"
    } else {
        $OutFile = Resolve-DailyDriverPath -Root $fleetRootFull -Path $OutFile
    }
    if ([string]::IsNullOrWhiteSpace($JsonOutFile)) {
        $JsonOutFile = Join-Path $fleetRootFull "fleet\status\return-triage-score.json"
    } else {
        $JsonOutFile = Resolve-DailyDriverPath -Root $fleetRootFull -Path $JsonOutFile
    }

    $projects = @(Get-DailyDriverProjects -FleetRoot $fleetRootFull)
    $rows = @()
    foreach ($project in $projects) {
        $classification = Resolve-DailyDriverTriageClassification -Item $project
        $rows += [pscustomobject]@{
            project = [string]$project.name
            statusColor = [string]$project.statusColor
            archived = [bool]$project.archived
            classification = [string]$classification.classification
            priority = [int]$classification.priority
            reason = [string]$classification.reason
            nextSafeAction = if ([bool]$project.archived) { "Leave archived unless Tim reactivates it." } else { Format-DailyDriverValue -Value $project.nextRecommendedAction -Default "Choose one bounded work order." }
        }
    }

    $orderedRows = @($rows | Sort-Object priority, project)
    $top = @($orderedRows | Where-Object { $_.classification -ne "ARCHIVED_LOCKED" } | Select-Object -First 1)
    $topText = if ($top.Count -gt 0) { "$($top[0].project) - $($top[0].classification): $($top[0].nextSafeAction)" } else { "No active project is actionable; archived projects remain locked." }

    $lines = @(
        "# Return Triage Score",
        "",
        "Generated by TSF Daily Driver Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## Top Recommendation",
        "",
        "- $topText",
        "",
        "## Priority Rules",
        "",
        "1. safety/security/deploy risk",
        "2. human decision blockers",
        "3. ready-to-approve completed work",
        "4. active product momentum",
        "5. nice-to-have cleanup",
        "6. archived/locked items last unless explicitly reactivated",
        "",
        "## Classifications",
        "",
        "| Project | Classification | Reason | Next safe action |",
        "| --- | --- | --- | --- |"
    )

    foreach ($row in $orderedRows) {
        $lines += "| $($row.project) | $($row.classification) | $($row.reason) | $($row.nextSafeAction) |"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
    $lines | Set-Content -LiteralPath $OutFile -Encoding UTF8
    @($orderedRows) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonOutFile -Encoding UTF8

    return [pscustomobject]@{
        markdown = $OutFile
        json = $JsonOutFile
        topRecommendation = $topText
        rows = $orderedRows
    }
}
