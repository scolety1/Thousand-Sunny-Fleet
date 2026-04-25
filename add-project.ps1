[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z][A-Za-z0-9_-]*$")]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("real-product", "frontend-static-demo", "docs-only", "experimental-prototype")]
    [string]$Profile = "frontend-static-demo",

    [ValidateSet("", "marketing-site", "full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game", "documentation", "sandbox-prototype")]
    [string]$ProjectType = "",

    [ValidateSet("", "sandbox", "local-only", "staging", "production-adjacent", "production")]
    [string]$RiskTier = "",

    [ValidateSet("edit-package-files", "add-dependencies", "edit-backend-code", "edit-migrations", "edit-auth-policy", "edit-deployment-config", "use-network-apis", "open-pull-requests", "deploy")]
    [string[]]$Capability = @(),

    [string]$BuildDirectory,

    [string]$BuildCommand,

    [int]$Rounds = 99,

    [switch]$Force,

    [switch]$SkipInstall,

    [switch]$RunBuildCheck
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Add-LocalExclude {
    param([string]$RepoPath)

    $infoDir = Join-Path $RepoPath ".git\info"
    if (!(Test-Path $infoDir)) {
        return
    }

    $excludePath = Join-Path $infoDir "exclude"
    if (!(Test-Path $excludePath)) {
        New-Item -ItemType File -Path $excludePath -Force | Out-Null
    }

    $exclude = Get-Content $excludePath -ErrorAction SilentlyContinue
    if ($exclude -notcontains ".codex-logs/") {
        Add-Content -Path $excludePath -Value ".codex-logs/"
        Write-Host "Added .codex-logs/ to .git/info/exclude" -ForegroundColor Green
    }
}

function Get-ObjectPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function New-CapabilityObject {
    param(
        [object]$DefaultCapabilities,
        [string[]]$EnabledCapabilities
    )

    $capabilities = [ordered]@{
        canEditPackageFiles = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canEditPackageFiles")
        canAddDependencies = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canAddDependencies")
        canEditBackendCode = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canEditBackendCode")
        canEditMigrations = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canEditMigrations")
        canEditAuthPolicy = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canEditAuthPolicy")
        canEditDeploymentConfig = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canEditDeploymentConfig")
        canUseNetworkApis = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canUseNetworkApis")
        canOpenPullRequests = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canOpenPullRequests")
        canDeploy = [bool](Get-ObjectPropertyValue -Object $DefaultCapabilities -Name "canDeploy")
    }

    foreach ($item in @($EnabledCapabilities)) {
        switch ($item) {
            "edit-package-files" { $capabilities.canEditPackageFiles = $true }
            "add-dependencies" { $capabilities.canAddDependencies = $true }
            "edit-backend-code" { $capabilities.canEditBackendCode = $true }
            "edit-migrations" { $capabilities.canEditMigrations = $true }
            "edit-auth-policy" { $capabilities.canEditAuthPolicy = $true }
            "edit-deployment-config" { $capabilities.canEditDeploymentConfig = $true }
            "use-network-apis" { $capabilities.canUseNetworkApis = $true }
            "open-pull-requests" { $capabilities.canOpenPullRequests = $true }
            "deploy" { $capabilities.canDeploy = $true }
        }
    }

    return [pscustomobject]$capabilities
}

$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $fleetRoot "projects.json"
$profilePath = Join-Path $fleetRoot "profiles\$Profile.json"

if (!(Test-Path $profilePath)) {
    Stop-WithMessage "Profile not found: $profilePath"
}

$repoMatches = @(Resolve-Path $Repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Stop-WithMessage "Repo path not found or ambiguous: $Repo"
}
$repoPath = $repoMatches[0].Path

Push-Location $repoPath
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Stop-WithMessage "Repo is not a git repository: $repoPath"
}
$status = @(git status --short)
if ($status.Count -gt 0 -and !$Force) {
    Pop-Location
    Write-Host "Repo has uncommitted changes. Re-run with -Force only if you want to install/register anyway." -ForegroundColor Red
    $status | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Pop-Location

$profileData = Get-Content $profilePath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($ProjectType)) {
    $ProjectType = if ($profileData.projectType) { [string]$profileData.projectType } else { "marketing-site" }
}
if ([string]::IsNullOrWhiteSpace($RiskTier)) {
    $RiskTier = if ($profileData.riskTier) { [string]$profileData.riskTier } else { "local-only" }
}
$capabilityPolicy = New-CapabilityObject -DefaultCapabilities $profileData.capabilities -EnabledCapabilities $Capability

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = if ($profileData.buildDirectory) { [string]$profileData.buildDirectory } else { "." }
}
if ([string]::IsNullOrWhiteSpace($BuildCommand)) {
    $BuildCommand = if ($profileData.buildCommand) { [string]$profileData.buildCommand } else { "" }
}

if (!$SkipInstall) {
    $installArgs = @(
        "-Repo", $repoPath,
        "-Profile", $Profile,
        "-Rounds", $Rounds
    )
    if ($Force) {
        $installArgs += "-Force"
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "install-harness.ps1") @installArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Harness install failed for $Name."
    }
}

Add-LocalExclude -RepoPath $repoPath

$projects = @()
if (Test-Path $configPath) {
    $loadedProjects = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($loadedProjects -is [array]) {
        $projects = @($loadedProjects)
    } elseif ($null -ne $loadedProjects -and $loadedProjects.PSObject.Properties.Name -contains "value") {
        $projects = @($loadedProjects.value)
    } elseif ($null -ne $loadedProjects) {
        $projects = @($loadedProjects)
    }
}

$projectEntry = [pscustomobject]@{
    name = $Name
    repo = $repoPath
    rounds = $Rounds
    briefScript = "scripts\codex-brief.ps1"
    loopScript = "scripts\codex-night-loop.ps1"
    buildDirectory = $BuildDirectory
    buildCommand = $BuildCommand
    profile = $Profile
    projectType = $ProjectType
    riskTier = $RiskTier
    capabilities = $capabilityPolicy
}

$existing = @($projects | Where-Object { $_.name -eq $Name -or $_.repo -eq $repoPath })
if ($existing.Count -gt 0) {
    $projects = @($projects | Where-Object { $_.name -ne $Name -and $_.repo -ne $repoPath })
    Write-Host "Updating existing project registration for $Name" -ForegroundColor Yellow
}

$projects += $projectEntry
$projects = @($projects | Where-Object { $_.name -and $_.repo })
@($projects) |
    Sort-Object name |
    ConvertTo-Json -Depth 8 |
    Set-Content -Path $configPath -Encoding UTF8

Write-Host "Registered $Name in projects.json" -ForegroundColor Green

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "run-checkpoint-loop.ps1") -Project $Name -ValidateOnly
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "Project registration failed checkpoint-loop validation."
}

if ($RunBuildCheck -and ![string]::IsNullOrWhiteSpace($BuildCommand)) {
    Push-Location (Join-Path $repoPath $BuildDirectory)
    Invoke-Expression $BuildCommand
    $buildOk = $LASTEXITCODE -eq 0
    Pop-Location
    if (!$buildOk) {
        Stop-WithMessage "Build check failed for $Name."
    }
}

Write-Host ""
Write-Host "Project joined the fleet: $Name" -ForegroundColor Green
Write-Host "Repo: $repoPath"
Write-Host "Profile: $Profile"
Write-Host "Project type: $ProjectType"
Write-Host "Risk tier: $RiskTier"
Write-Host "Build directory: $BuildDirectory"
Write-Host "Build command: $BuildCommand"
Write-Host ""
Write-Host "First safe test run:" -ForegroundColor Cyan
Write-Host ".\run-checkpoint-loop.ps1 -Project $Name -BatchSize 1 -MaxBatches 1"
