param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$ProposedFile = "docs/codex/NEXT_TASKS_PROPOSED.md",

    [string]$QueueFile = "docs/codex/TASK_QUEUE.md",

    [ValidateSet("append", "replace")]
    [string]$Mode = "append"
)

$ErrorActionPreference = "Continue"

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo path not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

if (!(Test-Path $ProposedFile)) {
    Write-Host "Proposed tasks file not found: $ProposedFile" -ForegroundColor Red
    exit 1
}

$lines = Get-Content $ProposedFile
$tasks = @($lines | Where-Object { $_ -match "^\s*-\s+\[ \]\s+.+" })

if ($tasks.Count -eq 0) {
    Write-Host "No unchecked markdown tasks found in $ProposedFile" -ForegroundColor Red
    exit 1
}

$blockedTerms = @(
    "secret",
    "api key",
    "password",
    "deploy",
    "push to main",
    "merge to main",
    "billing",
    "dns"
)

$badTasks = @()
foreach ($task in $tasks) {
    foreach ($term in $blockedTerms) {
        if ($task -match [regex]::Escape($term)) {
            $badTasks += $task
            break
        }
    }

    if ($task -notmatch "(?i)do not|forbidden|without|avoid") {
        $badTasks += $task
    }
}

if ($badTasks.Count -gt 0) {
    Write-Host "Proposed tasks failed validation:" -ForegroundColor Red
    $badTasks | Sort-Object -Unique | ForEach-Object { Write-Host "- $_" }
    exit 1
}

if (!(Test-Path $QueueFile)) {
    New-Item -ItemType File -Force -Path $QueueFile | Out-Null
}

if ($Mode -eq "replace") {
    Set-Content $QueueFile "# Codex Task Queue`n`n## Tasks`n"
}

Add-Content $QueueFile "`n## Imported Planner Tasks $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
$tasks | ForEach-Object { Add-Content $QueueFile $_ }

Write-Host "Imported $($tasks.Count) task(s) into $QueueFile" -ForegroundColor Green
