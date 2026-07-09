[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z][A-Za-z0-9_-]*$")]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("real-product", "frontend-static-demo", "docs-only", "experimental-prototype", "backend-local", "backend-staging")]
    [string]$Profile = "real-product",

    [ValidateSet("", "marketing-site", "full-stack-web", "desktop-app", "cli-tool", "library", "data-pipeline", "ai-workflow", "mobile-app", "game", "documentation", "sandbox-prototype")]
    [string]$ProjectType = "",

    [ValidateSet("", "sandbox", "local-only", "staging", "production-adjacent", "production")]
    [string]$RiskTier = "",

    [ValidateSet("edit-package-files", "add-dependencies", "edit-backend-code", "edit-migrations", "edit-auth-policy", "edit-deployment-config", "use-network-apis", "open-pull-requests", "deploy")]
    [string[]]$Capability = @(),

    [string]$BuildDirectory = "",

    [string]$BuildCommand = "",

    [int]$Rounds = 99,

    [string]$ConfigPath = "",

    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Get-MetadataFullPath {
    param([string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-MetadataPathInside {
    param(
        [string]$ChildPath,
        [string]$ParentPath
    )

    $child = (Get-MetadataFullPath $ChildPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $parent = (Get-MetadataFullPath $ParentPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    if ([string]::Equals($child, $parent, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $parentWithSeparator = $parent + [System.IO.Path]::DirectorySeparatorChar
    return $child.StartsWith($parentWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
}

function Normalize-MetadataPath {
    param([string]$Path)

    return (Get-MetadataFullPath $Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar).ToLowerInvariant()
}

function Get-MetadataObjectPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function New-MetadataCapabilityObject {
    param(
        [object]$DefaultCapabilities,
        [string[]]$EnabledCapabilities
    )

    $capabilities = [ordered]@{
        canEditPackageFiles      = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canEditPackageFiles")
        canAddDependencies       = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canAddDependencies")
        canEditBackendCode       = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canEditBackendCode")
        canEditMigrations        = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canEditMigrations")
        canEditAuthPolicy        = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canEditAuthPolicy")
        canEditDeploymentConfig  = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canEditDeploymentConfig")
        canUseNetworkApis        = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canUseNetworkApis")
        canOpenPullRequests      = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canOpenPullRequests")
        canDeploy                = [bool](Get-MetadataObjectPropertyValue -Object $DefaultCapabilities -Name "canDeploy")
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

function Get-MetadataGitStatus {
    param([string]$RepoPath)

    $summary = [ordered]@{
        is_git_repo  = $false
        repo_root    = ""
        branch       = ""
        head         = ""
        status_short = @()
        notes        = @()
    }

    try {
        $root = @(git -C $RepoPath rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -ne 0 -or $root.Count -eq 0) {
            $summary.notes = @("not_git_repo")
            return [pscustomobject]$summary
        }

        $summary.is_git_repo = $true
        $summary.repo_root = [string]$root[0]
        $summary.branch = [string](@(git -C $RepoPath branch --show-current 2>$null) | Select-Object -First 1)
        $summary.head = [string](@(git -C $RepoPath rev-parse --short HEAD 2>$null) | Select-Object -First 1)
        $summary.status_short = @(git -C $RepoPath status --short -uall 2>$null)
        if ($summary.status_short.Count -eq 0) {
            $summary.notes = @("clean")
        } else {
            $summary.notes = @("dirty_or_untracked_recorded_only")
        }
    } catch {
        $summary.notes = @("git_status_unavailable: $($_.Exception.Message)")
    }

    return [pscustomobject]$summary
}

function Read-MetadataProjects {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }

    $loaded = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) {
        return @($loaded)
    }

    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") {
        return @($loaded.value)
    }

    if ($null -ne $loaded) {
        return @($loaded)
    }

    return @()
}

function Write-MetadataResult {
    param(
        [object]$Result,
        [int]$ExitCode
    )

    if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
        $outFull = Get-MetadataFullPath $OutFile
        $outParent = Split-Path -Parent $outFull
        if (-not [string]::IsNullOrWhiteSpace($outParent)) {
            New-Item -ItemType Directory -Force -Path $outParent | Out-Null
        }

        $Result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
    }

    $Result | ConvertTo-Json -Depth 8
    exit $ExitCode
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $fleetRoot "projects.json"
}

$configFullPath = Get-MetadataFullPath $ConfigPath
$profilePath = Join-Path $fleetRoot "profiles\$Profile.json"

if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
    $result = [ordered]@{
        decision                    = "BLOCKED_UNSAFE_TARGET"
        reason                      = "Profile not found: $profilePath"
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

$repoMatches = @(Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1 -or -not (Test-Path -LiteralPath $repoMatches[0].Path -PathType Container)) {
    $result = [ordered]@{
        decision                    = "BLOCKED_UNSAFE_TARGET"
        reason                      = "Repo path not found or ambiguous: $Repo"
        repo_input                  = $Repo
        config_path                 = $configFullPath
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

$repoPath = $repoMatches[0].Path
$repoFullPath = Get-MetadataFullPath $repoPath

$outFileFullPath = ""
$outFileInsideTarget = $false
if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
    $outFileFullPath = Get-MetadataFullPath $OutFile
    $outFileInsideTarget = Test-MetadataPathInside -ChildPath $outFileFullPath -ParentPath $repoFullPath
}

if ($outFileInsideTarget) {
    $blockedOutFile = $outFileFullPath
    $OutFile = ""
    $result = [ordered]@{
        decision                    = "BLOCKED_UNSAFE_TARGET"
        reason                      = "OutFile must be outside the target repo for metadata-only registration."
        repo                        = $repoFullPath
        out_file                    = $blockedOutFile
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

if (Test-MetadataPathInside -ChildPath $configFullPath -ParentPath $repoFullPath) {
    $result = [ordered]@{
        decision                    = "BLOCKED_UNSAFE_TARGET"
        reason                      = "ConfigPath must be outside the target repo for metadata-only registration."
        repo                        = $repoFullPath
        config_path                 = $configFullPath
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

$beforeStatus = Get-MetadataGitStatus -RepoPath $repoFullPath
if (-not [bool]$beforeStatus.is_git_repo) {
    $result = [ordered]@{
        decision                    = "BLOCKED_UNSAFE_TARGET"
        reason                      = "Target path is not a git repository."
        repo                        = $repoFullPath
        git_status_before           = $beforeStatus
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

$profileData = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($ProjectType)) {
    $ProjectType = if ($profileData.projectType) { [string]$profileData.projectType } else { "marketing-site" }
}
if ([string]::IsNullOrWhiteSpace($RiskTier)) {
    $RiskTier = if ($profileData.riskTier) { [string]$profileData.riskTier } else { "local-only" }
}
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = if ($profileData.buildDirectory) { [string]$profileData.buildDirectory } else { "." }
}
if ([string]::IsNullOrWhiteSpace($BuildCommand)) {
    $BuildCommand = if ($profileData.buildCommand) { [string]$profileData.buildCommand } else { "" }
}

$capabilityPolicy = New-MetadataCapabilityObject -DefaultCapabilities $profileData.capabilities -EnabledCapabilities $Capability
$projects = @(Read-MetadataProjects -Path $configFullPath)
$normalizedRepo = Normalize-MetadataPath $repoFullPath

$exactMatches = @($projects | Where-Object {
    [string]$_.name -eq $Name -and
    -not [string]::IsNullOrWhiteSpace([string]$_.repo) -and
    (Normalize-MetadataPath ([string]$_.repo)) -eq $normalizedRepo
})

$sameNameDifferentPath = @($projects | Where-Object {
    [string]$_.name -eq $Name -and
    (-not [string]::IsNullOrWhiteSpace([string]$_.repo)) -and
    (Normalize-MetadataPath ([string]$_.repo)) -ne $normalizedRepo
})

$samePathDifferentName = @($projects | Where-Object {
    [string]$_.name -ne $Name -and
    (-not [string]::IsNullOrWhiteSpace([string]$_.repo)) -and
    (Normalize-MetadataPath ([string]$_.repo)) -eq $normalizedRepo
})

if ($exactMatches.Count -gt 0) {
    $afterStatus = Get-MetadataGitStatus -RepoPath $repoFullPath
    $result = [ordered]@{
        decision                    = "ALREADY_REGISTERED_EXACT_PATH"
        project_name                = $Name
        repo                        = $repoFullPath
        config_path                 = $configFullPath
        existing_matches            = $exactMatches
        git_status_before           = $beforeStatus
        git_status_after            = $afterStatus
        target_git_status_unchanged = (($beforeStatus.status_short -join "`n") -eq ($afterStatus.status_short -join "`n"))
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 0
}

if ($sameNameDifferentPath.Count -gt 0 -or $samePathDifferentName.Count -gt 0) {
    $afterStatus = Get-MetadataGitStatus -RepoPath $repoFullPath
    $result = [ordered]@{
        decision                    = "EXISTS_DIFFERENT_PATH_REQUIRES_REVIEW"
        project_name                = $Name
        repo                        = $repoFullPath
        config_path                 = $configFullPath
        same_name_different_path    = $sameNameDifferentPath
        same_path_different_name    = $samePathDifferentName
        reason                      = "Metadata-only registration will not overwrite existing name/path records, including archived or wrong-path entries."
        git_status_before           = $beforeStatus
        git_status_after            = $afterStatus
        target_git_status_unchanged = (($beforeStatus.status_short -join "`n") -eq ($afterStatus.status_short -join "`n"))
        target_repo_mutated         = $false
        product_repos_mutated       = $false
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 0
}

$projectEntry = [pscustomobject][ordered]@{
    name                     = $Name
    repo                     = $repoFullPath
    rounds                   = $Rounds
    briefScript              = "scripts\codex-brief.ps1"
    loopScript               = "scripts\codex-night-loop.ps1"
    buildDirectory           = $BuildDirectory
    buildCommand             = $BuildCommand
    profile                  = $Profile
    projectType              = $ProjectType
    riskTier                 = $RiskTier
    capabilities             = $capabilityPolicy
    metadataOnlyRegistration = [pscustomobject][ordered]@{
        registeredBy                         = "tools/register-project-metadata-only.ps1"
        registeredAtUtc                      = (Get-Date).ToUniversalTime().ToString("o")
        targetRepoReadOnly                   = $true
        harnessInstallSkipped                = $true
        localGitExcludeMutationSkipped       = $true
        checkpointValidationSkipped          = $true
        buildCheckSkipped                    = $true
        exactPathRegistrationRequired        = $true
        archivedDifferentPathOverwriteBlocked = $true
    }
}

$updatedProjects = @($projects) + $projectEntry
$configParent = Split-Path -Parent $configFullPath
if (-not [string]::IsNullOrWhiteSpace($configParent)) {
    New-Item -ItemType Directory -Force -Path $configParent | Out-Null
}

@($updatedProjects) |
    Sort-Object name |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $configFullPath -Encoding UTF8

$reloadedProjects = @(Read-MetadataProjects -Path $configFullPath)
$registered = @($reloadedProjects | Where-Object {
    [string]$_.name -eq $Name -and
    (-not [string]::IsNullOrWhiteSpace([string]$_.repo)) -and
    (Normalize-MetadataPath ([string]$_.repo)) -eq $normalizedRepo
})
$afterWriteStatus = Get-MetadataGitStatus -RepoPath $repoFullPath
$targetUnchanged = (($beforeStatus.status_short -join "`n") -eq ($afterWriteStatus.status_short -join "`n"))

if ($registered.Count -ne 1 -or -not $targetUnchanged) {
    $result = [ordered]@{
        decision                    = "BLOCKED_VALIDATION_FAILED"
        project_name                = $Name
        repo                        = $repoFullPath
        config_path                 = $configFullPath
        registered_match_count      = $registered.Count
        git_status_before           = $beforeStatus
        git_status_after            = $afterWriteStatus
        target_git_status_unchanged = $targetUnchanged
        target_repo_mutated         = (-not $targetUnchanged)
        product_repos_mutated       = (-not $targetUnchanged)
        installs_run                = $false
        migrations_run              = $false
        push_merge_deploy_run       = $false
        all_fleet_run               = $false
        background_runners_started  = $false
    }
    Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 1
}

$result = [ordered]@{
    decision                    = "REGISTERED_NEW_METADATA_ONLY"
    project_name                = $Name
    repo                        = $repoFullPath
    config_path                 = $configFullPath
    registered_entry            = $registered[0]
    git_status_before           = $beforeStatus
    git_status_after            = $afterWriteStatus
    target_git_status_unchanged = $targetUnchanged
    target_repo_mutated         = $false
    product_repos_mutated       = $false
    installs_run                = $false
    migrations_run              = $false
    push_merge_deploy_run       = $false
    all_fleet_run               = $false
    background_runners_started  = $false
}

Write-MetadataResult -Result ([pscustomobject]$result) -ExitCode 0
