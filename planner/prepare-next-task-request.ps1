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
"@

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Set-Content -Path $outPath -Value $body
Write-Host "Wrote $outPath" -ForegroundColor Green
