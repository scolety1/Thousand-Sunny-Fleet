[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [string[]]$ExpectedProject = @(),

    [int]$BatchSize = 3,

    [int]$MaxBatches = 20,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 8,

    [int]$MaxTaskQuarantines = 5,

    [int]$LaunchDelaySeconds = 0,

    [int]$VisualInspectEvery = 0,

    [int]$SimonEvery = 0,

    [int]$RobinEvery = 0,

    [int]$JoeyEvery = 0,

    [switch]$SkipDoctor,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$RequireMagicPreflight,

    [switch]$UseGlobalRunShape,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function ConvertTo-ProjectList {
    param([string[]]$Values = @())

    return @(
        $Values |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Get-Projects {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsed = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsed | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) {
            Stop-WithMessage "Project not found: $Project"
        }
    }
    if ($ExcludeProject.Count -gt 0) {
        $exclude = @(ConvertTo-ProjectList -Values $ExcludeProject)
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
    }

    return $projects
}

function Get-ShipInt {
    param(
        [object]$Ship,
        [string]$Name,
        [int]$Default
    )

    if ($null -ne $Ship -and $Ship.PSObject.Properties[$Name]) {
        $value = $Ship.PSObject.Properties[$Name].Value
        if ($null -ne $value -and [int]$value -gt 0) {
            return [int]$value
        }
    }

    return $Default
}

if ($BatchSize -lt 1) { Stop-WithMessage "-BatchSize must be at least 1." }
if ($MaxBatches -lt 1) { Stop-WithMessage "-MaxBatches must be at least 1." }
if ($RateLimitCooldownSeconds -lt 60) { Stop-WithMessage "-RateLimitCooldownSeconds must be at least 60." }
if ($RateLimitMaxCooldowns -lt 0) { Stop-WithMessage "-RateLimitMaxCooldowns must be 0 or greater." }
if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }
if ($LaunchDelaySeconds -lt 0) { Stop-WithMessage "-LaunchDelaySeconds must be 0 or greater." }
if ($VisualInspectEvery -lt 0) { Stop-WithMessage "-VisualInspectEvery must be 0 or greater." }
if ($SimonEvery -lt 0) { Stop-WithMessage "-SimonEvery must be 0 or greater." }
if ($RobinEvery -lt 0) { Stop-WithMessage "-RobinEvery must be 0 or greater." }
if ($JoeyEvery -lt 0) { Stop-WithMessage "-JoeyEvery must be 0 or greater." }

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter $Project -ExcludeProject $ExcludeProject -AllowSafeStopRequests:$AllowSafeStopRequests

if (!$SkipDoctor) {
    $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $ConfigPath)
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $doctorArgs += @("-Project", $Project)
    }
    $doctorExclusions = @(ConvertTo-ProjectList -Values $ExcludeProject)
    if ($doctorExclusions.Count -gt 0) {
        $doctorArgs += @("-ExcludeProject", ($doctorExclusions -join ","))
    }
    & powershell @doctorArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Overnight run refused. Chopper found a ship that is not ready."
    }
}

if ($RequireMagicPreflight) {
    $preflightArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "prepare-magic-run.ps1"), "-ConfigPath", $ConfigPath, "-AllowNoTasks", "-Strict")
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $preflightArgs += @("-Project", $Project)
    }
    $preflightExclusions = @(ConvertTo-ProjectList -Values $ExcludeProject)
    if ($preflightExclusions.Count -gt 0) {
        $preflightArgs += @("-ExcludeProject", ($preflightExclusions -join ","))
    }
    & powershell @preflightArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Overnight run refused. Magic preflight found a blocking ship."
    }
}

$shipsToLaunch = @(Get-Projects)
$expectedProjects = @(ConvertTo-ProjectList -Values $ExpectedProject)
if ($expectedProjects.Count -gt 0) {
    $actualProjects = @($shipsToLaunch | ForEach-Object { [string]$_.name } | Sort-Object -Unique)
    $missing = @($expectedProjects | Where-Object { $actualProjects -notcontains $_ })
    $unexpected = @($actualProjects | Where-Object { $expectedProjects -notcontains $_ })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        Write-Host "Selected launch validation failed." -ForegroundColor Red
        Write-Host "Expected: $($expectedProjects -join ', ')" -ForegroundColor Yellow
        Write-Host "Actual: $($actualProjects -join ', ')" -ForegroundColor Yellow
        if ($missing.Count -gt 0) { Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Yellow }
        if ($unexpected.Count -gt 0) { Write-Host "Unexpected: $($unexpected -join ', ')" -ForegroundColor Yellow }
        exit 1
    }
}
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode "overnight" -ConfigPath $ConfigPath -ProjectFilter $Project
for ($shipIndex = 0; $shipIndex -lt $shipsToLaunch.Count; $shipIndex++) {
    $ship = $shipsToLaunch[$shipIndex]
    $shipBatchSize = if ($UseGlobalRunShape) { $BatchSize } else { Get-ShipInt -Ship $ship -Name "overnightBatchSize" -Default $BatchSize }
    $shipMaxBatches = if ($UseGlobalRunShape) { $MaxBatches } else { Get-ShipInt -Ship $ship -Name "overnightMaxBatches" -Default $MaxBatches }
    $shipVisualEvery = if ($VisualInspectEvery -gt 0) { $VisualInspectEvery } else { Get-ShipInt -Ship $ship -Name "overnightVisualInspectEvery" -Default 3 }
    $shipSimonEvery = if ($SimonEvery -gt 0) { $SimonEvery } else { Get-ShipInt -Ship $ship -Name "overnightSimonEvery" -Default 3 }
    $shipRobinEvery = if ($RobinEvery -gt 0) { $RobinEvery } else { Get-ShipInt -Ship $ship -Name "overnightRobinEvery" -Default $shipSimonEvery }
    $shipJoeyEvery = if ($JoeyEvery -gt 0) { $JoeyEvery } else { Get-ShipInt -Ship $ship -Name "overnightJoeyEvery" -Default 6 }
    $shipLaunchDelay = Get-ShipInt -Ship $ship -Name "launchDelaySeconds" -Default $LaunchDelaySeconds

    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -Project '$($ship.name)' -BatchSize $shipBatchSize -MaxBatches $shipMaxBatches -VisualInspectEvery $shipVisualEvery -SimonEvery $shipSimonEvery -RobinEvery $shipRobinEvery -JoeyEvery $shipJoeyEvery -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns -MaxTaskQuarantines $MaxTaskQuarantines$(if ($QuarantineFailedTasks) { ' -QuarantineFailedTasks' } else { '' })$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching overnight run for $($ship.name): batch $shipBatchSize x $shipMaxBatches, Simon every $shipSimonEvery, Robin every $shipRobinEvery..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host $command
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -DryRun
    } else {
        $process = Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -ProcessId $process.Id
        if ($shipIndex -lt ($shipsToLaunch.Count - 1) -and $shipLaunchDelay -gt 0) {
            Write-Host "Waiting $shipLaunchDelay seconds before launching the next ship..." -ForegroundColor DarkCyan
            Start-Sleep -Seconds $shipLaunchDelay
        }
    }
}

Write-FleetLaunchManifest -Manifest $manifest
