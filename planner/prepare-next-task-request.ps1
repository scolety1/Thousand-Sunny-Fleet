param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/NEXT_TASK_REQUEST.md"
)

$ErrorActionPreference = "Continue"

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo path not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$status = @(git status --short)
$commits = @(git log --oneline -n 8)
$changed = @(git show --name-only --format="" HEAD | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() })
$completed = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[x\]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() })
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 120 } else { @("No report found.") }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$siteMap = if (Test-Path "docs/codex/SITE_MAP.md") { Get-Content "docs/codex/SITE_MAP.md" -Raw } else { "No site map found." }
$visualRoutes = if (Test-Path "docs/codex/visual-routes.json") { Get-Content "docs/codex/visual-routes.json" -Raw } else { "No visual route config found." }

$body = @"
# Next Task Request

You are the planner/reviewer for this project.

Return only safe markdown checklist tasks suitable for docs/codex/TASK_QUEUE.md.

Each task must:
- start with `- [ ]`
- be small enough for one Codex round
- include explicit forbidden scope
- obey the run policy
- avoid broad rewrites
- use SITE_MAP.md and visual-routes.json when route/page work would make the product clearer
- not say "preserve current routes" when the goal is real pages, page splits, navigation repair, or route cleanup
- use impact:visible for normal user-facing design/copy/page/mobile tasks and impact:showpiece for final, demo-ready, major redesign, premium, or high-expectation creative tasks
- make visible/showpiece tasks target actual product source, route, component, content, or style files rather than report-only or tiny spacing-only changes

## Repo

- Path: $($repoPath.Path)
- Branch: $branch
- HEAD: $head

## Working Tree

$(if ($status.Count -eq 0) { "- Clean" } else { ($status | ForEach-Object { "- $_" }) -join "`n" })

## Recent Commits

$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

## Files In Latest Commit

$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

## Completed Tasks

$(if ($completed.Count -eq 0) { "- None" } else { ($completed | ForEach-Object { "- $_" }) -join "`n" })

## Remaining Tasks

$(if ($unchecked.Count -eq 0) { "- None" } else { ($unchecked | ForEach-Object { "- $_" }) -join "`n" })

## Nightly Report Tail

$($reportTail -join "`n")

## Run Policy

$policy

## Site Map

$siteMap

## Visual Routes

$visualRoutes
"@

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Set-Content -Path $outPath -Value $body
Write-Host "Wrote $outPath" -ForegroundColor Green
