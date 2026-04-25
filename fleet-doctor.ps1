[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

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
    if ($ExcludeProject.Count -gt 0) {
        $exclude = @($ExcludeProject | ForEach-Object { [string]$_ })
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
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

function Get-ShipProfileData {
    param([object]$Ship)

    $profileName = Get-ConfigPropertyValue -Object $Ship -Name "profile"
    if ([string]::IsNullOrWhiteSpace([string]$profileName)) {
        return $null
    }

    $profilePath = Join-Path $script:FleetRoot "profiles\$profileName.json"
    if (!(Test-Path $profilePath)) {
        return $null
    }

    try {
        return Get-Content $profilePath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function New-DefaultCapabilityObject {
    return [pscustomobject]@{
        canEditPackageFiles = $false
        canAddDependencies = $false
        canEditBackendCode = $false
        canEditMigrations = $false
        canEditAuthPolicy = $false
        canEditDeploymentConfig = $false
        canUseNetworkApis = $false
        canOpenPullRequests = $false
        canDeploy = $false
    }
}

function Resolve-IntakeMetadata {
    param(
        [object]$Ship,
        [object]$ProfileData
    )

    $projectType = Get-ConfigPropertyValue -Object $Ship -Name "projectType"
    if ([string]::IsNullOrWhiteSpace([string]$projectType)) {
        $projectType = Get-ConfigPropertyValue -Object $ProfileData -Name "projectType"
    }
    if ([string]::IsNullOrWhiteSpace([string]$projectType)) {
        $projectType = "unknown"
    }

    $riskTier = Get-ConfigPropertyValue -Object $Ship -Name "riskTier"
    if ([string]::IsNullOrWhiteSpace([string]$riskTier)) {
        $riskTier = Get-ConfigPropertyValue -Object $ProfileData -Name "riskTier"
    }
    if ([string]::IsNullOrWhiteSpace([string]$riskTier)) {
        $riskTier = "unknown"
    }

    $capabilities = Get-ConfigPropertyValue -Object $Ship -Name "capabilities"
    if ($null -eq $capabilities) {
        $capabilities = Get-ConfigPropertyValue -Object $ProfileData -Name "capabilities"
    }
    if ($null -eq $capabilities) {
        $capabilities = New-DefaultCapabilityObject
    }

    return [pscustomobject]@{
        projectType = [string]$projectType
        riskTier = [string]$riskTier
        capabilities = $capabilities
    }
}

function Get-EnabledCapabilityNames {
    param([object]$Capabilities)

    $labels = [ordered]@{
        canEditPackageFiles = "package-files"
        canAddDependencies = "dependencies"
        canEditBackendCode = "backend-code"
        canEditMigrations = "migrations"
        canEditAuthPolicy = "auth-policy"
        canEditDeploymentConfig = "deployment-config"
        canUseNetworkApis = "network-apis"
        canOpenPullRequests = "pull-requests"
        canDeploy = "deploy"
    }

    $enabled = @()
    foreach ($key in $labels.Keys) {
        if ([bool](Get-ConfigPropertyValue -Object $Capabilities -Name $key)) {
            $enabled += $labels[$key]
        }
    }

    if ($enabled.Count -eq 0) {
        return "none"
    }

    return ($enabled -join ", ")
}

function Get-ArchitecturePlanStatus {
    if (!(Test-Path "docs/codex/ARCHITECTURE.md") -or !(Test-Path "docs/codex/ENGINEERING_PLAN.md") -or !(Test-Path "docs/codex/RISK_REGISTER.md")) {
        return "missing"
    }

    if (!(Test-Path "docs/codex/ARCHITECTURE_APPROVAL.md")) {
        return "draft"
    }

    $approval = Get-Content "docs/codex/ARCHITECTURE_APPROVAL.md" -Raw
    if ($approval -match "(?im)^\s*Status:\s*APPROVED\s*$") {
        return "approved"
    }

    return "draft"
}

function Get-DependencyApprovalStatus {
    if (!(Test-Path "docs/codex/DEPENDENCY_PROPOSAL.md")) {
        return "missing"
    }

    if (!(Test-Path "docs/codex/DEPENDENCY_APPROVAL.md")) {
        return "draft"
    }

    $approval = Get-Content "docs/codex/DEPENDENCY_APPROVAL.md" -Raw
    if ($approval -match "(?im)^\s*Status:\s*APPROVED\s*$") {
        return "approved"
    }

    return "draft"
}

function Get-MigrationApprovalStatus {
    if (!(Test-Path "docs/codex/MIGRATION_PROPOSAL.md")) {
        return "missing"
    }

    if (!(Test-Path "docs/codex/MIGRATION_APPROVAL.md")) {
        return "draft"
    }

    $approval = Get-Content "docs/codex/MIGRATION_APPROVAL.md" -Raw
    if ($approval -match "(?im)^\s*Status:\s*APPROVED\s*$") {
        return "approved"
    }

    return "draft"
}

function Get-SensitiveSystemsStatus {
    $hasRegistry = Test-Path "docs/codex/EXTERNAL_SERVICES.md"
    $authOk = (!(Test-Path "docs/codex/AUTH_POLICY.md") -or (Test-ApprovedStatus -Path "docs/codex/AUTH_APPROVAL.md"))
    $paymentOk = (!(Test-Path "docs/codex/PAYMENT_RISK.md") -or (Test-ApprovedStatus -Path "docs/codex/PAYMENT_APPROVAL.md"))

    if ($hasRegistry -and $authOk -and $paymentOk) { return "ready" }
    if ($hasRegistry -or (Test-Path "docs/codex/AUTH_POLICY.md") -or (Test-Path "docs/codex/PAYMENT_RISK.md")) { return "draft" }
    return "missing"
}

function Get-RuntimeVerificationStatus {
    if (!(Test-Path "docs/codex/RUNTIME_VERIFICATION.md")) {
        if (Test-Path "docs/codex/RUNTIME_CHECKS.md") { return "missing" }
        return "not-configured"
    }

    $report = Get-Content "docs/codex/RUNTIME_VERIFICATION.md" -Raw
    if ($report -match "(?is)## Verdict\s+GREEN\b") { return "green" }
    if ($report -match "(?is)## Verdict\s+RED\b") { return "red" }
    return "yellow"
}

function Get-MaintenanceStatus {
    $hasQueue = Test-Path "docs/codex/MAINTENANCE_QUEUE.md"
    $hasWindows = Test-Path "docs/codex/MAINTENANCE_WINDOWS.md"

    if ($hasQueue -and $hasWindows) { return "configured" }
    if ($hasQueue -or $hasWindows) { return "partial" }
    return "missing"
}

function Get-AutopilotStatus {
    if (!(Test-Path "docs/codex/AUTOPILOT_POLICY.md")) { return "missing" }
    if (!(Test-Path "docs/codex/AUTOPILOT_APPROVAL.md")) { return "draft" }
    if (Test-ApprovedStatus -Path "docs/codex/AUTOPILOT_APPROVAL.md") { return "approved-limited" }
    return "draft"
}

function Test-ApprovedStatus {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $false }
    $text = Get-Content $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
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
            robin = "missing"
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
    $robin = Get-MarkdownValue -Path "docs/codex/ROBIN_COPY_REVIEW.md" -Heading "Verdict"
    $joey = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
    $missionExists = Test-Path "docs/codex/MISSION.md"
    $taskQueueExists = Test-Path "docs/codex/TASK_QUEUE.md"
    $runPolicyExists = Test-Path "docs/codex/RUN_POLICY.md"
    $architectureStatus = Get-ArchitecturePlanStatus
    $dependencyStatus = Get-DependencyApprovalStatus
    $migrationStatus = Get-MigrationApprovalStatus
    $sensitiveStatus = Get-SensitiveSystemsStatus
    $runtimeStatus = Get-RuntimeVerificationStatus
    $maintenanceStatus = Get-MaintenanceStatus
    $autopilotStatus = Get-AutopilotStatus
    Pop-Location

    $profileStatus = Test-ProfileExists -Ship $Ship
    $profileData = Get-ShipProfileData -Ship $Ship
    $intake = Resolve-IntakeMetadata -Ship $Ship -ProfileData $profileData
    $buildCommand = Get-ConfigPropertyValue -Object $Ship -Name "buildCommand"
    $buildDirectory = Get-ConfigPropertyValue -Object $Ship -Name "buildDirectory"
    $visualPaths = Get-ConfigPropertyValue -Object $Ship -Name "visualPaths"
    $allowedProjectTypes = @("marketing-site", "full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game", "documentation", "sandbox-prototype")
    $allowedRiskTiers = @("sandbox", "local-only", "staging", "production-adjacent", "production")

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

    if ($allowedProjectTypes -notcontains $intake.projectType) {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Unknown projectType: $($intake.projectType)."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Project type classified: $($intake.projectType)."
    }

    if ($allowedRiskTiers -notcontains $intake.riskTier) {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Unknown riskTier: $($intake.riskTier)."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Risk tier classified: $($intake.riskTier)."
    }

    $enabledCapabilities = Get-EnabledCapabilityNames -Capabilities $intake.capabilities
    if ($intake.riskTier -eq "production" -and $enabledCapabilities -match "\bdeploy\b") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Production deploy capability is enabled; require explicit captain approval before launch."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Capability policy loaded: $enabledCapabilities."
    }

    $seriousShip = (
        $intake.projectType -in @("full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game") -or
        $intake.riskTier -in @("staging", "production-adjacent", "production") -or
        $enabledCapabilities -ne "none"
    )
    if ($seriousShip -and $architectureStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 1 architecture planning pack is missing; run fleet-plan.ps1 before broad work."
    } elseif ($seriousShip -and $architectureStatus -eq "draft") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 1 architecture planning pack is still DRAFT."
    } elseif ($seriousShip) {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 1 architecture planning pack is approved."
    }

    $dependencyGateNeeded = (
        [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canEditPackageFiles") -or
        [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canAddDependencies")
    )
    if ($dependencyGateNeeded -and $dependencyStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 2 dependency proposal is missing for package/dependency-capable ship."
    } elseif ($dependencyGateNeeded -and $dependencyStatus -eq "draft") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 2 dependency proposal is still DRAFT."
    } elseif ($dependencyGateNeeded) {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 2 dependency proposal is approved."
    }

    $migrationGateNeeded = [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canEditMigrations")
    if ($migrationGateNeeded -and $migrationStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 4 migration proposal is missing for migration-capable ship."
    } elseif ($migrationGateNeeded -and $migrationStatus -eq "draft") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 4 migration proposal is still DRAFT."
    } elseif ($migrationGateNeeded) {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 4 migration proposal is approved."
    }

    $sensitiveGateNeeded = (
        [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canEditAuthPolicy") -or
        [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canUseNetworkApis") -or
        [bool](Get-ConfigPropertyValue -Object $intake.capabilities -Name "canDeploy")
    )
    if ($sensitiveGateNeeded -and $sensitiveStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 5 sensitive systems registry is missing."
    } elseif ($sensitiveGateNeeded -and $sensitiveStatus -eq "draft") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 5 sensitive systems policy is still DRAFT."
    } elseif ($sensitiveGateNeeded) {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 5 sensitive systems policy is ready."
    }

    if ($runtimeStatus -eq "red") {
        Add-Finding -Findings $findings -Level "FAIL" -Message "Phase 6 runtime verification is RED."
    } elseif ($runtimeStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 6 runtime checks are configured but no verification report exists."
    } elseif ($runtimeStatus -eq "green") {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 6 runtime verification is GREEN."
    }

    if ($maintenanceStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 8 maintenance queue is missing; run fleet-maintenance.ps1 -Template when the ship is ready for recurring maintenance."
    } elseif ($maintenanceStatus -eq "partial") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 8 maintenance lane is partially configured."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 8 maintenance lane is configured."
    }

    if ($autopilotStatus -eq "missing") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 9 limited autopilot policy is missing; run fleet-autopilot-policy.ps1 -Template before any business autopilot."
    } elseif ($autopilotStatus -eq "draft") {
        Add-Finding -Findings $findings -Level "WARN" -Message "Phase 9 limited autopilot policy is still DRAFT."
    } else {
        Add-Finding -Findings $findings -Level "OK" -Message "Phase 9 limited autopilot policy is approved."
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
        @{ name = "Robin"; value = $robin },
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
    $recommended = ".\run-checkpoint-loop.ps1 -Project $name -BatchSize $batchSize -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint"

    return [pscustomobject]@{
        name = $name
        repo = $repo
        branch = $branch
        head = $head
        dirty = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }
        projectType = $intake.projectType
        riskTier = $intake.riskTier
        capabilities = $enabledCapabilities
        architecture = $architectureStatus
        dependencies = $dependencyStatus
        migrations = $migrationStatus
        sensitiveSystems = $sensitiveStatus
        runtime = $runtimeStatus
        maintenance = $maintenanceStatus
        autopilot = $autopilotStatus
        uncheckedTasks = $taskCount
        firstTask = $firstTask
        checkpoint = $checkpoint
        simon = $simon
        robin = $robin
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
    "| Ship | Ready | Type | Risk | Architecture | Dependencies | Migrations | Sensitive | Runtime | Maintenance | Autopilot | Branch | HEAD | Dirty | Tasks | Checkpoint | Simon | Robin | Joey |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |"
)

foreach ($diagnosis in $diagnoses) {
    $ready = if ($diagnosis.launchReady) { "YES" } else { "NO" }
    $lines += "| $($diagnosis.name) | $ready | $($diagnosis.projectType) | $($diagnosis.riskTier) | $($diagnosis.architecture) | $($diagnosis.dependencies) | $($diagnosis.migrations) | $($diagnosis.sensitiveSystems) | $($diagnosis.runtime) | $($diagnosis.maintenance) | $($diagnosis.autopilot) | $($diagnosis.branch) | $($diagnosis.head) | $($diagnosis.dirty) | $($diagnosis.uncheckedTasks) | $($diagnosis.checkpoint) | $($diagnosis.simon) | $($diagnosis.robin) | $($diagnosis.joey) |"
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
    $lines += "- Project type: $($diagnosis.projectType)"
    $lines += "- Risk tier: $($diagnosis.riskTier)"
    $lines += "- Enabled capabilities: $($diagnosis.capabilities)"
    $lines += "- Architecture: $($diagnosis.architecture)"
    $lines += "- Dependencies: $($diagnosis.dependencies)"
    $lines += "- Migrations: $($diagnosis.migrations)"
    $lines += "- Sensitive systems: $($diagnosis.sensitiveSystems)"
    $lines += "- Runtime verification: $($diagnosis.runtime)"
    $lines += "- Maintenance lane: $($diagnosis.maintenance)"
    $lines += "- Limited autopilot: $($diagnosis.autopilot)"
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
        Write-Host "Chopper says $($diagnosis.name) is ${status}: $($diagnosis.projectType), $($diagnosis.riskTier), architecture $($diagnosis.architecture), dependencies $($diagnosis.dependencies), migrations $($diagnosis.migrations), sensitive $($diagnosis.sensitiveSystems), runtime $($diagnosis.runtime), maintenance $($diagnosis.maintenance), autopilot $($diagnosis.autopilot), $($diagnosis.dirty), tasks $($diagnosis.uncheckedTasks), checkpoint $($diagnosis.checkpoint), Simon $($diagnosis.simon), Robin $($diagnosis.robin), Joey $($diagnosis.joey)." -ForegroundColor $color
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
