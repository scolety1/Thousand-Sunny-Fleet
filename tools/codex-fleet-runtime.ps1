function ConvertTo-FleetArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Join-FleetArguments {
    param([string[]]$Arguments)

    return (($Arguments | ForEach-Object { ConvertTo-FleetArgument -Value ([string]$_) }) -join " ")
}

function Stop-FleetProcessTree {
    param([int]$ProcessId)

    if ($ProcessId -le 0) {
        return
    }

    cmd.exe /c "taskkill /PID $ProcessId /T /F" | Out-Null
    $global:LASTEXITCODE = 0
}

function Invoke-FleetProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [string]$InputText = "",

        [string]$WorkingDirectory = "",

        [string]$LogPath = "",

        [int]$TimeoutSeconds = 0,

        [hashtable]$Environment = @{}
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = Join-FleetArguments -Arguments $Arguments
    if (![string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    foreach ($key in $Environment.Keys) {
        $startInfo.Environment[$key] = [string]$Environment[$key]
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    $timedOut = $false
    $started = $false
    $startError = ""
    $stdout = ""
    $stderr = ""
    $stdoutTask = $null
    $stderrTask = $null

    try {
        $started = $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (![string]::IsNullOrEmpty($InputText)) {
            $process.StandardInput.Write($InputText)
        }
        $process.StandardInput.Close()

        if ($TimeoutSeconds -gt 0) {
            $finished = $process.WaitForExit($TimeoutSeconds * 1000)
            if (-not $finished) {
                $timedOut = $true
                Stop-FleetProcessTree -ProcessId $process.Id
                $process.WaitForExit(5000) | Out-Null
            } else {
                $process.WaitForExit()
            }
        } else {
            $process.WaitForExit()
        }

        if ($null -ne $stdoutTask) {
            $stdout = $stdoutTask.Result
        }
        if ($null -ne $stderrTask) {
            $stderr = $stderrTask.Result
        }
    } catch {
        $startError = $_.Exception.Message
    } finally {
        if ($started -and -not $process.HasExited) {
            Stop-FleetProcessTree -ProcessId $process.Id
        }
    }

    $exitCode = if ($timedOut) { 124 } elseif ($started) { $process.ExitCode } else { 1 }
    $combined = @()
    if (![string]::IsNullOrEmpty($stdout)) {
        $combined += @($stdout -split "\r?\n" | Where-Object { $_ -ne "" })
    }
    if (![string]::IsNullOrEmpty($stderr)) {
        $combined += @($stderr -split "\r?\n" | Where-Object { $_ -ne "" })
    }
    if (![string]::IsNullOrWhiteSpace($startError)) {
        $combined += $startError
    }

    if (![string]::IsNullOrWhiteSpace($LogPath)) {
        $parent = Split-Path -Parent $LogPath
        if (![string]::IsNullOrWhiteSpace($parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        $header = @(
            "Command: $FilePath $(Join-FleetArguments -Arguments $Arguments)",
            "Working directory: $(if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) { Get-Location } else { $WorkingDirectory })",
            "Timeout seconds: $TimeoutSeconds",
            "Timed out: $timedOut",
            "Exit code: $exitCode",
            ""
        )
        Set-Content -Path $LogPath -Value ($header + $combined)
    }

    $process.Dispose()

    return [pscustomobject]@{
        exitCode = $exitCode
        timedOut = $timedOut
        output = $combined
        logPath = $LogPath
    }
}

function ConvertTo-FleetStringArray {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return @()
        }
        return @($Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }

    return @([string]$Value)
}

function Test-FleetRateLimitOutput {
    param([object]$Output)

    $text = ((ConvertTo-FleetStringArray -Value $Output) -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $false
    }

    $patterns = @(
        "(?i)\brate\s*limit\b",
        "(?i)\busage\s*limit\b",
        "(?i)\blimit\s*reached\b",
        "(?i)\bquota\b",
        "(?i)\btoo\s*many\s*requests\b",
        "(?i)\btry\s*again\s*later\b",
        "(?i)\btry\s*again\s*in\b",
        "(?i)\bresets?\s*in\b",
        "(?i)\b5\s*-?\s*hour\s*limit\b",
        "(?i)\bfive\s*-?\s*hour\s*limit\b"
    )

    foreach ($pattern in $patterns) {
        if ($text -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-FleetRateLimitDelaySeconds {
    param(
        [object]$Output,
        [int]$DefaultSeconds = 3600
    )

    $text = ((ConvertTo-FleetStringArray -Value $Output) -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $DefaultSeconds
    }

    $match = [regex]::Match($text, "(?i)(try\s*again\s*in|resets?\s*in|reset\s*time\s*:?)\s*(\d+)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)\b")
    if ($match.Success) {
        $amount = [int]$match.Groups[2].Value
        $unit = $match.Groups[3].Value.ToLowerInvariant()
        $seconds = if ($unit -match "^s") {
            $amount
        } elseif ($unit -match "^m") {
            $amount * 60
        } else {
            $amount * 3600
        }

        return [Math]::Max(60, $seconds + 60)
    }

    return $DefaultSeconds
}

function Test-FleetBlockingReviewOutput {
    param(
        [string]$Path = "",
        [string]$Text = ""
    )

    $content = $Text
    if (![string]::IsNullOrWhiteSpace($Path)) {
        if (!(Test-Path $Path)) {
            return $false
        }
        $content = Get-Content $Path -Raw
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        return $false
    }

    return (
        $content -match "(?im)^\s*REVIEW_STATUS:\s*BLOCKED\b" -or
        $content -match "(?im)^\s*REVIEW_FINDING:\s*P[12]\b" -or
        $content -match "(?im)^\s*\[?P[12]\]?\s*[:\-]" -or
        $content -match "::code-comment\{[^}]*priority=(1|2)\b"
    )
}

function Invoke-FleetCodexReadOnly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string[]]$Models = @(),

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [string]$WorkingDirectory = "",

        [string]$LogPath = "",

        [int]$TimeoutSeconds = 600,

        [int]$RateLimitCooldownSeconds = 3600,

        [int]$RateLimitMaxCooldowns = 4
    )

    $modelChain = @(ConvertTo-FleetStringArray -Value $Models)
    if ($modelChain.Count -eq 0) {
        $modelChain = @("")
    }

    $lastResult = $null
    $cooldownsUsed = 0
    foreach ($model in $modelChain) {
        $modelLabel = if ([string]::IsNullOrWhiteSpace($model)) { "default" } else { $model }
        $safeModel = ($modelLabel -replace "[^a-zA-Z0-9_.-]+", "-")

        while ($true) {
            $suffix = if ($cooldownsUsed -eq 0) { "" } else { "-cooldown-$cooldownsUsed" }
            $modelLogPath = $LogPath
            if (!([string]::IsNullOrWhiteSpace($LogPath))) {
                if ($modelChain.Count -gt 1 -or $cooldownsUsed -gt 0) {
                    $modelLogPath = $LogPath -replace "\.log$", "-$safeModel$suffix.log"
                }
            }

            if (Test-Path $OutputPath) {
                Clear-Content -Path $OutputPath -ErrorAction SilentlyContinue
            }

            $codexArgs = @("exec")
            if (![string]::IsNullOrWhiteSpace($model)) {
                $codexArgs += @("-m", $model)
            }
            $codexArgs += @("-o", $OutputPath, "-")

            Write-Host "Starting read-only Codex run with model $modelLabel" -ForegroundColor DarkCyan
            $lastResult = Invoke-FleetProcess -FilePath "codex" -Arguments $codexArgs -InputText $Prompt -WorkingDirectory $WorkingDirectory -LogPath $modelLogPath -TimeoutSeconds $TimeoutSeconds
            if ($lastResult.timedOut) {
                Write-Host "Read-only Codex run timed out after $TimeoutSeconds seconds on model $modelLabel." -ForegroundColor Yellow
            }

            if ((Test-Path $OutputPath) -and ((Get-Item $OutputPath).Length -gt 0)) {
                return $lastResult
            }

            if (Test-FleetRateLimitOutput -Output $lastResult.output -and $cooldownsUsed -lt $RateLimitMaxCooldowns) {
                $cooldownsUsed++
                $sleepSeconds = Get-FleetRateLimitDelaySeconds -Output $lastResult.output -DefaultSeconds $RateLimitCooldownSeconds
                Write-Host "Codex appears rate-limited. Waiting $sleepSeconds seconds before retry $cooldownsUsed of $RateLimitMaxCooldowns." -ForegroundColor Yellow
                Start-Sleep -Seconds $sleepSeconds
                continue
            }

            break
        }

        if ($model -ne $modelChain[-1]) {
            Write-Host "Model $modelLabel produced no output. Trying next configured model." -ForegroundColor Yellow
        }
    }

    return $lastResult
}
