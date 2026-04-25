[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$OutFile = "out\fleet-doctor.md",

    [switch]$AllowDirty,

    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$script:FleetRoot = if (![string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
} else {
    Get-Location
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [ValidateSet("FAIL", "WARN", "OK")]
        [string]$Level,
        [string]$Message
    )

    $Findings.Add([pscustomobject]@{
        level = $Level
        message = $Message
    }) | Out-Null
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

function Get-ProjectList {
    if (!(Test-Path $ConfigPath)) {
        Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })

    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq [string]$Project })
        if ($projects.Count -ne 1) {
            Write-Host "Project not found or ambiguous: $Project" -ForegroundColor Red
            exit 1
        }
    }

    return $projects
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
        return $match.Groups[1].Value.Trim()
    }

    return "unknown"
}

function Get-UncheckedTaskCount {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        return 0
    }

    return @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Get-FirstUncheckedTask {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        return ""
    }

    $match = Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]\s+(.+)$" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($match) {
        return $match.Matches[0].Groups[1].Value.Trim()
    }

    return ""
}

function Test-ProfileExists {
    param([object]$Ship)

    $profileName = Get-ConfigPropertyValue -Object $Ship -Name "profile"
    if ([string]::IsNullOrWhiteSpace([string]$profileName)) {
        return "missing"
    }

    $profilePath = Join-Path $script:FleetRoot "profiles\$profileName.json"
    if (Test-Path $profilePath) {
        return [string]$profileName
    }

    return "missing:$profileName"
}

function Get-ShipDiagnosis {
    param([object]$Ship)

    $findings = [System.Collections.Generic.List[object]]::new()
    $repo = [string]$Ship.repo
    $name = [string]$Ship.name

    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = Split-Path -Leaf $repo
    }

    if ([string]::IsNullOrWhiteSpace($repo) -or !(Test-Path $repo)) {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Repo missing: $repo"
        return [pscustomobject]@{
            name = $name
            repo = $repo
            branch = "missing"
            head = "missing"
            dirty = "n/a"
            uncheckedTasks = 0
            firstTask = ""
            checkpoint = "missing"
            simon = "missing"
            joey = "missing"
            launchReady = $false
            recommendedCommand = "Fix repo path before launch."
            findings = @($findings)
        }
    }

    Push-Location $repo
    $branch = git branch --show-current 2>$null
    $head = git rev-parse --short HEAD 2>$null
    if ([string]::IsNullOrWhiteSpace($head)) { $head = "none" }
    $dirty = @(git status --short 2>$null)
    $taskCount = Get-UncheckedTaskCount
    $firstTask = Get-FirstUncheckedTask
    $checkpoint = Get-MarkdownValue -Path "docs/codex/CHECKPOINT_REVIEW.md" -Heading "Verdict"
    $simon = Get-MarkdownValue -Path "docs/codex/SIMON_DESIGN_REVIEW.md" -Heading "Verdict"
    $joey = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
    $missionExists = Test-Path "docs/codex/MISSION.md"
    $taskQueueExists = Test-Path "docs/codex/TASK_QUEUE.md"
    $runPolicyExists = Test-Path "docs/codex/RUN_POLICY.md"
    Pop-Location

    $profileStatus = Test-ProfileExists -Ship $Ship
    $buildCommand = Get-ConfigPropertyValue -Object $Ship -Name "buildCommand"
    $buildDirectory = Get-ConfigPropertyValue -Object $Ship -Name "buildDirectory"
    $visualPaths = Get-ConfigPropertyValue -Object $Ship -Name "visualPaths"

    if ($dirty.Count -gt 0 -and !$AllowDirty) {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Working tree is dirty: $($dirty.Count) file(s)."
    } elseif ($dirty.Count -gt 0) {
        Add-Finding -Findings $findings -Level "WARN" -Message "Working tree is dirty but -AllowDirty was used."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Working tree is clean."
    }

    if (!$missionExists) { Add-Finding -Findings $findings -Level "WARN" -Message "Missing docs/codex/MISSION.md." }
    if (!$taskQueueExists) { Add-Finding -Findings $findings -Level "FAIL" -Message "Missing docs/codex/TASK_QUEUE.md." }
    if (!$runPolicyExists) { Add-Finding -Findings $findings -Level "WARN" -Message "Missing docs/codex/RUN_POLICY.md." }

    if ($profileStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "No profile configured; using script defaults."
    } elseif ($profileStatus -match "^missing:") {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Configured profile file not found: $($profileStatus.Substring(8))."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Profile configured: $profileStatus."
    }

    if ([string]::IsNullOrWhiteSpace([string]$buildCommand)) {
        Add-Finding -Findings $findings -Level "WARN" -Message "No build command configured."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Build command configured."
    }

    if (![string]::IsNullOrWhiteSpace([string]$buildDirectory)) {
        $buildPath = Join-Path $repo ([string]$buildDirectory)
        if (!(Test-Path $buildPath)) {
            Add-Finding -Findings $findings -Level "FAIL" -Message "Build directory missing: $buildDirectory."
        }
    }

    if ($null -eq $visualPaths -or @($visualPaths).Count -eq 0) {
        Add-Finding -Findings $findings -Level "WARN" -Message "No visualPaths configured."
    }

    foreach ($verdict in @(
        @{ name = "checkpoint"; value = $checkpoint },
        @{ name = "Simon"; value = $simon },
        @{ name = "Joey"; value = $joey }
    )) {
        if ([string]$verdict.value -match "^RED\b") {
            Add-Finding -Findings $findings -Level "FAIL" -Message "$($verdict.name) verdict is RED."
        } elseif ([string]$verdict.value -match "^YELLOW\b") {
            Add-Finding -Findings $findings -Level "WARN" -Message "$($verdict.name) verdict is YELLOW; launch is allowed but expect repair-first tasks."
        }
    }

    if ($taskCount -eq 0) {
        Add-Finding -Findings $findings -Level "WARN" -Message "No unchecked tasks; Nami will generate next tasks during checkpoint loop."
    }

    $failCount = @($findings | Where-Object { $_.level -eq "FAIL" }).Count
    $batchSize = if ($taskCount -eq 0) { 2 } else { [Math]::Min(3, [Math]::Max(1, $taskCount)) }
    $recommended = ".\run-checkpoint-loop.ps1 -Project $name -BatchSize $batchSize -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint"

    return [pscustomobject]@{
        name = $name
        repo = $repo
        branch = $branch
        head = $head
        dirty = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }
        uncheckedTasks = $taskCount
        firstTask = $firstTask
        checkpoint = $checkpoint
        simon = $simon
        joey = $joey
        launchReady = ($failCount -eq 0)
        recommendedCommand = $recommended
        findings = @($findings)
    }
}

$ships = Get-ProjectList
$diagnoses = @($ships | ForEach-Object { Get-ShipDiagnosis -Ship $_ })
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$lines = @(
    "# Tony Tony Chopper Fleet Doctor Report",
    "",
    "Generated: $timestamp",
    "",
    "| Ship | Ready | Branch | HEAD | Dirty | Tasks | Checkpoint | Simon | Joey |",
    "| --- | --- | --- | --- | --- | ---: | --- | --- | --- |"
)

foreach ($diagnosis in $diagnoses) {
    $ready = if ($diagnosis.launchReady) { "YES" } else { "NO" }
    $lines += "| $($diagnosis.name) | $ready | $($diagnosis.branch) | $($diagnosis.head) | $($diagnosis.dirty) | $($diagnosis.uncheckedTasks) | $($diagnosis.checkpoint) | $($diagnosis.simon) | $($diagnosis.joey) |"
}

$lines += ""
$lines += "## Ship Notes"
$lines += ""
foreach ($diagnosis in $diagnoses) {
    $readyText = if ($diagnosis.launchReady) { "YES" } else { "NO" }
    $firstTaskText = if ([string]::IsNullOrWhiteSpace($diagnosis.firstTask)) { "None" } else { $diagnosis.firstTask }
    $lines += "### $($diagnosis.name)"
    $lines += ""
    $lines += "- Repo: $($diagnosis.repo)"
    $lines += "- Ready: $readyText"
    $lines += "- First unchecked task: $firstTaskText"
    $lines += "- Recommended command: $($diagnosis.recommendedCommand)"
    $lines += "- Findings:"
    foreach ($finding in $diagnosis.findings) {
        $lines += "  - [$($finding.level)] $($finding.message)"
    }
    $lines += ""
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines

if (!$Quiet) {
    Write-Host "Tony Tony Chopper Fleet Doctor - $timestamp" -ForegroundColor Cyan
    Write-Host "Report: $OutFile"
    foreach ($diagnosis in $diagnoses) {
        $color = if ($diagnosis.launchReady) { "Green" } else { "Red" }
        $status = if ($diagnosis.launchReady) { "healthy" } else { "not ready" }
        Write-Host "Chopper says $($diagnosis.name) is ${status}: $($diagnosis.dirty), tasks $($diagnosis.uncheckedTasks), checkpoint $($diagnosis.checkpoint), Simon $($diagnosis.simon), Joey $($diagnosis.joey)." -ForegroundColor $color
        if (!$diagnosis.launchReady) {
            $diagnosis.findings | Where-Object { $_.level -eq "FAIL" } | ForEach-Object {
                Write-Host "  - $($_.message)" -ForegroundColor Red
            }
        }
    }
}

$failed = @($diagnoses | Where-Object { -not $_.launchReady })
if ($failed.Count -gt 0) {
    exit 1
}

exit 0
