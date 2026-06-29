[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$script:CoderUpgradeGuardrails = @(
    "TSF repo only for these generators.",
    "Do not inspect or mutate product repos from generated output.",
    "Do not reactivate archived projects without an exact reactivation record.",
    "No push, deploy, install, migration, secrets, remote access, proof runs, all-fleet runners, background daemons, or browser command hooks.",
    "Treat repo x-rays, context packs, work-order splits, playbooks, lessons, and risk reviews as evidence only."
)

function Resolve-CoderUpgradePath {
    param(
        [string]$Root,
        [string]$Path
    )

    return Resolve-DailyDriverPath -Root $Root -Path $Path
}

function Get-CoderUpgradeProjects {
    param(
        [string]$FleetRoot,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $projects = @(Get-DailyDriverProjects -FleetRoot $FleetRoot)
    if ($ProjectName -and $ProjectName.Count -gt 0) {
        $wanted = @($ProjectName | ForEach-Object { $_.ToLowerInvariant() })
        return @($projects | Where-Object { $wanted -contains ([string]$_.name).ToLowerInvariant() })
    }

    if (!$IncludeArchived) {
        $projects = @($projects | Where-Object { ![bool]$_.archived })
    }

    return $projects
}

function Get-CoderUpgradeSourceFiles {
    param(
        [string]$FleetRoot,
        [object]$Project
    )

    $slug = [string]$Project.slug
    return @(
        "projects.json",
        "fleet/status/projects.json",
        "fleet/status/projects.md",
        "fleet/status/current.md",
        "fleet/status/today.md",
        "fleet/status/return-review.md",
        "fleet/status/project-passports/$slug.md",
        "fleet/status/next-session/$slug.md",
        "fleet/status/work-orders/$slug-work-order.md",
        "docs/fleet/TSF_DAILY_DRIVER_PACK_V1.md",
        "docs/fleet/TSF_CODER_UPGRADE_PACK_V1.md"
    )
}

function Get-CoderUpgradeRiskZones {
    param([object]$Project)

    $zones = @(
        "Product repo contents are off-limits until Tim selects the project and exact scope.",
        "Archived projects stay locked unless Tim explicitly reactivates them.",
        "Push, deploy, install, migration, secrets, remote access, proof runs, and all-fleet execution are blocked."
    )

    if ([bool]$Project.archived) {
        $zones += "This project is archived, so no implementation task is actionable."
    }

    if ([string]$Project.statusColor -eq "UNKNOWN") {
        $zones += "TSF-local status is UNKNOWN; use read-only context before implementation."
    }

    return $zones
}

function Get-CoderUpgradeCurrentDiffFiles {
    param([string]$FleetRoot)

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    $originalLocation = (Get-Location).Path
    try {
        Set-Location -LiteralPath $fleetRootFull
        $statusLines = @(& git status --short --untracked-files=all 2>$null)
    } finally {
        Set-Location -LiteralPath $originalLocation
    }

    $files = @()
    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $path = $line.Substring(3).Trim()
        if ($path -match "\s+->\s+") {
            $path = ($path -split "\s+->\s+")[-1].Trim()
        }

        if (![string]::IsNullOrWhiteSpace($path)) {
            $files += ($path -replace "/", "\")
        }
    }

    return @($files | Sort-Object -Unique)
}

function Get-CoderUpgradeDiffRiskFixture {
    param([string]$Case)

    switch -Regex ($Case.ToLowerInvariant()) {
        "^low$" {
            return [pscustomobject]@{
                changedFiles = @("docs\fleet\notes.md", "tests\fixtures\fleet\readme.md")
                diffText = "Docs, copy, and fixture notes only."
            }
        }
        "^medium$" {
            return [pscustomobject]@{
                changedFiles = @("tools\render-fleet-console.ps1", "fleet\status\current.md")
                diffText = "Renderer and generated status output changed."
            }
        }
        "^high$" {
            return [pscustomobject]@{
                changedFiles = @("tools\codex-fleet-runtime.ps1", "templates\task-packet-schema.json")
                diffText = "Core workflow and guardrail schema behavior changed."
            }
        }
        "^blocked$" {
            return [pscustomobject]@{
                changedFiles = @(".env", "docs\fleet\deploy-plan.md", "tools\remote-access-helper.ps1")
                diffText = "Requires secrets, deploy approval, package installation, migration, remote access, push, product repo mutation, and archived project reactivation."
            }
        }
        default {
            throw "Unknown diff risk fixture case: $Case"
        }
    }
}

function Resolve-CoderUpgradeDiffRisk {
    param(
        [string[]]$ChangedFiles,
        [string]$DiffText = ""
    )

    $files = @($ChangedFiles | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    $joined = (($files -join "`n"), $DiffText) -join "`n"
    $normalizedFiles = @($files | ForEach-Object { $_ -replace "/", "\" })

    $blockedPattern = "(?i)(^|[\\/])\.env(\.|$)|secret|credential|password|private key|deploy|release|migration|remote access|remote-access|push\b|product repo mutation|product repo content|reactivat(e|ion).*archived|archived project reactivation|package installation|install packages|all-fleet|background daemon|browser command hook"
    $highFilePattern = "(?i)(tools[\\/]codex-fleet-(runtime|autonomy|overnight|mobile|external-agent|control-room|state|decision)\.ps1|templates[\\/][^\r\n]*schema\.json|docs[\\/]fleet[\\/][^\r\n]*(POLICY|OPERATING_MODEL|CONTROL|SAFETY|BOUNDARY)[^\r\n]*\.md)"
    $highTextPattern = "(?i)(core workflow|guardrail schema|policy gate|runtime policy|approval bypass|safety boundary)"
    $mediumFilePattern = "(?i)(tools[\\/][^\r\n]+\.ps1|render|renderer|fleet[\\/]status[\\/]|docs[\\/]fleet[\\/]ui[\\/]prototype[\\/]|status generation)"

    if ($joined -match $blockedPattern) {
        return [pscustomobject]@{
            riskLevel = "BLOCKED"
            why = "Forbidden action, secret, release, migration, remote, product-repo, archive-reactivation, or broad execution risk appears in the diff."
            recommendedValidation = "Stop. Repacketize into a TSF-local review. Do not commit until Tim removes the forbidden action."
            humanApprovalNeeded = $true
            suggestedCommitMessage = ""
        }
    }

    if ((($normalizedFiles -join "`n") -match $highFilePattern) -or ($joined -match $highTextPattern)) {
        return [pscustomobject]@{
            riskLevel = "HIGH"
            why = "Core workflow, policy, guardrail, schema, or safety-boundary logic appears to be changing."
            recommendedValidation = "Run full fleet tests and get human review before approving the commit."
            humanApprovalNeeded = $true
            suggestedCommitMessage = "Update TSF workflow guardrails"
        }
    }

    if ((($normalizedFiles -join "`n") -match $mediumFilePattern)) {
        return [pscustomobject]@{
            riskLevel = "MEDIUM"
            why = "Scripts, renderers, static console, or generated status outputs changed."
            recommendedValidation = "Run git diff --check and the full fleet test suite before commit."
            humanApprovalNeeded = $false
            suggestedCommitMessage = "Update TSF local tooling"
        }
    }

    return [pscustomobject]@{
        riskLevel = "LOW"
        why = "Only docs, copy, tests, or fixture-shaped files changed."
        recommendedValidation = "Run focused tests or the full fleet suite if this is part of a pack."
        humanApprovalNeeded = $false
        suggestedCommitMessage = "Update TSF docs and fixtures"
    }
}

function New-CoderUpgradeDiffRiskLines {
    param(
        [string[]]$ChangedFiles,
        [object]$Risk,
        [string]$SourceLabel
    )

    $files = @($ChangedFiles | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($files.Count -eq 0) {
        $files = @("none")
    }

    $approval = if ([bool]$Risk.humanApprovalNeeded) { "yes" } else { "no" }
    $commitMessage = if ([string]::IsNullOrWhiteSpace([string]$Risk.suggestedCommitMessage)) { "none; blocked review has no safe commit message" } else { [string]$Risk.suggestedCommitMessage }

    return @(
        "# Diff Risk Review",
        "",
        "Generated by TSF Coder Upgrade Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## Source",
        "",
        "- Review source: $SourceLabel",
        "",
        "## Risk Result",
        "",
        "- Risk level: $($Risk.riskLevel)",
        "- Why it matters: $($Risk.why)",
        "- Recommended validation: $($Risk.recommendedValidation)",
        "- Human approval needed: $approval",
        "- Suggested commit message if safe: $commitMessage",
        "",
        "## Files Changed",
        "",
        @($files | ForEach-Object { "- $_" }),
        "",
        "## Boundaries",
        "",
        "- This review never pushes, deploys, installs, migrates, touches secrets, or mutates product repos.",
        "- BLOCKED means stop and repacketize before any commit approval.",
        "- LOW/MEDIUM/HIGH are review labels, not permission to bypass validation."
    )
}

function Write-CoderUpgradeDiffRiskReview {
    param(
        [string]$FleetRoot,
        [string]$OutFile,
        [string]$FixtureCase
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        $OutFile = Join-Path $fleetRootFull "fleet\status\diff-risk-review.md"
    } else {
        $OutFile = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutFile
    }

    if (![string]::IsNullOrWhiteSpace($FixtureCase)) {
        $fixture = Get-CoderUpgradeDiffRiskFixture -Case $FixtureCase
        $files = @($fixture.changedFiles)
        $risk = Resolve-CoderUpgradeDiffRisk -ChangedFiles $files -DiffText ([string]$fixture.diffText)
        $sourceLabel = "fixture case: $FixtureCase"
    } else {
        $files = @(Get-CoderUpgradeCurrentDiffFiles -FleetRoot $fleetRootFull)
        $risk = Resolve-CoderUpgradeDiffRisk -ChangedFiles $files
        $sourceLabel = "current TSF repo working tree"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    New-CoderUpgradeDiffRiskLines -ChangedFiles $files -Risk $risk -SourceLabel $sourceLabel | Set-Content -LiteralPath $OutFile -Encoding UTF8
    return [pscustomobject]@{
        path = $OutFile
        riskLevel = $risk.riskLevel
        filesChanged = $files
        humanApprovalNeeded = $risk.humanApprovalNeeded
    }
}

function New-CoderUpgradeRepoXrayLines {
    param([object]$Project)

    $name = [string]$Project.name
    $state = Get-DailyDriverProjectState -Project $Project
    $repo = Format-DailyDriverValue -Value $Project.repo -Default "not stored in TSF registry"
    $purpose = Get-DailyDriverProjectPurpose -Project $Project
    $entrypoints = @(
        "Profile: $(Format-DailyDriverValue -Value $Project.profile -Default "unknown")",
        "Build directory: $(Format-DailyDriverValue -Value $Project.buildDirectory -Default ".")",
        "Build command: $(Format-DailyDriverValue -Value $Project.buildCommand -Default "not known")"
    )
    $testCommand = Format-DailyDriverValue -Value $Project.buildCommand -Default "not known from TSF metadata"
    $docs = Get-CoderUpgradeSourceFiles -FleetRoot "" -Project $Project
    $riskZones = Get-CoderUpgradeRiskZones -Project $Project
    $blocker = if ($state -eq "archived") { "Archived/locked; no implementation task is actionable." } elseif ([string]$Project.statusColor -eq "UNKNOWN") { "TSF-local status is UNKNOWN." } else { "No specific blocker recorded in TSF-local status." }

    return @(
        "# Repo X-Ray - $name",
        "",
        "Generated by TSF Coder Upgrade Pack V1 from TSF-local metadata only. Evidence only; not executable authority or approval.",
        "",
        "## Repo Identity",
        "",
        "- Project name: $name",
        "- Repo path if known: $repo",
        "- Status: $state",
        "- Plain-English purpose: $purpose",
        "- Current branch/HEAD if known from TSF-local status: branch $(Format-DailyDriverValue -Value $Project.branch -Default "unknown"); HEAD not stored in TSF-local status",
        "",
        "## Main App / Tool Entrypoints If Known",
        "",
        @($entrypoints | ForEach-Object { "- $_" }),
        "",
        "## Test Commands If Known",
        "",
        "- $testCommand",
        "- This X-Ray records commands only; it does not run them.",
        "",
        "## Important Docs / Status Files",
        "",
        @($docs | ForEach-Object { "- $_" }),
        "",
        "## Known Blockers",
        "",
        "- $blocker",
        "",
        "## Risk Zones / Off-Limits",
        "",
        @($riskZones | ForEach-Object { "- $_" }),
        "",
        "## Next Safe Inspection Task",
        "",
        "- Read TSF-local status, passport, next-session card, and context pack before opening any product repo.",
        "",
        "## Suggested Codex Prompt To Understand The Repo",
        "",
        "~~~text",
        "Project: $name",
        "Repo path: $repo",
        "Goal: explain the repo using TSF-local metadata first, then ask Tim before inspecting product repo contents.",
        "Read first: fleet/status/repo-xray/$($Project.slug).md; fleet/status/context-packs/$($Project.slug)-context-pack.md; fleet/status/project-passports/$($Project.slug).md",
        "Off-limits: product repo inspection unless Tim explicitly selects this project and scope; archived reactivation; push; deploy; install; migration; secrets; remote access.",
        "Output: purpose, likely entrypoints, test commands, risk zones, open questions, and one safe next inspection task.",
        "~~~"
    )
}

function Write-CoderUpgradeRepoXrays {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\repo-xray"
    } else {
        $OutDirectory = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $written = @()
    foreach ($project in @(Get-CoderUpgradeProjects -FleetRoot $fleetRootFull -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)) {
        $outPath = Join-Path $OutDirectory "$($project.slug).md"
        New-CoderUpgradeRepoXrayLines -Project $project | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function New-CoderUpgradeContextPackLines {
    param(
        [object]$Project,
        [object]$InboxSummary
    )

    $name = [string]$Project.name
    $state = Get-DailyDriverProjectState -Project $Project
    $sourceFiles = Get-CoderUpgradeSourceFiles -FleetRoot "" -Project $Project
    $guardrails = @($script:CoderUpgradeGuardrails | ForEach-Object { "- $_" })
    $taskCandidates = @()
    if (![string]::IsNullOrWhiteSpace([string]$Project.nextRecommendedAction)) {
        $taskCandidates += [string]$Project.nextRecommendedAction
    }
    $taskCandidates += @($InboxSummary.taskRequestFiles | ForEach-Object { "Inbox task request: $_" })
    if ($taskCandidates.Count -eq 0) {
        $taskCandidates += "Ask Tim for one bounded goal before implementation."
    }

    return @(
        "# Context Pack - $name",
        "",
        "Generated by TSF Coder Upgrade Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## What Codex Needs To Know",
        "",
        "- Project: $name",
        "- Status: $state",
        "- Purpose: $(Get-DailyDriverProjectPurpose -Project $Project)",
        "- Repo path from TSF registry: $(Format-DailyDriverValue -Value $Project.repo -Default "not stored")",
        "",
        "## Current Status",
        "",
        "- TSF status: $(Format-DailyDriverValue -Value $Project.statusColor -Default "UNKNOWN")",
        "- Branch: $(Format-DailyDriverValue -Value $Project.branch -Default "unknown")",
        "- Clean state: $(Format-DailyDriverValue -Value $Project.cleanState -Default "unknown")",
        "- Status note: $(Format-DailyDriverValue -Value $Project.note -Default "none recorded")",
        "",
        "## Source-Truth Files",
        "",
        @($sourceFiles | ForEach-Object { "- $_" }),
        "",
        "## Approved Decisions",
        "",
        "- $(Format-DailyDriverList -Items $InboxSummary.approvedDecisionFiles -Empty "none found")",
        "",
        "## Open Questions",
        "",
        "- $(Format-DailyDriverList -Items $InboxSummary.openQuestionFiles -Empty "none found")",
        "",
        "## Guardrails",
        "",
        $guardrails,
        "",
        "## Current Task Candidates",
        "",
        @($taskCandidates | ForEach-Object { "- $_" }),
        "",
        "## Validation Expectations",
        "",
        "- Use known TSF metadata command if selected: $(Format-DailyDriverValue -Value $Project.buildCommand -Default "not known")",
        "- Run only validation named in the bounded work order.",
        "- Stop if validation requires install, deploy, migration, secrets, remote access, proof run, or product repo mutation outside selected scope.",
        "",
        "## Final Report Format",
        "",
        "- Verdict",
        "- Files changed",
        "- What changed",
        "- Tests/checks run",
        "- Blockers",
        "- Next safe action"
    )
}

function Write-CoderUpgradeContextPacks {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string]$InboxRoot,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\context-packs"
    } else {
        $OutDirectory = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $written = @()
    foreach ($project in @(Get-CoderUpgradeProjects -FleetRoot $fleetRootFull -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)) {
        $summary = Get-DailyDriverInboxSummary -FleetRoot $fleetRootFull -InboxRoot $InboxRoot -ProjectName ([string]$project.name)
        $outPath = Join-Path $OutDirectory "$($project.slug)-context-pack.md"
        New-CoderUpgradeContextPackLines -Project $project -InboxSummary $summary | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function Get-CoderUpgradeSpecGoal {
    param(
        [string]$FleetRoot,
        [string]$ProjectName,
        [string]$SpecPath
    )

    if (![string]::IsNullOrWhiteSpace($SpecPath)) {
        $resolved = Resolve-CoderUpgradePath -Root $FleetRoot -Path $SpecPath
        if (Test-Path -LiteralPath $resolved) {
            return (Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop).Trim()
        }
    }

    $fixturePath = Join-Path $FleetRoot "tests\fixtures\fleet\coder-upgrade\spec-goals\$ProjectName\messy-goal.md"
    if (Test-Path -LiteralPath $fixturePath) {
        return (Get-Content -LiteralPath $fixturePath -Raw -ErrorAction Stop).Trim()
    }

    return "Turn the current project goal into one small, testable implementation path."
}

function New-CoderUpgradeWorkOrderSplitLines {
    param(
        [object]$Project,
        [string]$GoalText
    )

    $name = [string]$Project.name
    $repo = Format-DailyDriverValue -Value $Project.repo -Default "<repo path>"
    $validation = Format-DailyDriverValue -Value $Project.buildCommand -Default "run only the validation command named by Tim"
    $tasks = @(
        [pscustomobject]@{ title = "Confirm source truth and scope"; acceptance = "Context pack, passport, and task request agree on one bounded goal."; check = "No conflicting source truth remains." },
        [pscustomobject]@{ title = "Define the smallest product-shaped slice"; acceptance = "One user-visible or operator-visible slice is named with allowed files and stop conditions."; check = "Task is small enough to finish in one session." },
        [pscustomobject]@{ title = "Implement the safe slice"; acceptance = "Only approved files are changed and forbidden actions are avoided."; check = $validation },
        [pscustomobject]@{ title = "Review diff risk before commit approval"; acceptance = "Diff Risk Reviewer is LOW or MEDIUM, or Tim reviews HIGH."; check = "fleet/status/diff-risk-review.md updated." },
        [pscustomobject]@{ title = "Refresh handoff"; acceptance = "Next Session Card or final report names the next safe action."; check = "Final report includes blockers and validation." }
    )

    return @(
        "# Work Order Split - $name",
        "",
        "Generated by TSF Coder Upgrade Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## Messy Goal Input",
        "",
        $GoalText,
        "",
        "## Bounded Tasks",
        "",
        @($tasks | ForEach-Object -Begin { $script:taskIndex = 0 } -Process {
            $script:taskIndex++
            @(
                "### Task $script:taskIndex - $($_.title)",
                "",
                "- Recommended order: $script:taskIndex",
                "- Acceptance criteria: $($_.acceptance)",
                "- Off-limits: product repos unless selected, archived reactivation, push, deploy, install, migration, secrets, remote access, proof runs, all-fleet commands, executable browser controls.",
                "- Stop conditions: unclear source truth, unsafe scope, failed validation outside approved repair, forbidden action requirement, or too-large task scope.",
                "- Validation commands: $($_.check)",
                ""
            )
        }),
        "## Final Report Format",
        "",
        "- Completed task",
        "- Files changed",
        "- Acceptance evidence",
        "- Validation commands and result",
        "- Stop conditions hit",
        "- Next bounded task"
    )
}

function Write-CoderUpgradeWorkOrderSplits {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string]$SpecPath,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\work-order-splits"
    } else {
        $OutDirectory = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $written = @()
    foreach ($project in @(Get-CoderUpgradeProjects -FleetRoot $fleetRootFull -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)) {
        $goal = Get-CoderUpgradeSpecGoal -FleetRoot $fleetRootFull -ProjectName ([string]$project.name) -SpecPath $SpecPath
        $outPath = Join-Path $OutDirectory "$($project.slug)-split.md"
        New-CoderUpgradeWorkOrderSplitLines -Project $project -GoalText $goal | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function New-CoderUpgradeStuckPlaybookLines {
    param([object]$Project)

    $name = [string]$Project.name
    $repo = Format-DailyDriverValue -Value $Project.repo -Default "<repo path>"
    $types = @(
        [pscustomobject]@{ name = "failing tests"; happened = "Validation failed or became ambiguous."; cause = "Recent change, stale fixture, missing local setup, or wrong command."; codex = "read the first failure, inspect changed TSF-local files, try one narrow repair"; tim = "test requires product secrets, install, migration, deploy, or direction choice" },
        [pscustomobject]@{ name = "dirty working tree"; happened = "Uncommitted changes exist."; cause = "Previous run or generated output changed files."; codex = "summarize changed TSF files and run Diff Risk Reviewer"; tim = "changes include product repo files or unclear ownership" },
        [pscustomobject]@{ name = "unclear product direction"; happened = "The next product choice is ambiguous."; cause = "Goal is too broad or source truth conflicts."; codex = "split into options and recommend one safe default"; tim = "business/product decision changes the user outcome" },
        [pscustomobject]@{ name = "conflicting source truth"; happened = "Docs, inbox, and status disagree."; cause = "Old handoff or stale research."; codex = "list conflicts with source file names only"; tim = "must choose authoritative source" },
        [pscustomobject]@{ name = "missing files"; happened = "Referenced files are unavailable."; cause = "Inbox incomplete or path typo."; codex = "generate a missing-file checklist"; tim = "needed source files are not in TSF-local inputs" },
        [pscustomobject]@{ name = "archived project boundary"; happened = "A task targets an archived project."; cause = "Old idea or accidental selection."; codex = "leave archived and suggest active alternative"; tim = "explicit reactivation is required" },
        [pscustomobject]@{ name = "forbidden action requirement"; happened = "Task asks for push, deploy, install, migration, secrets, remote access, proof run, or all-fleet action."; cause = "Goal exceeds TSF sleep-safe authority."; codex = "stop and rewrite as read-only review"; tim = "approval or external action is required" },
        [pscustomobject]@{ name = "too-large task scope"; happened = "Task cannot be finished and tested in one bounded pass."; cause = "Spec bundled too many goals."; codex = "use Work Order Splitter and pick Task 1"; tim = "priority/order choice is needed" }
    )

    $lines = @(
        "# Stuck-State Playbook - $name",
        "",
        "Generated by TSF Coder Upgrade Pack V1. Evidence only; not executable authority or approval.",
        "",
        "## Project",
        "",
        "- Project: $name",
        "- Repo path: $repo",
        "",
        "## Playbook"
    )

    foreach ($type in $types) {
        $lines += @(
            "",
            "### $($type.name)",
            "",
            "- What happened: $($type.happened)",
            "- Likely cause: $($type.cause)",
            "- Safe next checks: read TSF-local status, inspect current diff risk, verify source files exist, and rerun only named validation.",
            "- What Codex can try without Tim: $($type.codex).",
            "- When Tim is required: $($type.tim).",
            "- Suggested prompt to continue: Project $name; stuck type $($type.name); use TSF-local evidence only; try one safe repair or report the exact Tim decision needed."
        )
    }

    return $lines
}

function Write-CoderUpgradeStuckPlaybooks {
    param(
        [string]$FleetRoot,
        [string]$OutDirectory,
        [string[]]$ProjectName,
        [switch]$IncludeArchived
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
        $OutDirectory = Join-Path $fleetRootFull "fleet\status\stuck-playbooks"
    } else {
        $OutDirectory = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutDirectory
    }

    New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
    $written = @()
    foreach ($project in @(Get-CoderUpgradeProjects -FleetRoot $fleetRootFull -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)) {
        $outPath = Join-Path $OutDirectory "$($project.slug)-stuck-playbook.md"
        New-CoderUpgradeStuckPlaybookLines -Project $project | Set-Content -LiteralPath $outPath -Encoding UTF8
        $written += $outPath
    }

    return $written
}

function New-CoderUpgradeLessonsLines {
    param([string]$FleetRoot)

    $fixtureLesson = Join-Path $FleetRoot "tests\fixtures\fleet\coder-upgrade\lessons\console-copy-regression.md"
    $lessonBody = if (Test-Path -LiteralPath $fixtureLesson) {
        (Get-Content -LiteralPath $fixtureLesson -Raw -ErrorAction Stop).Trim()
    } else {
        "Problem: Static console copy drifted from regression phrases.`nCause: A quiet UI polish removed exact V3 wording.`nFix: Restore the required phrase in read-only copy.`nHow to catch earlier next time: run static prototype phrase tests after console edits.`nTest/check to add: assert required phrases and no executable hooks.`nApplies to which projects/tools: Fleet Console, Daily Driver, Coder Upgrade."
    }

    return @(
        "# Coding Lessons Learned",
        "",
        "Generated by TSF Coder Upgrade Pack V1 from TSF-local fixtures/reports. Evidence only; not executable authority or approval.",
        "",
        "## Lesson 1",
        "",
        $lessonBody,
        "",
        "## How To Use This Journal",
        "",
        "- Before a similar change, scan the matching lesson.",
        "- Convert the catch-earlier note into a focused regression check.",
        "- Keep lessons short enough to read before coding."
    )
}

function Write-CoderUpgradeBugJournal {
    param(
        [string]$FleetRoot,
        [string]$OutFile
    )

    $fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        $OutFile = Join-Path $fleetRootFull "fleet\status\coding-lessons\lessons-learned.md"
    } else {
        $OutFile = Resolve-CoderUpgradePath -Root $fleetRootFull -Path $OutFile
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    New-CoderUpgradeLessonsLines -FleetRoot $fleetRootFull | Set-Content -LiteralPath $OutFile -Encoding UTF8
    return $OutFile
}
