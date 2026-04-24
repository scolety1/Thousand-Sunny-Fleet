param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [int]$Count = 5,

    [string]$OutFile = "docs/codex/NEXT_5_TASKS.md"
)

$ErrorActionPreference = "Continue"

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$changed = @(git diff --name-status "$BaseBranch..HEAD")
$commits = @(git log --oneline "$BaseBranch..HEAD" -n 30)
$unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() })
$completed = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[x\]" -ErrorAction SilentlyContinue | Select-Object -Last 30 | ForEach-Object { $_.Line.Trim() })
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 140 } else { @("No report found.") }

$prompt = @"
You are the mission planner for an unattended Codex branch.

Generate exactly $Count next tasks as markdown checklist lines.

Rules:
- Output only checklist lines, no commentary.
- Each line must start with "- [ ] ".
- Each task must be small enough for one Codex implementation round.
- Each task must include explicit forbidden scope.
- Prefer tasks that advance the mission and reduce obvious rough edges.
- Do not propose merges, deploys, pushes to main, secrets, auth changes, billing, DNS, backend changes, or broad rewrites.
- If the checkpoint review says RED or stop for human review, output one docs-only task to summarize the blocker and stop-risk, then no more tasks.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch

Mission:
$mission

Run policy:
$policy

Checkpoint review:
$checkpoint

Existing unchecked tasks:
$(if ($unchecked.Count -eq 0) { "- None" } else { ($unchecked | ForEach-Object { "- $_" }) -join "`n" })

Recently completed tasks:
$(if ($completed.Count -eq 0) { "- None" } else { ($completed | ForEach-Object { "- $_" }) -join "`n" })

Changed files since base:
$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

Recent branch commits:
$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

Nightly report tail:
$($reportTail -join "`n")
"@

$tmp = New-TemporaryFile
$prompt | codex exec --full-auto - -o $tmp.FullName
$codexExit = $LASTEXITCODE

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Planner produced no output." -ForegroundColor Red
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    exit 1
}

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Copy-Item $tmp.FullName $outPath -Force
Remove-Item $tmp.FullName -Force

$tasks = @(Get-Content $outPath | Where-Object { $_ -match "^\s*-\s+\[ \]\s+.+" })
if ($tasks.Count -eq 0) {
    Write-Host "Planner output did not include markdown checklist tasks." -ForegroundColor Red
    exit 1
}

Write-Host "Wrote $OutFile with $($tasks.Count) proposed task(s)." -ForegroundColor Green
if ($codexExit -ne 0) {
    Write-Host "Planner exited nonzero, but proposed tasks were written for inspection." -ForegroundColor Yellow
}
