[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project,

    [string]$Repo,

    [string]$ConfigPath = ".\projects.json",

    [string]$BaseBranch = "main",

    [int]$BatchSize = 5,

    [int]$MaxBatches = 1,

    [int]$MaxCodexAttempts = 4,

    [int]$CodexTimeoutSeconds = 1800,

    [int]$BuildTimeoutSeconds = 600,

    [int]$PlannerTimeoutSeconds = 600,

    [int]$CheckpointTimeoutSeconds = 600,

    [int]$SimonTimeoutSeconds = 600,

    [int]$VisualTimeoutSeconds = 900,

    [int]$JoeyTimeoutSeconds = 300,

    [int]$DebugTimeoutSeconds = 300,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 4,

    [int]$MaxTaskQuarantines = 3,

    [int]$VisualEvery = 0,

    [int]$VisualInspectEvery = 0,

    [int]$SimonEvery = 0,

    [int]$JoeyEvery = 0,

    [switch]$PushCheckpoint,

    [switch]$SkipDebug,

    [switch]$ContinueOnYellowCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowDuplicateRun,

    [switch]$ValidateOnly,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (!(Test-Path $fleetRuntime)) {
    Write-Host "Fleet runtime helper not found: $fleetRuntime" -ForegroundColor Red
    exit 1
}
. $fleetRuntime

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

if ($RateLimitCooldownSeconds -lt 60) {
    Stop-Usage "-RateLimitCooldownSeconds must be at least 60."
}

if ($RateLimitMaxCooldowns -lt 0) {
    Stop-Usage "-RateLimitMaxCooldowns must be 0 or greater."
}

if ($MaxTaskQuarantines -lt 0) {
    Stop-Usage "-MaxTaskQuarantines must be 0 or greater."
}

foreach ($timeoutSpec in @(
    @{ name = "CodexTimeoutSeconds"; value = $CodexTimeoutSeconds },
    @{ name = "BuildTimeoutSeconds"; value = $BuildTimeoutSeconds },
    @{ name = "PlannerTimeoutSeconds"; value = $PlannerTimeoutSeconds },
    @{ name = "CheckpointTimeoutSeconds"; value = $CheckpointTimeoutSeconds },
    @{ name = "SimonTimeoutSeconds"; value = $SimonTimeoutSeconds },
    @{ name = "VisualTimeoutSeconds"; value = $VisualTimeoutSeconds },
    @{ name = "JoeyTimeoutSeconds"; value = $JoeyTimeoutSeconds },
    @{ name = "DebugTimeoutSeconds"; value = $DebugTimeoutSeconds }
)) {
    if ([int]$timeoutSpec.value -lt 1) {
        Stop-Usage "-$($timeoutSpec.name) must be at least 1."
    }
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

function Get-RoleModelsFrom {
    param(
        [object]$ConfigObject,
        [string]$Role
    )

    if ($null -eq $ConfigObject) { return @() }

    $results = @()

    $models = Get-ConfigPropertyValue -Object $ConfigObject -Name "models"
    if ($null -ne $models) {
        foreach ($key in @($Role, "${Role}Model")) {
            $value = Get-ConfigPropertyValue -Object $models -Name $key
            $results += ConvertTo-FleetStringArray -Value $value
        }
    }

    foreach ($key in @("${Role}Model", "model")) {
        $value = Get-ConfigPropertyValue -Object $ConfigObject -Name $key
        $results += ConvertTo-FleetStringArray -Value $value
    }

    return @($results | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
}

function Get-ProjectModels {
    param([string]$Role)

    $projectModels = @(Get-RoleModelsFrom -ConfigObject $script:projectConfig -Role $Role)
    if ($projectModels.Count -gt 0) { return $projectModels }

    $profileModels = @(Get-RoleModelsFrom -ConfigObject $script:profileConfig -Role $Role)
    if ($profileModels.Count -gt 0) { return $profileModels }

    return @()
}

function Get-TimeoutSetting {
    param(
        [string]$Role,
        [int]$Default
    )

    foreach ($source in @($script:projectConfig, $script:profileConfig)) {
        if ($null -eq $source) { continue }

        $timeouts = Get-ConfigPropertyValue -Object $source -Name "timeouts"
        if ($null -ne $timeouts) {
            $roleValue = Get-ConfigPropertyValue -Object $timeouts -Name $Role
            if ($null -ne $roleValue -and [int]$roleValue -gt 0) {
                return [int]$roleValue
            }
        }

        foreach ($key in @("${Role}TimeoutSeconds", "${Role}Timeout")) {
            $value = Get-ConfigPropertyValue -Object $source -Name $key
            if ($null -ne $value -and [int]$value -gt 0) {
                return [int]$value
            }
        }
    }

    return $Default
}

function Get-ConfigInt {
    param(
        [string]$Name,
        [int]$Default
    )

    foreach ($source in @($script:projectConfig, $script:profileConfig)) {
        if ($null -eq $source) { continue }

        $value = Get-ConfigPropertyValue -Object $source -Name $Name
        if ($null -ne $value -and [int]$value -gt 0) {
            return [int]$value
        }

        $timeouts = Get-ConfigPropertyValue -Object $source -Name "timeouts"
        if ($null -ne $timeouts) {
            $timeoutValue = Get-ConfigPropertyValue -Object $timeouts -Name $Name
            if ($null -ne $timeoutValue -and [int]$timeoutValue -gt 0) {
                return [int]$timeoutValue
            }
        }
    }

    return $Default
}

function Write-FleetOutputTail {
    param(
        [object]$Result,
        [int]$LineCount = 80
    )

    if ($null -eq $Result -or $null -eq $Result.output) {
        return
    }

    @($Result.output | Select-Object -Last $LineCount) | ForEach-Object { Write-Host $_ }
}

function Invoke-FleetPowerShell {
    param(
        [string[]]$Arguments,
        [string]$LogName,
        [int]$TimeoutSeconds,
        [string]$WorkingDirectory = $repoPath,
        [hashtable]$Environment = @{}
    )

    $logPath = Join-Path $script:RunLogRoot $LogName
    $result = Invoke-FleetProcess -FilePath "powershell" -Arguments $Arguments -WorkingDirectory $WorkingDirectory -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -Environment $Environment
    Write-FleetOutputTail -Result $result
    if ($result.timedOut) {
        Write-Host "Fleet watchdog stopped timed-out process after $TimeoutSeconds seconds. Zoro cut the rope clean." -ForegroundColor Red
    }
    return $result.exitCode
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

    return (Test-FleetBlockingReviewOutput -Path $Path)
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

function Mark-FirstUncheckedTaskQuarantined {
    $path = "docs/codex/TASK_QUEUE.md"
    $updated = $false
    $newLines = foreach ($line in Get-Content $path) {
        if (-not $updated -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $updated = $true
            "$($Matches[1])[!]$($Matches[2])"
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

function Append-QuarantineReport {
    param(
        [string]$Task,
        [string]$Reason,
        [int]$Batch,
        [int]$TaskIndex,
        [string[]]$FilesChanged
    )

    if (!(Test-Path "docs/codex/QUARANTINED_TASKS.md")) {
        New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
        "# Quarantined Fleet Tasks`n" | Set-Content "docs/codex/QUARANTINED_TASKS.md"
    }

    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $files = if ($FilesChanged.Count -gt 0) { ($FilesChanged | ForEach-Object { "- $_" }) -join "`n" } else { "- None" }
    Add-Content "docs/codex/QUARANTINED_TASKS.md" @"

## $date

- Batch: $Batch
- Task index: $TaskIndex
- Task: $Task
- Reason: $Reason
- Files restored before continuing:
$files
- Next step: Nami should avoid repeating this exact task until a human reviews the failure.
"@
}

function Get-TaskChangedFiles {
    $changed = @(
        @(git diff --name-only)
        @(git diff --cached --name-only)
        @(git ls-files --others --exclude-standard)
    )
    return @($changed | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
}

function Restore-TaskChanges {
    param([string]$TaskBase)

    if ([string]::IsNullOrWhiteSpace($TaskBase)) {
        return $false
    }

    $repoFullPath = [System.IO.Path]::GetFullPath($repoPath)
    $stagedPaths = @(git diff --cached --name-only) | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique

    if ($stagedPaths.Count -gt 0) {
        & git restore --staged -- @stagedPaths
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    $worktreePaths = @(git diff --name-only) | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique
    if ($worktreePaths.Count -gt 0) {
        & git restore --worktree -- @worktreePaths
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    $untrackedPaths = @(git ls-files --others --exclude-standard)
    foreach ($path in $untrackedPaths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $target = [System.IO.Path]::GetFullPath((Join-Path $repoFullPath $path))
        if (!$target.StartsWith($repoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Refusing to remove untracked path outside repo: $path" -ForegroundColor Red
            return $false
        }
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        }
    }

    $remaining = @(git status --porcelain)
    return ($remaining.Count -eq 0)
}

function Invoke-TaskQuarantine {
    param(
        [string]$Task,
        [string]$Reason,
        [int]$Batch,
        [int]$TaskIndex,
        [string]$TaskBase
    )

    if (!$QuarantineFailedTasks) {
        return $false
    }

    if ($script:TaskQuarantineCount -ge $MaxTaskQuarantines) {
        Write-Host "Task quarantine limit reached ($MaxTaskQuarantines). Ending loop for human review." -ForegroundColor Red
        return $false
    }

    $script:TaskQuarantineCount++
    $filesChanged = @(Get-TaskChangedFiles)
    Write-Host "Quarantining failed task $script:TaskQuarantineCount of $MaxTaskQuarantines, restoring task changes, and continuing." -ForegroundColor Yellow

    if (-not (Restore-TaskChanges -TaskBase $TaskBase)) {
        Write-Host "Could not restore task changes cleanly. Ending loop for human review." -ForegroundColor Red
        return $false
    }

    Mark-FirstUncheckedTaskQuarantined
    Append-Report -Task $Task -FilesChanged $filesChanged -BuildResult "Quarantined" -Risk $Reason
    Append-QuarantineReport -Task $Task -Reason $Reason -Batch $Batch -TaskIndex $TaskIndex -FilesChanged $filesChanged

    Stage-Files -Paths @("docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md", "docs/codex/QUARANTINED_TASKS.md")
    $pendingQuarantineCommit = @(git diff --cached --name-only)
    if ($pendingQuarantineCommit.Count -gt 0) {
        git commit -m "Codex quarantine failed task batch $Batch task $TaskIndex"
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    return $true
}

function Invoke-CodexExec {
    param(
        [string]$Prompt,
        [string]$LogPath,
        [string[]]$Models = @(),
        [string]$ResponsePath = "",
        [int]$TimeoutSeconds = $CodexTimeoutSeconds
    )

    $modelChain = @(ConvertTo-FleetStringArray -Value $Models)
    if ($modelChain.Count -eq 0) {
        $modelChain = @("")
    }

    $rateLimitCooldown = Get-ConfigInt -Name "rateLimitCooldownSeconds" -Default (Get-ConfigInt -Name "rateLimitCooldown" -Default $RateLimitCooldownSeconds)
    $rateLimitMaxCooldowns = Get-ConfigInt -Name "rateLimitMaxCooldowns" -Default $RateLimitMaxCooldowns
    $rateLimitCooldownsUsed = 0

    foreach ($model in $modelChain) {
        $modelLabel = if ([string]::IsNullOrWhiteSpace($model)) { "default" } else { $model }
        $safeModel = ($modelLabel -replace "[^a-zA-Z0-9_.-]+", "-")

        $attempt = 1
        while ($attempt -le $MaxCodexAttempts) {
            Write-Host "Starting Codex run with model $modelLabel, attempt $attempt of $MaxCodexAttempts" -ForegroundColor DarkCyan
            $attemptLog = if ($attempt -eq 1 -and $modelChain.Count -eq 1) {
                $LogPath
            } else {
                $LogPath -replace "\.log$", "-$safeModel-attempt-$attempt.log"
            }

            if (![string]::IsNullOrWhiteSpace($ResponsePath) -and (Test-Path $ResponsePath)) {
                Remove-Item $ResponsePath -Force -ErrorAction SilentlyContinue
            }

            $codexArgs = @("exec", "--full-auto")
            if (![string]::IsNullOrWhiteSpace($model)) {
                $codexArgs += @("-m", $model)
            }
            if (![string]::IsNullOrWhiteSpace($ResponsePath)) {
                $codexArgs += @("-o", $ResponsePath)
            }
            $codexArgs += "-"

            $result = Invoke-FleetProcess -FilePath "codex" -Arguments $codexArgs -InputText $Prompt -WorkingDirectory $repoPath -LogPath $attemptLog -TimeoutSeconds $TimeoutSeconds
            Write-FleetOutputTail -Result $result
            $exitCode = $result.exitCode
            if ($result.timedOut) {
                Write-Host "Codex timed out after $TimeoutSeconds seconds on model $modelLabel." -ForegroundColor Yellow
            }
            if ($exitCode -eq 0) { return 0 }

            $statusText = (git status --porcelain) -join "`n"
            if (![string]::IsNullOrWhiteSpace($statusText)) {
                Write-Host "Codex exited nonzero after making changes; continuing to checks." -ForegroundColor Yellow
                return $exitCode
            }

            if (Test-FleetRateLimitOutput -Output $result.output -and $rateLimitCooldownsUsed -lt $rateLimitMaxCooldowns) {
                $rateLimitCooldownsUsed++
                $sleepSeconds = Get-FleetRateLimitDelaySeconds -Output $result.output -DefaultSeconds $rateLimitCooldown
                Write-Host "Codex appears rate-limited. Waiting $sleepSeconds seconds before retry $rateLimitCooldownsUsed of $rateLimitMaxCooldowns. This does not count as a normal attempt." -ForegroundColor Yellow
                Start-Sleep -Seconds $sleepSeconds
                continue
            }

            $sleepSeconds = [Math]::Min(300, 30 * $attempt)
            Write-Host "Codex failed with no repo changes. Waiting $sleepSeconds seconds before retry." -ForegroundColor Yellow
            Start-Sleep -Seconds $sleepSeconds
            $attempt++
        }

        if ($model -ne $modelChain[-1]) {
            Write-Host "Model $modelLabel did not produce changes. Trying next configured model." -ForegroundColor Yellow
        }
    }

    return 1
}

function Invoke-ExternalBuild {
    $buildCommand = Get-ConfigScalar -Name "buildCommand" -Default ""
    if ([string]::IsNullOrWhiteSpace($buildCommand)) {
        return $true
    }

    $buildDir = Get-ConfigScalar -Name "buildDirectory" -Default "."
    $buildPath = Resolve-Path $buildDir -ErrorAction SilentlyContinue
    if (!$buildPath) {
        Write-Host "Build directory not found: $buildDir" -ForegroundColor Red
        return $false
    }

    $buildTimeout = Get-TimeoutSetting -Role "build" -Default $BuildTimeoutSeconds
    $buildLog = Join-Path $script:RunLogRoot ("build-{0}.log" -f (Get-Date -Format "HHmmssfff"))
    $result = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $buildCommand) -WorkingDirectory $buildPath.Path -LogPath $buildLog -TimeoutSeconds $buildTimeout
    Write-FleetOutputTail -Result $result
    if ($result.timedOut) {
        Write-Host "Build timed out after $buildTimeout seconds." -ForegroundColor Red
    }
    return ($result.exitCode -eq 0)
}

function Invoke-ProjectGuardrails {
    param([string]$Task, [string]$Stage)
    if (!(Test-Path "scripts/codex-guardrails.ps1")) {
        return $true
    }
    $guardrailTimeout = Get-TimeoutSetting -Role "guardrails" -Default 120
    $exitCode = Invoke-FleetPowerShell -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ".\scripts\codex-guardrails.ps1",
        "-Stage", $Stage
    ) -LogName ("guardrails-{0}-{1}.log" -f $Stage, (Get-Date -Format "HHmmssfff")) -TimeoutSeconds $guardrailTimeout -Environment @{ CODEX_SELECTED_TASK = $Task }
    return ($exitCode -eq 0)
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

function Invoke-CheckpointReviewGate {
    param([int]$Batch)

    $checkpointArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "checkpoint-review.ps1"),
        "-Repo", $repoPath,
        "-BaseBranch", $BaseBranch,
        "-BuildDirectory", (Get-ConfigScalar -Name "buildDirectory" -Default "."),
        "-BuildCommand", (Get-ConfigScalar -Name "buildCommand" -Default "")
    )
    $checkpointModels = @(Get-ProjectModels -Role "checkpoint")
    if ($checkpointModels.Count -gt 0) {
        $checkpointArgs = @(Add-FleetArrayArgument -Arguments $checkpointArgs -Name "-Models" -Values $checkpointModels)
    }
    $checkpointTimeout = Get-TimeoutSetting -Role "checkpoint" -Default $CheckpointTimeoutSeconds
    $checkpointBuildTimeout = Get-TimeoutSetting -Role "build" -Default $BuildTimeoutSeconds
    $checkpointRateLimitCooldown = Get-ConfigInt -Name "rateLimitCooldownSeconds" -Default (Get-ConfigInt -Name "rateLimitCooldown" -Default $RateLimitCooldownSeconds)
    $checkpointRateLimitMaxCooldowns = Get-ConfigInt -Name "rateLimitMaxCooldowns" -Default $RateLimitMaxCooldowns
    $checkpointArgs += @(
        "-TimeoutSeconds", $checkpointTimeout,
        "-BuildTimeoutSeconds", $checkpointBuildTimeout,
        "-RateLimitCooldownSeconds", $checkpointRateLimitCooldown,
        "-RateLimitMaxCooldowns", $checkpointRateLimitMaxCooldowns
    )
    $checkpointExit = Invoke-FleetPowerShell -Arguments $checkpointArgs -LogName "checkpoint-review-batch-$Batch.log" -TimeoutSeconds ($checkpointTimeout + $checkpointBuildTimeout + ($checkpointRateLimitCooldown * $checkpointRateLimitMaxCooldowns) + 120)
    if ($checkpointExit -ne 0) { exit 1 }

    $checkpointText = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "" }
    Stage-Files -Paths @("docs/codex/CHECKPOINT_REVIEW.md")
    $pendingCheckpointCommit = @(git diff --cached --name-only)
    if ($pendingCheckpointCommit.Count -gt 0) {
        git commit -m "Codex checkpoint review batch $Batch"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    return $checkpointText
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

function Get-FleetRunLockPath {
    param(
        [string]$ProjectName,
        [string]$RepoFullPath
    )

    $lockRoot = Join-Path $fleetRoot ".codex-local\locks"
    New-Item -ItemType Directory -Force -Path $lockRoot | Out-Null
    $safeName = if ([string]::IsNullOrWhiteSpace($ProjectName)) { Split-Path -Leaf $RepoFullPath } else { $ProjectName }
    $safeName = ([string]$safeName) -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeName = $safeName.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = "project"
    }
    return Join-Path $lockRoot "$safeName.lock.json"
}

function Test-FleetProcessAlive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) {
        return $false
    }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    return ($null -ne $process)
}

function Get-ExistingFleetRunProcesses {
    param(
        [string]$ProjectName,
        [string]$RepoFullPath
    )

    $needles = @()
    if (![string]::IsNullOrWhiteSpace($ProjectName)) {
        $needles += [string]$ProjectName
    }
    if (![string]::IsNullOrWhiteSpace($RepoFullPath)) {
        $needles += [string]$RepoFullPath
    }

    if ($needles.Count -eq 0) {
        return @()
    }

    try {
        return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $isMatch = $true
            if ([int]$_.ProcessId -eq [int]$PID) { $isMatch = $false }
            $commandLine = [string]$_.CommandLine
            if ([string]::IsNullOrWhiteSpace($commandLine)) { $isMatch = $false }
            if ($isMatch -and $commandLine.IndexOf("run-checkpoint-loop.ps1", [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { $isMatch = $false }

            if ($isMatch) {
                $containsProjectOrRepo = $false
                foreach ($needle in $needles) {
                    if ([string]::IsNullOrWhiteSpace($needle)) { continue }
                    if ($commandLine.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $containsProjectOrRepo = $true
                        break
                    }
                }
                $isMatch = $containsProjectOrRepo
            }
            $isMatch
        })
    } catch {
        return @()
    }
}

function Assert-NoDuplicateFleetRun {
    param(
        [string]$ProjectName,
        [string]$RepoFullPath
    )

    $existingProcesses = @(Get-ExistingFleetRunProcesses -ProjectName $ProjectName -RepoFullPath $RepoFullPath)
    if ($existingProcesses.Count -gt 0) {
        Write-Host "Duplicate fleet run refused for $ProjectName." -ForegroundColor Red
        Write-Host "Another run-checkpoint-loop process appears active for this ship:" -ForegroundColor Yellow
        $existingProcesses | Select-Object -First 5 | ForEach-Object {
            Write-Host ("- PID {0}: {1}" -f $_.ProcessId, $_.CommandLine) -ForegroundColor Yellow
        }
        Write-Host "Wait for that window to finish, or pass -AllowDuplicateRun if you are intentionally doing something risky." -ForegroundColor Yellow
        exit 1
    }
}

function Acquire-FleetRunLock {
    param(
        [string]$ProjectName,
        [string]$RepoFullPath
    )

    $lockPath = Get-FleetRunLockPath -ProjectName $ProjectName -RepoFullPath $RepoFullPath
    $lockInfo = [pscustomobject]@{
        project = $ProjectName
        repo = $RepoFullPath
        pid = $PID
        startedAt = (Get-Date).ToString("o")
        command = $MyInvocation.Line
    }

    if (Test-Path $lockPath) {
        $existing = $null
        try {
            $existing = Get-Content $lockPath -Raw | ConvertFrom-Json
        } catch {
            $existing = $null
        }

        $existingPid = if ($null -ne $existing -and $null -ne $existing.pid) { [int]$existing.pid } else { 0 }
        if (Test-FleetProcessAlive -ProcessId $existingPid) {
            Write-Host "Duplicate fleet run refused for $ProjectName." -ForegroundColor Red
            Write-Host "Active lock: $lockPath" -ForegroundColor Yellow
            Write-Host "Lock owner PID: $existingPid" -ForegroundColor Yellow
            Write-Host "Wait for that run to finish, or pass -AllowDuplicateRun if you are intentionally doing something risky." -ForegroundColor Yellow
            exit 1
        }

        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }

    $json = $lockInfo | ConvertTo-Json -Depth 4
    try {
        $stream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Dispose()
        }
    } catch {
        Write-Host "Could not acquire fleet run lock for $ProjectName at $lockPath." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Fleet run lock acquired: $lockPath" -ForegroundColor DarkCyan
    $script:FleetRunLockPath = $lockPath
}

$script:projectConfig = Get-ProjectConfig
$repoMatches = @(Resolve-Path $script:projectConfig.repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Write-Host "Repo not found: $($script:projectConfig.repo)" -ForegroundColor Red
    exit 1
}
$repoPath = $repoMatches[0].Path

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
    Write-Host "Implement models: $((Get-ProjectModels -Role "implement") -join ', ')"
    Write-Host "Review models: $((Get-ProjectModels -Role "review") -join ', ')"
    Write-Host "Planner models: $((Get-ProjectModels -Role "planner") -join ', ')"
    Write-Host "Timeouts: codex=$(Get-TimeoutSetting -Role "codex" -Default $CodexTimeoutSeconds)s build=$(Get-TimeoutSetting -Role "build" -Default $BuildTimeoutSeconds)s planner=$(Get-TimeoutSetting -Role "planner" -Default $PlannerTimeoutSeconds)s visual=$(Get-TimeoutSetting -Role "visual" -Default $VisualTimeoutSeconds)s"
    Write-Host "Rate-limit cooldown: $(Get-ConfigInt -Name "rateLimitCooldownSeconds" -Default (Get-ConfigInt -Name "rateLimitCooldown" -Default $RateLimitCooldownSeconds))s, max cooldowns $(Get-ConfigInt -Name "rateLimitMaxCooldowns" -Default $RateLimitMaxCooldowns)"
    $validateVisualPaths = @(Get-ConfigArray -Name "visualPaths")
    Write-Host "Visual paths: $(if ($validateVisualPaths.Count -gt 0) { $validateVisualPaths -join ', ' } else { 'none' })"
    exit 0
}

if (!$AllowDuplicateRun) {
    Assert-NoDuplicateFleetRun -ProjectName $script:projectConfig.name -RepoFullPath $repoPath
    Acquire-FleetRunLock -ProjectName $script:projectConfig.name -RepoFullPath $repoPath
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
$script:RunLogRoot = $logRoot
$script:TaskQuarantineCount = 0

for ($batch = 1; $batch -le $MaxBatches; $batch++) {
    Write-Host ""
    Write-Host "===== CHECKPOINT BATCH $batch of $MaxBatches =====" -ForegroundColor Cyan

    $batchBase = (git rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($batchBase)) {
        Write-Host "Could not determine batch base commit before starting checkpoint batch." -ForegroundColor Red
        exit 1
    }

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
        $plannerModels = @(Get-ProjectModels -Role "planner")
        if ($plannerModels.Count -gt 0) {
            $plannerArgs = @(Add-FleetArrayArgument -Arguments $plannerArgs -Name "-Models" -Values $plannerModels)
        }
        $plannerTimeout = Get-TimeoutSetting -Role "planner" -Default $PlannerTimeoutSeconds
        $plannerRateLimitCooldown = Get-ConfigInt -Name "rateLimitCooldownSeconds" -Default (Get-ConfigInt -Name "rateLimitCooldown" -Default $RateLimitCooldownSeconds)
        $plannerRateLimitMaxCooldowns = Get-ConfigInt -Name "rateLimitMaxCooldowns" -Default $RateLimitMaxCooldowns
        $plannerArgs += @(
            "-TimeoutSeconds", $plannerTimeout,
            "-RateLimitCooldownSeconds", $plannerRateLimitCooldown,
            "-RateLimitMaxCooldowns", $plannerRateLimitMaxCooldowns
        )
        $plannerExit = Invoke-FleetPowerShell -Arguments $plannerArgs -LogName "planner-batch-$batch.log" -TimeoutSeconds ($plannerTimeout + ($plannerRateLimitCooldown * $plannerRateLimitMaxCooldowns) + 120)
        if ($plannerExit -ne 0) { exit 1 }
        if (-not (Import-NextTasks -Path "docs/codex/NEXT_5_TASKS.md")) { exit 1 }
        Stage-Files -Paths @("docs/codex/TASK_QUEUE.md", "docs/codex/NEXT_5_TASKS.md")
        git commit -m "Codex checkpoint planner tasks batch $batch"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    for ($i = 1; $i -le $BatchSize; $i++) {
        $task = Get-FirstUncheckedTask
        if ([string]::IsNullOrWhiteSpace($task)) { break }

        Write-Host ""
        Write-Host "----- TASK $i of $BatchSize -----" -ForegroundColor Cyan
        Write-Host "Selected task: $task" -ForegroundColor Cyan
        $taskBase = (git rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($taskBase)) {
            Write-Host "Could not determine task base commit before implementation." -ForegroundColor Red
            exit 1
        }

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
        $exit = Invoke-CodexExec -Prompt $prompt -LogPath $log1 -Models (Get-ProjectModels -Role "implement") -TimeoutSeconds (Get-TimeoutSetting -Role "implement" -Default (Get-TimeoutSetting -Role "codex" -Default $CodexTimeoutSeconds))
        $headAfterImplement = (git rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($headAfterImplement)) {
            Write-Host "Could not determine HEAD after implementation." -ForegroundColor Red
            exit 1
        }
        if ($headAfterImplement.Trim() -ne $taskBase.Trim()) {
            Append-Report -Task $task -FilesChanged @() -BuildResult "Blocked" -Risk "Codex changed git history or committed during implementation. Stop for human review."
            Write-Host "Codex changed HEAD during implementation. Ending loop for human review instead of quarantining." -ForegroundColor Red
            exit 1
        }
        $statusAfter = @(git status --porcelain)
        if ($exit -ne 0 -and $statusAfter.Count -eq 0) {
            if (Invoke-TaskQuarantine -Task $task -Reason "Codex command failed after retries and made no changes." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            Append-Report -Task $task -FilesChanged @() -BuildResult "Failed" -Risk "Codex command failed after retries and made no changes."
            exit 1
        }
        if ($statusAfter.Count -eq 0) {
            if (Invoke-TaskQuarantine -Task $task -Reason "Codex made no changes." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            Append-Report -Task $task -FilesChanged @() -BuildResult "Skipped" -Risk "Codex made no changes."
            exit 1
        }

        if (-not (Invoke-ProjectGuardrails -Task $task -Stage "implementation")) {
            if (Invoke-TaskQuarantine -Task $task -Reason "Implementation guardrails failed." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            exit 1
        }
        if (-not (Invoke-ExternalBuild)) {
            $failedFiles = @(Get-TaskChangedFiles)
            if (Invoke-TaskQuarantine -Task $task -Reason "External build failed after implementation." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            Append-Report -Task $task -FilesChanged $failedFiles -BuildResult "Failed" -Risk "External build failed."
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
        [void](Invoke-CodexExec -Prompt $reviewPrompt -LogPath $log2 -Models (Get-ProjectModels -Role "review") -ResponsePath $reviewResponse -TimeoutSeconds (Get-TimeoutSetting -Role "review" -Default (Get-TimeoutSetting -Role "codex" -Default $CodexTimeoutSeconds)))

        if (Test-BlockingReviewOutput -Path $reviewResponse) {
            $blockedFiles = @(Get-TaskChangedFiles)
            if (Invoke-TaskQuarantine -Task $task -Reason "Review reported an unresolved P1/P2 finding." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            Append-Report -Task $task -FilesChanged $blockedFiles -BuildResult "Blocked" -Risk "Review reported an unresolved P1/P2 finding."
            Write-Host "Review reported an unresolved P1/P2 finding. Ending loop without marking task complete." -ForegroundColor Red
            exit 1
        }

        if (-not (Invoke-ProjectGuardrails -Task $task -Stage "review")) {
            if (Invoke-TaskQuarantine -Task $task -Reason "Review guardrails failed." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            exit 1
        }
        if (-not (Invoke-ExternalBuild)) {
            $finalFailedFiles = @(Get-TaskChangedFiles)
            if (Invoke-TaskQuarantine -Task $task -Reason "Final external build failed." -Batch $batch -TaskIndex $i -TaskBase $taskBase) { continue }
            Append-Report -Task $task -FilesChanged $finalFailedFiles -BuildResult "Failed" -Risk "Final external build failed."
            exit 1
        }

        $filesChanged = @(@(git diff --name-only; git ls-files --others --exclude-standard) | Sort-Object -Unique)
        Mark-FirstUncheckedTaskComplete
        Append-Report -Task $task -FilesChanged $filesChanged -BuildResult "Passed" -Risk "Low. External build passed and checkpoint loop review completed."
        Stage-Files -Paths @($filesChanged + @("docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md"))
        git commit -m "Codex checkpoint batch $batch task $i"
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    $stopAfterCheckpoint = $false
    $stopAfterCheckpointExitCode = 0
    $stopAfterCheckpointReason = ""

    if ($VisualEvery -gt 0 -and ($batch % $VisualEvery -eq 0)) {
        $serveDir = Get-ConfigScalar -Name "buildDirectory" -Default "."
        $visualSmokeArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "visual-smoke.ps1"),
            "-Repo", $repoPath,
            "-Project", $script:projectConfig.name,
            "-ServeDirectory", $serveDir,
            "-Port", (Get-FreeTcpPort),
            "-ChromePort", (Get-FreeTcpPort)
        )
        $visualSmokeExit = Invoke-FleetPowerShell -Arguments $visualSmokeArgs -LogName "visual-smoke-batch-$batch.log" -TimeoutSeconds (Get-TimeoutSetting -Role "visual" -Default $VisualTimeoutSeconds)
        if ($visualSmokeExit -ne 0) {
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
            "-ChromePort", (Get-FreeTcpPort)
        )
        $visualArgs = @(Add-FleetArrayArgument -Arguments $visualArgs -Name "-Paths" -Values $visualPaths)
        $visualInspectExit = Invoke-FleetPowerShell -Arguments $visualArgs -LogName "visual-inspect-batch-$batch.log" -TimeoutSeconds (Get-TimeoutSetting -Role "visual" -Default $VisualTimeoutSeconds)
        $visualInspectPassed = $visualInspectExit -eq 0
        Stage-Files -Paths @("docs/codex/VISUAL_BUGS.md")
        $pendingVisualCommit = @(git diff --cached --name-only)
        if ($pendingVisualCommit.Count -gt 0) {
            git commit -m "Codex visual inspect batch $batch"
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        if (-not $visualInspectPassed) {
            $stopAfterCheckpoint = $true
            $stopAfterCheckpointExitCode = 1
            $stopAfterCheckpointReason = "Visual inspect found blocking issues."
            Write-Host "Visual inspect found blocking issues. A final checkpoint will be written before stopping." -ForegroundColor Red
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
        $simonModels = @(Get-ProjectModels -Role "simon")
        if ($simonModels.Count -gt 0) {
            $simonArgs = @(Add-FleetArrayArgument -Arguments $simonArgs -Name "-Models" -Values $simonModels)
        }
        $simonTimeout = Get-TimeoutSetting -Role "simon" -Default $SimonTimeoutSeconds
        $simonRateLimitCooldown = Get-ConfigInt -Name "rateLimitCooldownSeconds" -Default (Get-ConfigInt -Name "rateLimitCooldown" -Default $RateLimitCooldownSeconds)
        $simonRateLimitMaxCooldowns = Get-ConfigInt -Name "rateLimitMaxCooldowns" -Default $RateLimitMaxCooldowns
        $simonArgs += @(
            "-TimeoutSeconds", $simonTimeout,
            "-RateLimitCooldownSeconds", $simonRateLimitCooldown,
            "-RateLimitMaxCooldowns", $simonRateLimitMaxCooldowns
        )
        $simonExit = Invoke-FleetPowerShell -Arguments $simonArgs -LogName "simon-design-review-batch-$batch.log" -TimeoutSeconds ($simonTimeout + ($simonRateLimitCooldown * $simonRateLimitMaxCooldowns) + 120)
        if ($simonExit -ne 0) {
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
            $stopAfterCheckpoint = $true
            $stopAfterCheckpointExitCode = [Math]::Max($stopAfterCheckpointExitCode, 0)
            $stopAfterCheckpointReason = "Simon requested a human design stop."
            Write-Host "Simon requested a human design stop. A final checkpoint will be written before stopping." -ForegroundColor Yellow
        }
    }

    if ($JoeyEvery -gt 0 -and ($batch % $JoeyEvery -eq 0)) {
        $joeyArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "joey-security-review.ps1"),
            "-Repo", $repoPath,
            "-Project", $script:projectConfig.name,
            "-BaseBranch", $BaseBranch
        )
        $joeyExit = Invoke-FleetPowerShell -Arguments $joeyArgs -LogName "joey-security-review-batch-$batch.log" -TimeoutSeconds (Get-TimeoutSetting -Role "joey" -Default $JoeyTimeoutSeconds)
        $joeyPassed = $joeyExit -eq 0
        $joeyText = if (Test-Path "docs/codex/JOEY_SECURITY_REVIEW.md") { Get-Content "docs/codex/JOEY_SECURITY_REVIEW.md" -Raw } else { "" }
        Stage-Files -Paths @("docs/codex/JOEY_SECURITY_REVIEW.md")
        $pendingJoeyCommit = @(git diff --cached --name-only)
        if ($pendingJoeyCommit.Count -gt 0) {
            git commit -m "Codex Joey security review batch $batch"
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        if (-not $joeyPassed -or $joeyText -match "(?is)## Verdict\s+RED\b" -or $joeyText -match "(?i)stop for human security review") {
            $stopAfterCheckpoint = $true
            $stopAfterCheckpointExitCode = 1
            $stopAfterCheckpointReason = "Joey requested a human security stop."
            Write-Host "Joey requested a human security stop. A final checkpoint will be written before stopping." -ForegroundColor Red
        }
    }

    $checkpointText = Invoke-CheckpointReviewGate -Batch $batch

    if ($stopAfterCheckpoint) {
        Write-Host "$stopAfterCheckpointReason Ending loop without merge." -ForegroundColor $(if ($stopAfterCheckpointExitCode -ne 0) { "Red" } else { "Yellow" })
        if ($stopAfterCheckpointExitCode -ne 0) {
            exit $stopAfterCheckpointExitCode
        }
        break
    }

    if ($checkpointText -match "(?is)## Verdict\s+RED\b" -or $checkpointText -match "(?i)stop for human review") {
        Write-Host "Checkpoint review requested a human stop. Ending loop without merge." -ForegroundColor Yellow
        break
    }

    if (!$SkipDebug) {
        $debugArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "debug-checkpoint.ps1"),
            "-Repo", $repoPath,
            "-BaseBranch", $BaseBranch,
            "-BatchBase", $batchBase
        )
        $maxChangedFiles = Get-ConfigScalar -Name "maxChangedFiles" -Default ""
        if (![string]::IsNullOrWhiteSpace($maxChangedFiles)) {
            $debugArgs += @("-MaxChangedFiles", [int]$maxChangedFiles)
        }
        $maxBatchChangedFiles = Get-ConfigScalar -Name "maxBatchChangedFiles" -Default $maxChangedFiles
        if (![string]::IsNullOrWhiteSpace($maxBatchChangedFiles)) {
            $debugArgs += @("-MaxBatchChangedFiles", [int]$maxBatchChangedFiles)
        }
        if ($ContinueOnYellowCheckpoint) {
            $debugArgs += "-AllowYellowCheckpoint"
        }
        $debugExit = Invoke-FleetPowerShell -Arguments $debugArgs -LogName "debug-checkpoint-batch-$batch.log" -TimeoutSeconds (Get-TimeoutSetting -Role "debug" -Default $DebugTimeoutSeconds)
        if ($debugExit -ne 0) {
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
