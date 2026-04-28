[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$BaseBranch = "main",

    [string]$OutFile = "out\merge-readiness.md",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (!(Test-Path $fleetRuntime)) {
    Write-Host "Fleet runtime helper not found: $fleetRuntime" -ForegroundColor Red
    exit 1
}
. $fleetRuntime

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

function Get-MarkdownValue {
    param(
        [string]$Path,
        [string]$Heading
    )

    if (!(Test-Path $Path)) {
        return "missing"
    }

    $text = Get-Content $Path -Raw
    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)"
    $match = [regex]::Match($text, $pattern)
    if ($match.Success) {
        $value = $match.Groups[1].Value.Trim()
        if ($Heading -eq "Verdict") {
            $verdict = [regex]::Match($value, "^(GREEN|YELLOW|RED)\b", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($verdict.Success) {
                return $verdict.Groups[1].Value.ToUpperInvariant()
            }
        }
        return $value
    }

    return "unknown"
}

function Normalize-Path {
    param([string]$Path)
    return ($Path -replace "\\", "/")
}

function Add-Reason {
    param(
        [System.Collections.Generic.List[string]]$Reasons,
        [string]$Message
    )

    if (![string]::IsNullOrWhiteSpace($Message)) {
        $Reasons.Add($Message) | Out-Null
    }
}

function Get-UncheckedTaskCount {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        return 0
    }

    return @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Get-VisualFindingCount {
    param([ValidateSet("High", "Medium", "Low")] [string]$Severity)

    if (!(Test-Path "docs/codex/VISUAL_BUGS.md")) {
        return 0
    }

    return @(Select-String -Path "docs/codex/VISUAL_BUGS.md" -Pattern "\[$($Severity.ToUpperInvariant())\]" -ErrorAction SilentlyContinue).Count
}

function Get-LatestBatchQaSummary {
    $path = "docs/codex/MAGIC_SCORECARD.md"
    if (!(Test-Path $path)) {
        return [pscustomobject]@{
            status = "missing"
            checkpoint = "missing"
            simon = "missing"
            robin = "missing"
            joey = "missing"
            debug = "missing"
            score = "missing"
            scorecardCommit = "missing"
            commitsAfter = 0
        }
    }

    $text = Get-Content $path -Raw
    $matches = [regex]::Matches($text, "(?ims)^##\s+Batch\s+\d+\s+QA\s+-\s+.+?(?=^##\s+|\z)")
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{
            status = "missing"
            checkpoint = "missing"
            simon = "missing"
            robin = "missing"
            joey = "missing"
            debug = "missing"
            score = "missing"
            scorecardCommit = "missing"
            commitsAfter = 0
        }
    }

    $latest = $matches[$matches.Count - 1].Value
    function Get-LineValue {
        param([string]$Label)
        $match = [regex]::Match($latest, "(?im)^-\s+$([regex]::Escape($Label)):\s*(.+)$")
        if ($match.Success) {
            $value = $match.Groups[1].Value.Trim()
            if ($Label -match "verdict$") {
                $verdict = [regex]::Match($value, "^(GREEN|YELLOW|RED)\b", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($verdict.Success) {
                    return $verdict.Groups[1].Value.ToUpperInvariant()
                }
            }
            return $value
        }
        return "unknown"
    }

    $scorecardCommit = (git rev-list -1 HEAD -- $path 2>$null)
    $commitsAfter = 0
    if (![string]::IsNullOrWhiteSpace($scorecardCommit)) {
        $commitsAfterText = (git rev-list --count "$scorecardCommit..HEAD" 2>$null)
        if (![string]::IsNullOrWhiteSpace($commitsAfterText)) {
            $commitsAfter = [int]$commitsAfterText
        }
    } else {
        $scorecardCommit = "unknown"
    }

    return [pscustomobject]@{
        status = "present"
        checkpoint = Get-LineValue "Checkpoint verdict"
        simon = Get-LineValue "Simon verdict"
        robin = Get-LineValue "Robin verdict"
        joey = Get-LineValue "Joey verdict"
        debug = Get-LineValue "Debug checkpoint result"
        score = Get-LineValue "Simon improvement score"
        scorecardCommit = $scorecardCommit
        commitsAfter = $commitsAfter
    }
}

function Invoke-ProjectBuild {
    param([object]$ProjectConfig)

    if ($SkipBuild) {
        return [pscustomobject]@{
            status = "skipped"
            log = ""
        }
    }

    $buildCommand = [string](Get-ConfigPropertyValue -Object $ProjectConfig -Name "buildCommand")
    if ([string]::IsNullOrWhiteSpace($buildCommand)) {
        return [pscustomobject]@{
            status = "not configured"
            log = ""
        }
    }

    $buildDirectory = [string](Get-ConfigPropertyValue -Object $ProjectConfig -Name "buildDirectory")
    if ([string]::IsNullOrWhiteSpace($buildDirectory)) {
        $buildDirectory = "."
    }

    $buildPath = Resolve-Path $buildDirectory -ErrorAction SilentlyContinue
    if (!$buildPath) {
        return [pscustomobject]@{
            status = "failed"
            log = "Build directory not found: $buildDirectory"
        }
    }

    $timeout = 600
    $timeouts = Get-ConfigPropertyValue -Object $ProjectConfig -Name "timeouts"
    if ($null -ne $timeouts) {
        $configuredTimeout = Get-ConfigPropertyValue -Object $timeouts -Name "build"
        if ($null -ne $configuredTimeout -and [int]$configuredTimeout -gt 0) {
            $timeout = [int]$configuredTimeout
        }
    }

    $logPath = Join-Path ".codex-logs" ("merge-readiness-build-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    $result = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $buildCommand) -WorkingDirectory $buildPath.Path -LogPath $logPath -TimeoutSeconds $timeout
    $status = if ($result.exitCode -eq 0) { "passed" } elseif ($result.timedOut) { "timed out" } else { "failed" }

    return [pscustomobject]@{
        status = $status
        log = $logPath
    }
}

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
    if ($projects.Count -ne 1) {
        Write-Host "Project not found: $Project" -ForegroundColor Red
        exit 1
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()

foreach ($projectConfig in $projects) {
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $repoMatches = @(Resolve-Path $projectConfig.repo -ErrorAction SilentlyContinue)
    if ($repoMatches.Count -ne 1) {
        Add-Reason -Reasons $reasons -Message "Repo missing or ambiguous: $($projectConfig.repo)"
        $results += [pscustomobject]@{
            ship = $projectConfig.name
            status = "DO NOT MERGE"
            repo = $projectConfig.repo
            branch = "missing"
            head = "missing"
            build = "not run"
            changedFiles = @()
            reasons = @($reasons)
            warnings = @($warnings)
            tasks = 0
            checkpoint = "missing"
            simon = "missing"
            robin = "missing"
            joey = "missing"
            visual = "missing"
        }
        continue
    }

    $repoPath = $repoMatches[0].Path
    Push-Location $repoPath

    $branch = git branch --show-current 2>$null
    $head = git rev-parse --short HEAD 2>$null
    $dirty = @(git status --short 2>$null)
    $commitCount = 0
    $changed = @()
    git merge-base $BaseBranch HEAD *> $null
    if ($LASTEXITCODE -eq 0) {
        $commitCount = [int](git rev-list --count "$BaseBranch..HEAD" 2>$null)
        $changed = @(git diff --name-status "$BaseBranch..HEAD" 2>$null | ForEach-Object { Normalize-Path $_ })
    } else {
        Add-Reason -Reasons $reasons -Message "Could not compare branch with $BaseBranch."
    }

    $build = Invoke-ProjectBuild -ProjectConfig $projectConfig
    $taskCount = Get-UncheckedTaskCount
    $checkpoint = Get-MarkdownValue -Path "docs/codex/CHECKPOINT_REVIEW.md" -Heading "Verdict"
    $simon = Get-MarkdownValue -Path "docs/codex/SIMON_DESIGN_REVIEW.md" -Heading "Verdict"
    $robin = Get-MarkdownValue -Path "docs/codex/ROBIN_COPY_REVIEW.md" -Heading "Verdict"
    $joey = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
    $visualHigh = Get-VisualFindingCount -Severity "High"
    $visualMedium = Get-VisualFindingCount -Severity "Medium"
    $visual = if (!(Test-Path "docs/codex/VISUAL_BUGS.md")) { "missing" } else { "high $visualHigh, medium $visualMedium" }
    $batchQa = Get-LatestBatchQaSummary

    if ($branch -eq $BaseBranch) { Add-Reason -Reasons $reasons -Message "Ship is on $BaseBranch, not a review branch." }
    if ($dirty.Count -gt 0) { Add-Reason -Reasons $reasons -Message "Working tree is dirty: $($dirty.Count) file(s)." }
    if ($commitCount -eq 0) { Add-Reason -Reasons $reasons -Message "No commits ahead of $BaseBranch." }
    if ($build.status -notin @("passed", "skipped", "not configured")) { Add-Reason -Reasons $reasons -Message "Build $($build.status)." }
    if ($checkpoint -eq "RED") { Add-Reason -Reasons $reasons -Message "Checkpoint verdict is RED." }
    if ($checkpoint -eq "missing" -or $checkpoint -eq "unknown") { Add-Reason -Reasons $warnings -Message "Checkpoint verdict is $checkpoint." }
    if ($joey -eq "RED") { Add-Reason -Reasons $reasons -Message "Joey security review is RED." }
    if ($joey -eq "missing" -or $joey -eq "unknown") { Add-Reason -Reasons $warnings -Message "Joey security review is $joey." }
    if ($simon -eq "RED") { Add-Reason -Reasons $reasons -Message "Simon design review is RED." }
    if ($simon -eq "YELLOW") { Add-Reason -Reasons $warnings -Message "Simon design review is YELLOW; inspect visuals before merge." }
    if ($robin -eq "RED") { Add-Reason -Reasons $reasons -Message "Robin copy review is RED." }
    if ($robin -eq "YELLOW") { Add-Reason -Reasons $warnings -Message "Robin copy review is YELLOW; inspect copy before merge." }
    if ($visualHigh -gt 0) { Add-Reason -Reasons $reasons -Message "Visual bug report has $visualHigh high finding(s)." }
    if ($visualMedium -gt 0) { Add-Reason -Reasons $warnings -Message "Visual bug report has $visualMedium medium finding(s)." }
    if ($batchQa.status -eq "missing" -and $commitCount -gt 0) { Add-Reason -Reasons $warnings -Message "No fresh batch QA scorecard entry found." }
    if ($batchQa.status -eq "present" -and $batchQa.commitsAfter -gt 0) { Add-Reason -Reasons $warnings -Message "Batch QA scorecard is stale: $($batchQa.commitsAfter) commit(s) after latest scorecard update." }
    if ($batchQa.debug -match "^FAIL") { Add-Reason -Reasons $reasons -Message "Batch QA debug checkpoint result is $($batchQa.debug)." }
    if ($batchQa.checkpoint -eq "RED") { Add-Reason -Reasons $reasons -Message "Batch QA checkpoint verdict is RED." }
    if ($batchQa.simon -eq "RED") { Add-Reason -Reasons $reasons -Message "Batch QA Simon verdict is RED." }
    if ($batchQa.robin -eq "RED") { Add-Reason -Reasons $reasons -Message "Batch QA Robin verdict is RED." }
    if ($batchQa.joey -eq "RED") { Add-Reason -Reasons $reasons -Message "Batch QA Joey verdict is RED." }

    $status = if ($reasons.Count -gt 0) {
        "DO NOT MERGE"
    } elseif ($warnings.Count -gt 0) {
        "SAFE TO INSPECT"
    } else {
        "SAFE TO MERGE AFTER HUMAN REVIEW"
    }

    $results += [pscustomobject]@{
        ship = $projectConfig.name
        status = $status
        repo = $repoPath
        branch = $branch
        head = $head
        build = $build.status
        buildLog = $build.log
        commitsAhead = $commitCount
        changedFiles = $changed
        reasons = @($reasons)
        warnings = @($warnings)
        tasks = $taskCount
        checkpoint = $checkpoint
        simon = $simon
        robin = $robin
        joey = $joey
        visual = $visual
        batchQaStatus = $batchQa.status
        batchQaDebug = $batchQa.debug
        batchQaScore = $batchQa.score
        batchQaCommitsAfter = $batchQa.commitsAfter
    }

    Pop-Location
}

$overall = if (@($results | Where-Object { $_.status -eq "DO NOT MERGE" }).Count -gt 0) {
    "DO NOT MERGE"
} elseif (@($results | Where-Object { $_.status -eq "SAFE TO INSPECT" }).Count -gt 0) {
    "SAFE TO INSPECT"
} else {
    "SAFE TO MERGE AFTER HUMAN REVIEW"
}

$lines = @(
    "# Fleet Merge Readiness",
    "",
    "Generated: $timestamp",
    "Base branch: $BaseBranch",
    "Overall: $overall",
    "",
    "Jimbei Harbor Master note: this report does not merge anything. It only tells the captain which ships are allowed near the dock.",
    "",
    "| Ship | Status | Branch | HEAD | Commits | Build | Tasks | Checkpoint | Simon | Robin | Joey | Visual | Batch QA |",
    "| --- | --- | --- | --- | ---: | --- | ---: | --- | --- | --- | --- | --- | --- |"
)

foreach ($result in $results) {
    $lines += "| $($result.ship) | $($result.status) | $($result.branch) | $($result.head) | $($result.commitsAhead) | $($result.build) | $($result.tasks) | $($result.checkpoint) | $($result.simon) | $($result.robin) | $($result.joey) | $($result.visual) | $($result.batchQaStatus) / $($result.batchQaDebug) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.ship)"
    $lines += ""
    $lines += "- Status: $($result.status)"
    $lines += "- Repo: $($result.repo)"
    $lines += "- Branch: $($result.branch)"
    $lines += "- HEAD: $($result.head)"
    $lines += "- Build: $($result.build)"
    $lines += "- Batch QA: $($result.batchQaStatus) / debug $($result.batchQaDebug)"
    $lines += "- Batch QA freshness: $($result.batchQaCommitsAfter) commit(s) after latest scorecard update"
    $lines += "- Batch QA Simon score: $($result.batchQaScore)"
    if (![string]::IsNullOrWhiteSpace([string]$result.buildLog)) {
        $lines += "- Build log: $($result.buildLog)"
    }

    if ($result.reasons.Count -gt 0) {
        $lines += ""
        $lines += "Blocking reasons:"
        foreach ($reason in $result.reasons) {
            $lines += "- $reason"
        }
    }

    if ($result.warnings.Count -gt 0) {
        $lines += ""
        $lines += "Inspection notes:"
        foreach ($warning in $result.warnings) {
            $lines += "- $warning"
        }
    }

    $lines += ""
    $lines += "Changed files:"
    if ($result.changedFiles.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($file in @($result.changedFiles | Select-Object -First 80)) {
            $lines += "- $file"
        }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines

Write-Host "Jimbei Harbor Master - $overall" -ForegroundColor $(if ($overall -eq "DO NOT MERGE") { "Red" } elseif ($overall -eq "SAFE TO INSPECT") { "Yellow" } else { "Green" })
Write-Host "Report: $OutFile"
foreach ($result in $results) {
    $color = if ($result.status -eq "DO NOT MERGE") { "Red" } elseif ($result.status -eq "SAFE TO INSPECT") { "Yellow" } else { "Green" }
    Write-Host ("{0}: {1} | branch {2} | build {3} | checkpoint {4} | Simon {5} | Robin {6} | Joey {7} | batch QA {8}/{9}" -f $result.ship, $result.status, $result.branch, $result.build, $result.checkpoint, $result.simon, $result.robin, $result.joey, $result.batchQaStatus, $result.batchQaDebug) -ForegroundColor $color
}

if ($overall -eq "DO NOT MERGE") {
    exit 1
}
exit 0
