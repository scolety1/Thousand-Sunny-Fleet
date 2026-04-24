param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$RequestFile = "docs/codex/NEXT_TASK_REQUEST.md",

    [string]$OutFile = "docs/codex/NEXT_TASKS_PROPOSED.md"
)

$ErrorActionPreference = "Continue"

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo path not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

if (!(Test-Path $RequestFile)) {
    Write-Host "Request file not found. Run prepare-next-task-request.ps1 first: $RequestFile" -ForegroundColor Red
    exit 1
}

$prompt = @"
Read the following next-task request and propose the next safe tasks.

Output only markdown checklist tasks. Do not include commentary.

$(Get-Content $RequestFile -Raw)
"@

$tmp = New-TemporaryFile
$prompt | codex exec --full-auto - -o $tmp.FullName
$exit = $LASTEXITCODE

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Planner produced no output." -ForegroundColor Red
    exit 1
}

Copy-Item $tmp.FullName $OutFile -Force
Remove-Item $tmp.FullName -Force

if ($exit -ne 0) {
    Write-Host "Planner exited nonzero, but output was written to $OutFile for manual review." -ForegroundColor Yellow
} else {
    Write-Host "Wrote $OutFile" -ForegroundColor Green
}
