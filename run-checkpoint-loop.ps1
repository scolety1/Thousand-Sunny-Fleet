[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project,

    [string]$Repo,

    [string]$ConfigPath = ".\projects.json",

    [string]$BaseBranch = "main",

    [int]$BatchSize = 5,

    [int]$MaxBatches = 1,

    [int]$MaxCodexAttempts = 4,

    [int]$VisualEvery = 0,

    [int]$VisualInspectEvery = 0,

    [int]$SimonEvery = 0,

    [int]$JoeyEvery = 0,

    [switch]$PushCheckpoint,

    [switch]$SkipDebug,

    [switch]$ContinueOnYellowCheckpoint,

    [switch]$ValidateOnly,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Continue"

function Stop-Usage {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\run-checkpoint-loop.ps1 -Project RestaurantDemo -BatchSize 2 -MaxBatches 1"
    Write-Host ""
    Write-Host "Important: use normal hyphens (-), not smart dashes copied from rich text." -ForegroundColor Yellow
    exit 1
}

function Test-SmartDash {
    param([string[]]$Values)

    $smartDashCodes = @(0x2012, 0x2013, 0x2014, 0x2015)
    foreach ($value in $Values) {
        foreach ($char in $value.ToCharArray()) {
            if ($smartDashCodes -contains [int][char]$char) {
                return $true
            }
        }
    }
    return $false
}

if ($ExtraArgs.Count -gt 0) {
    Stop-Usage "Unexpected extra arguments: $($ExtraArgs -join ' ')"
}

if (Test-SmartDash @($Project, $Repo, $ConfigPath, $BaseBranch)) {
    Stop-Usage "Smart dash detected in command arguments."
}

if ($BatchSize -lt 1) {
    Stop-Usage "-BatchSize must be at least 1."
}

if ($MaxBatches -lt 1) {
    Stop-Usage "-MaxBatches must be at least 1."
}

if ($VisualEvery -lt 0) {
    Stop-Usage "-VisualEvery must be 0 or greater."
}

if ($VisualInspectEvery -lt 0) {
    Stop-Usage "-VisualInspectEvery must be 0 or greater."
}

if ($SimonEvery -lt 0) {
    Stop-Usage "-SimonEvery must be 0 or greater."
}

if ($JoeyEvery -lt 0) {
    Stop-Usage "-JoeyEvery must be 0 or greater."
}

function Get-ProjectConfig {
    if (![string]::IsNullOrWhiteSpace($Repo)) {
        return [pscustomobject]@{
            name = (Split-Path -Leaf $Repo)
            repo = $Repo
            buildDirectory = ""
            buildCommand = ""
        }
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-Usage "Missing required -Project or -Repo value."
    }

    if (!(Test-Path $ConfigPath)) {
        Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    $projectName = [string]$Project
    $match = @($projects | Where-Object { [string]$_.name -ceq $projectName })
    if ($match.Count -ne 1) {
        Write-Host "Project not found or ambiguous: $Project" -ForegroundColor Red
        Write-Host "Available projects:"
        $projects | ForEach-Object { Write-Host "- $($_.name)" }
        exit 1
    }
    return $match[0]
}

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ConfigScalar {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    $projectValue = Get-ConfigPropertyValue -Object $script:projectConfig -Name $Name
    if ($null -ne $projectValue -and ![string]::IsNullOrWhiteSpace([string]$projectValue)) {
        return [string]$projectValue
    }

    $profileValue = Get-ConfigPropertyValue -Object $script:profileConfig -Name $Name
    if ($null -ne $profileValue -and ![string]::IsNullOrWhiteSpace([string]$profileValue)) {
        return [string]$profileValue
    }

    return $Default
}

function Get-ConfigArray {
    param([string]$Name)

    $projectValue = Get-ConfigPropertyValue -Object $script:projectConfig -Name $Name
    if ($null -ne $projectValue) {
        return @($projectValue | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }

    $profileValue = Get-ConfigPropertyValue -Object $script:profileConfig -Name $Name
    if ($null -ne $profileValue) {
        return @($profileValue | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }

    return @()
}

function Get-RoleModelFrom {
    param(
        [object]$ConfigObject,
        [string]$Role
    )

    if ($null -eq $ConfigObject) { return "" }

    $models = Get-ConfigPropertyValue -Object $ConfigObject -Name "models"
    if ($null -ne $models) {
        foreach ($key in @($Role, "${Role}Model")) {
            $value = Get-ConfigPropertyValue -Object $models -Name $key
            if ($null -ne $value -and ![string]::IsNullOrWhiteSpace([string]$value)) {
                return [string]$value
            }
        }
    }

    foreach ($key in @("${Role}Model", "model")) {
        $value = Get-ConfigPropertyValue -Object $ConfigObject -Name $key
        if ($null -ne $value -and ![string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return ""
}

function Get-ProjectModel {
    param([string]$Role)

    $projectModel = Get-RoleModelFrom -ConfigObject $script:projectConfig -Role $Role
    if (![string]::IsNullOrWhiteSpace($projectModel)) { return $projectModel }

    $profileModel = Get-RoleModelFrom -ConfigObject $script:profileConfig -Role $Role
    if (![string]::IsNullOrWhiteSpace($profileModel)) { return $profileModel }

    return ""
}

function Stage-Files {
    param([string[]]$Paths)

    $cleanPaths = @($Paths |
        Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { ([string]$_).Replace("\", "/") } |
        Sort-Object -Unique)

    if ($cleanPaths.Count -eq 0) {
        return
    }

    & git add -- @cleanPaths
}

function Test-BlockingReviewOutput {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        return $false
    }

    $text = Get-Content $Path -Raw
    return (
        $text -match "(?im)^\s*REVIEW_STATUS:\s*BLOCKED\b" -or
        $text -match "(?im)^\s*REVIEW_FINDING:\s*P[12]\b" -or
        $text -match "(?im)^\s*\[?P[12]\]?\s*[:\-]" -or
        $text -match "::code-comment\{[^}]*priority=(1|2)\b"
    )
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

function Get-FirstUncheckedTask {
    foreach ($line in Get-Content "docs/codex/TASK_QUEUE.md" -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*-\s+\[ \]\s+(.+)$") {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Mark-FirstUncheckedTaskComplete {
    $path = "docs/codex/TASK_QUEUE.md"
    $updated = $false
    $newLines = foreach ($line in Get-Content $path) {
        if (-not $updated -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $updated = $true
            "$($Matches[1])[x]$($Matches[2])"
        } else {
            $line
        }
    }
    Set-Content $path $newLines
}

function Append-Report {
    param([string]$Task, [string[]]$FilesChanged, [string]$BuildResult, [string]$Risk)
    if (!(Test-Path "docs/codex/NIGHTLY_REPORT.md")) {
        New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
        "# Codex Nightly Report`n" | Set-Content "docs/codex/NIGHTLY_REPORT.md"
    }

    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $files = if ($FilesChanged.Count -gt 0) { ($FilesChanged | ForEach-Object { "- $_" }) -join "`n" } else { "- None" }
    Add-Content "docs/codex/NIGHTLY_REPORT.md" @"

## $date

- Task attempted: $Task
- Build result: $BuildResult
- Files changed:
$files
- Risks or follow-up needed: $Risk
"@
}

function Invoke-CodexExec {
    param(
        [string]$Prompt,
        [string]$LogPath,
        [string]$Model = "",
        [string]$ResponsePath = ""
    )

    for ($attempt = 1; $attempt -le $MaxCodexAttempts; $attempt++) {
        Write-Host "Starting Codex run attempt $attempt of $MaxCodexAttempts" -ForegroundColor DarkCyan
        $attemptLog = if ($attempt -eq 1) { $LogPath } else { $LogPath -replace "\.log$", "-attempt-$attempt.log" }
        $codexArgs = @("exec", "--full-auto")
        if (![string]::IsNullOrWhiteSpace($Model)) {
            $codexArgs += @("-m", $Model)
        }
        if (![string]::IsNullOrWhiteSpace($ResponsePath)) {
            $codexArgs += @("-o", $ResponsePath)
        }
        $codexArgs += "-"
        $Prompt | & codex @codexArgs 2>&1 | Tee-Object -FilePath $attemptLog
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) { return 0 }

        $statusText = (git status --porcelain) -join "`n"
        if (![string]::IsNullOrWhiteSpace($statusText)) {
            Write-Host "Codex exited nonzero after making changes; continuing to checks." -ForegroundColor Yellow
            return $exitCode
        }

        $sleepSeconds = [Math]::Min(300, 30 * $attempt)
        Write-Host "Codex failed with no repo changes. Waiting $sleepSeconds seconds before retry." -ForegroundColor Yellow
        Start-Sleep -Seconds $sleepSeconds
    }

    return 1
}

function Invoke-ExternalBuild {
    $buildCommand = Get-ConfigScalar -Name "buildCommand" -Default ""
    if ([string]::IsNullOrWhiteSpace($buildCommand)) {
        return $true
    }

    $buildDir = Get-ConfigScalar -Name "buildDirectory" -Default "."
    Push-Location $buildDir
    Invoke-Expression $buildCommand
    $ok = $LASTEXITCODE -eq 0
    Pop-Location
    return $ok
}

function Invoke-ProjectGuardrails {
    param([string]$Task, [string]$Stage)
    if (!(Test-Path "scripts/codex-guardrails.ps1")) {
        return $true
    }
    $previousTask = $env:CODEX_SELECTED_TASK
    $env:CODEX_SELECTED_TASK = $Task
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\codex-guardrails.ps1" -Stage $Stage
    $passed = $LASTEXITCODE -eq 0
    $env:CODEX_SELECTED_TASK = $previousTask
    return $passed
}

function Import-NextTasks {
    param([string]$Path)
    $tasks = @(Get-Content $Path | Where-Object { $_ -match "^\s*-\s+\[ \]\s+.+" })
    if ($tasks.Count -eq 0) {
        Write-Host "No valid tasks found in $Path" -ForegroundColor Red
        return $false
    }
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
        "# Codex Task Queue`n`n## Tasks`n" | Set-Content "docs/codex/TASK_QUEUE.md"
    }
    Add-Content "docs/codex/TASK_QUEUE.md" "`n## Checkpoint Planner Tasks $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $tasks | Select-Object -First $BatchSize | ForEach-Object { Add-Content "docs/codex/TASK_QUEUE.md" $_ }
    return $true
}

function Ensure-LogExclude {
    if (!(Test-Path ".git\info\exclude")) {
        New-Item -ItemType File -Path ".git\info\exclude" -Force | Out-Null
    }

    $excludeText = Get-Content ".git\info\exclude" -Raw
    if ($excludeText -notmatch "\.codex-logs/") {
        Add-Content ".git\info\exclude" "`n.codex-logs/"
    }
}

$script:projectConfig = Get-ProjectConfig
$repoMatches = @(Resolve-Path $script:projectConfig.repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Write-Host "Repo not found: $($script:projectConfig.repo)" -ForegroundColor Red
    exit 1
}
$repoPath = $repoMatches[0].Path

$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:profileConfig = $null
$profileName = Get-ConfigPropertyValue -Object $script:projectConfig -Name "profile"
if (![string]::IsNullOrWhiteSpace([string]$profileName)) {
    $profilePath = Join-Path $fleetRoot "profiles\$profileName.json"
    if (Test-Path $profilePath) {
        $script:profileConfig = Get-Content $profilePath -Raw | ConvertFrom-Json
    } else {
        Write-Host "Project profile not found: $profilePath" -ForegroundColor Red
        exit 1
    }
}
Set-Location $repoPath
Ensure-LogExclude

if ($ValidateOnly) {
    Write-Host "Project resolved successfully." -ForegroundColor Green
    Write-Host "Project: $($script:projectConfig.name)"
    Write-Host "Repo: $repoPath"
    $validateProfile = Get-ConfigScalar -Name "profile" -Default "none"
    $validateBuildDirectory = Get-ConfigScalar -Name "buildDirectory" -Default "."
    $validateBuildCommand = Get-ConfigScalar -Name "buildCommand" -Default ""
    Write-Host "Profile: $validateProfile"
    Write-Host "Build directory: $validateBuildDirectory"
    Write-Host "Build command: $validateBuildCommand"
    exit 0
}

$status = @(git status --porcelain)
if ($status.Count -gt 0) {
    Write-Host "Repo is dirty. Commit, restore, or stash before starting checkpoint loop." -ForegroundColor Red
    git status
    exit 1
}

$branch = git branch --show-current
if ($branch -eq $BaseBranch) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeProject = if ([string]::IsNullOrWhiteSpace($script:projectConfig.name)) { "project" } else { ([string]$script:projectConfig.name) -replace "[^a-zA-Z0-9_-]+", "-" }
    $safeProject = $safeProject.Trim("-")
    $branchPrefix = Get-ConfigScalar -Name "branchPrefix" -Default "codex/mission"
    $branch = "$branchPrefix-$safeProject-$timestamp"
    git checkout -b $branch
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Host "Continuing on existing branch $branch" -ForegroundColor Cyan
}

$logRoot = ".codex-logs\checkpoint-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

for ($batch = 1; $batch -le $MaxBatches; $batch++) {
    Write-Host ""
    Write-Host "===== CHECKPOINT BATCH $batch of $MaxBatches =====" -ForegroundColor Cyan

    $task = Get-FirstUncheckedTask
    if ([string]::IsNullOrWhiteSpace($task)) {
        Write-Host "No unchecked tasks. Generating next $BatchSize from mission." -ForegroundColor Cyan
        $plannerArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "generate-next-five.ps1"),
            "-Repo", $repoPath,
            "-BaseBranch", $BaseBranch,
            "-Count", $BatchSize
        )
        $plannerModel = Get-ProjectModel -Role "planner"
        if (![string]::IsNullOrWhiteSpace($plannerModel)) {
            $plannerArgs += @("-Model", $plannerModel)
        }
        powershell @plannerArgs
        if ($LASTEXITCODE -ne 0) { exit 1 }
        if (-not (Import-NextTasks -Path "docs/codex/NEXT_5_TASKS.md")) { exit 1 }
        Stage-Files -Paths @("docs/codex/TASK_QUEUE.md", "docs/codex/NEXT_5_TASKS.md")
        git commit -m "Codex checkpoint planner tasks batch $batch"
    }

    for ($i = 1; $i -le $BatchSize; $i++) {
        $task = Get-FirstUncheckedTask
        if ([string]::IsNullOrWhiteSpace($task)) { break }

        Write-Host ""
        Write-Host "----- TASK $i of $BatchSize -----" -ForegroundColor Cyan
        Write-Host "Selected task: $task" -ForegroundColor Cyan

        $prompt = @"
Read docs/codex/MISSION.md if present, docs/codex/RUN_POLICY.md if present, and docs/codex/TASK_QUEUE.md.

Implement only this selected task:
$task

Rules:
1. Make a small reviewable change.
2. Do not run build commands.
3. Do not mark tasks complete.
4. Do not edit NIGHTLY_REPORT.md.
5. Do not merge, push to main, or deploy.
6. Obey the project guardrails and forbidden scope.
"@

        $log1 = Join-Path $logRoot "batch-$batch-task-$i-implement.log"
        $exit = Invoke-CodexExec -Prompt $prompt -LogPath $log1 -Model (Get-ProjectModel -Role "implement")
        $statusAfter = @(git status --porcelain)
        if ($exit -ne 0 -and $statusAfter.Count -eq 0) {
            Append-Report -Task $task -FilesChanged @() -BuildResult "Failed" -Risk "Codex command failed after retries and made no changes."
            exit 1
        }
        if ($statusAfter.Count -eq 0) {
            Append-Report -Task $task -FilesChanged @() -BuildResult "Skipped" -Risk "Codex made no changes."
            exit 1
        }

        if (-not (Invoke-ProjectGuardrails -Task $task -Stage "implementation")) { exit 1 }
        if (-not (Invoke-ExternalBuild)) {
            Append-Report -Task $task -FilesChanged @(git diff --name-only; git ls-files --others --exclude-standard) -BuildResult "Failed" -Risk "External build failed."
            exit 1
        }

        $reviewPrompt = @"
Review the current git diff for only this selected task:
$task

Fix only clear issues caused by this task.
Do not broaden scope.
Do not run build commands.
Do not mark tasks complete.
Do not edit NIGHTLY_REPORT.md.

After fixing clear issues, end your response with exactly one of these machine-readable status lines:
REVIEW_STATUS: PASS
REVIEW_STATUS: BLOCKED

Use REVIEW_STATUS: BLOCKED only when a P1/P2 issue remains unresolved after your fixes, and include one line like:
REVIEW_FINDING: P1: short description
or
REVIEW_FINDING: P2: short description
"@
        $log2 = Join-Path $logRoot "batch-$batch-task-$i-review.log"
        $reviewResponse = Join-Path $logRoot "batch-$batch-task-$i-review-response.md"
        [void](Invoke-CodexExec -Prompt $reviewPrompt -LogPath $log2 -Model (Get-ProjectModel -Role "review") -ResponsePath $reviewResponse)

        if (Test-BlockingReviewOutput -Path $reviewResponse) {
            Append-Report -Task $task -FilesChanged @(git diff --name-only; git ls-files --others --exclude-standard) -BuildResult "Blocked" -Risk "Review reported an unresolved P1/P2 finding."
            Write-Host "Review reported an unresolved P1/P2 finding. Ending loop without marking task complete." -ForegroundColor Red
            exit 1
        }

        if (-not (Invoke-ProjectGuardrails -Task $task -Stage "review")) { exit 1 }
        if (-not (Invoke-ExternalBuild)) {
            Append-Report -Task $task -FilesChanged @(git diff --name-only; git ls-files --others --exclude-standard) -BuildResult "Failed" -Risk "Final external build failed."
            exit 1
        }

        $filesChanged = @(git diff --name-only; git ls-files --others --exclude-standard) | Sort-Object -Unique
        Mark-FirstUncheckedTaskComplete
        Append-Report -Task $task -FilesChanged $filesChanged -BuildResult "Passed" -Risk "Low. External build passed and checkpoint loop review completed."
        Stage-Files -Paths @($filesChanged + @("docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md"))
        git commit -m "Codex checkpoint batch $batch task $i"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    $checkpointArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "checkpoint-review.ps1"),
        "-Repo", $repoPath,
        "-BaseBranch", $BaseBranch,
        "-BuildDirectory", (Get-ConfigScalar -Name "buildDirectory" -Default "."),
        "-BuildCommand", (Get-ConfigScalar -Name "buildCommand" -Default "")
    )
    $checkpointModel = Get-ProjectModel -Role "checkpoint"
    if (![string]::IsNullOrWhiteSpace($checkpointModel)) {
        $checkpointArgs += @("-Model", $checkpointModel)
    }
    powershell @checkpointArgs
    if ($LASTEXITCODE -ne 0) { exit 1 }

    $checkpointText = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "" }
    Stage-Files -Paths @("docs/codex/CHECKPOINT_REVIEW.md")
    $pendingCheckpointCommit = @(git diff --cached --name-only)
    if ($pendingCheckpointCommit.Count -gt 0) {
        git commit -m "Codex checkpoint review batch $batch"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    if ($checkpointText -match "(?is)## Verdict\s+RED\b" -or $checkpointText -match "(?i)stop for human review") {
        Write-Host "Checkpoint review requested a human stop. Ending loop without merge." -ForegroundColor Yellow
        break
    }

    if ($VisualEvery -gt 0 -and ($batch % $VisualEvery -eq 0)) {
        $serveDir = Get-ConfigScalar -Name "buildDirectory" -Default "."
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "visual-smoke.ps1") -Repo $repoPath -Project $script:projectConfig.name -ServeDirectory $serveDir -Port (Get-FreeTcpPort) -ChromePort (Get-FreeTcpPort)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Visual smoke failed. Ending loop without merge." -ForegroundColor Red
            exit 1
        }
    }

    if ($VisualInspectEvery -gt 0 -and ($batch % $VisualInspectEvery -eq 0)) {
        $serveDir = Get-ConfigScalar -Name "buildDirectory" -Default "."
        $visualPaths = Get-ConfigArray -Name "visualPaths"
        if ($visualPaths.Count -eq 0) {
            $visualPaths = @("/")
        }
        $visualArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "visual-inspect.ps1"),
            "-Repo", $repoPath,
            "-Project", $script:projectConfig.name,
            "-ServeDirectory", $serveDir,
            "-Port", (Get-FreeTcpPort),
            "-ChromePort", (Get-FreeTcpPort),
            "-Paths"
        ) + $visualPaths
        powershell @visualArgs
        $visualInspectPassed = $LASTEXITCODE -eq 0
        Stage-Files -Paths @("docs/codex/VISUAL_BUGS.md")
        $pendingVisualCommit = @(git diff --cached --name-only)
        if ($pendingVisualCommit.Count -gt 0) {
            git commit -m "Codex visual inspect batch $batch"
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        if (-not $visualInspectPassed) {
            Write-Host "Visual inspect found blocking issues. Ending loop without merge." -ForegroundColor Red
            exit 1
        }
    }

    if ($SimonEvery -gt 0 -and ($batch % $SimonEvery -eq 0)) {
        $simonArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "simon-design-review.ps1"),
            "-Repo", $repoPath,
            "-Project", $script:projectConfig.name,
            "-BaseBranch", $BaseBranch
        )
        $simonModel = Get-ProjectModel -Role "simon"
        if (![string]::IsNullOrWhiteSpace($simonModel)) {
            $simonArgs += @("-Model", $simonModel)
        }
        powershell @simonArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Simon design review failed. Ending loop without merge." -ForegroundColor Red
            exit 1
        }
        $simonText = if (Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md") { Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw } else { "" }
        Stage-Files -Paths @("docs/codex/SIMON_DESIGN_REVIEW.md")
        $pendingSimonCommit = @(git diff --cached --name-only)
        if ($pendingSimonCommit.Count -gt 0) {
            git commit -m "Codex Simon design review batch $batch"
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        if ($simonText -match "(?is)## Verdict\s+RED\b" -or $simonText -match "(?i)stop for human design review") {
            Write-Host "Simon requested a human design stop. Ending loop without merge." -ForegroundColor Yellow
            break
        }
    }

    if ($JoeyEvery -gt 0 -and ($batch % $JoeyEvery -eq 0)) {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "joey-security-review.ps1") -Repo $repoPath -Project $script:projectConfig.name -BaseBranch $BaseBranch
        $joeyPassed = $LASTEXITCODE -eq 0
        $joeyText = if (Test-Path "docs/codex/JOEY_SECURITY_REVIEW.md") { Get-Content "docs/codex/JOEY_SECURITY_REVIEW.md" -Raw } else { "" }
        Stage-Files -Paths @("docs/codex/JOEY_SECURITY_REVIEW.md")
        $pendingJoeyCommit = @(git diff --cached --name-only)
        if ($pendingJoeyCommit.Count -gt 0) {
            git commit -m "Codex Joey security review batch $batch"
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        if (-not $joeyPassed -or $joeyText -match "(?is)## Verdict\s+RED\b" -or $joeyText -match "(?i)stop for human security review") {
            Write-Host "Joey requested a human security stop. Ending loop without merge." -ForegroundColor Red
            exit 1
        }
    }

    if (!$SkipDebug) {
        $debugArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "debug-checkpoint.ps1"),
            "-Repo", $repoPath,
            "-BaseBranch", $BaseBranch
        )
        $maxChangedFiles = Get-ConfigScalar -Name "maxChangedFiles" -Default ""
        if (![string]::IsNullOrWhiteSpace($maxChangedFiles)) {
            $debugArgs += @("-MaxChangedFiles", [int]$maxChangedFiles)
        }
        if ($ContinueOnYellowCheckpoint) {
            $debugArgs += "-AllowYellowCheckpoint"
        }
        powershell @debugArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Checkpoint debugger failed. Ending loop without merge." -ForegroundColor Red
            exit 1
        }
    }

    if ($PushCheckpoint) {
        $originUrl = git remote get-url origin 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originUrl)) {
            Write-Host "Push checkpoint requested, but no origin remote is configured. Skipping push." -ForegroundColor Yellow
        } else {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
    }
}

Write-Host ""
Write-Host "Checkpoint loop finished on branch $branch" -ForegroundColor Green
Write-Host "No merge was performed."
