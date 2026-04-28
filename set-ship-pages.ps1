[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string[]]$Path = @(),

    [string]$ConfigPath = ".\projects.json",

    [switch]$InstallSiteMap,

    [switch]$NoVisualConfig
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$configFullPath = Join-Path $fleetRoot $ConfigPath

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Normalize-RoutePath {
    param([string]$Value)

    $route = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($route)) { return "" }
    if (!$route.StartsWith("/")) { $route = "/$route" }
    return $route
}

function Get-RouteLabel {
    param([string]$Route)

    if ($Route -eq "/") { return "Home" }
    $leaf = ($Route.Trim("/") -split "/")[-1]
    $leaf = $leaf -replace "\?.*$", ""
    $words = @($leaf -split "[-_]" | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($words.Count -eq 0) { return $Route }
    return (($words | ForEach-Object {
        if ($_.Length -le 1) { $_.ToUpperInvariant() } else { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }
    }) -join " ")
}

if (!(Test-Path -LiteralPath $configFullPath)) {
    Stop-WithMessage "Config not found: $configFullPath"
}

$routes = @($Path | ForEach-Object { Normalize-RoutePath $_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($routes.Count -eq 0) {
    Stop-WithMessage "Provide at least one -Path value, for example: -Path /,/wine-list,/contact"
}
if ($routes -notcontains "/") {
    $routes = @("/") + $routes
}

$loadedProjects = Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json
if ($loadedProjects -is [array]) {
    $projects = @($loadedProjects)
} elseif ($null -ne $loadedProjects -and $loadedProjects.PSObject.Properties.Name -contains "value") {
    $projects = @($loadedProjects.value)
} elseif ($null -ne $loadedProjects) {
    $projects = @($loadedProjects)
} else {
    $projects = @()
}
$matches = @($projects | Where-Object { [string]$_.name -ceq [string]$Project })
if ($matches.Count -ne 1) {
    Stop-WithMessage "Project not found or ambiguous: $Project"
}

$ship = $matches[0]
$repo = [string]$ship.repo
if ([string]::IsNullOrWhiteSpace($repo) -or !(Test-Path -LiteralPath $repo)) {
    Stop-WithMessage "Project repo not found: $repo"
}

$status = @(git -C $repo status --short)
if ($status.Count -gt 0) {
    Write-Host "Warning: ship working tree is dirty. Updating docs/config only; preserving existing ship work." -ForegroundColor Yellow
    $status | ForEach-Object { Write-Host "  $_" }
}

if ($ship.PSObject.Properties["visualPaths"]) {
    $ship.visualPaths = @($routes)
} else {
    $ship | Add-Member -NotePropertyName "visualPaths" -NotePropertyValue @($routes)
}
@($projects) | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFullPath -Encoding UTF8

if ($InstallSiteMap) {
    $template = Join-Path $fleetRoot "templates\docs\codex\SITE_MAP.md"
    $siteMapPath = Join-Path $repo "docs\codex\SITE_MAP.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $siteMapPath) | Out-Null
    if (!(Test-Path -LiteralPath $siteMapPath)) {
        Copy-Item -LiteralPath $template -Destination $siteMapPath -Force
    }
}

if (!$NoVisualConfig) {
    $routeConfigPath = Join-Path $repo "docs\codex\visual-routes.json"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $routeConfigPath) | Out-Null
    $routeObjects = @($routes | ForEach-Object {
        [pscustomobject]@{
            path = $_
            label = Get-RouteLabel -Route $_
            requiredText = @()
        }
    })
    [pscustomobject]@{
        routes = $routeObjects
        viewports = @(
            [pscustomobject]@{ name = "desktop"; width = 1440; height = 1000; deviceScaleFactor = 1; mobile = $false },
            [pscustomobject]@{ name = "mobile"; width = 390; height = 844; deviceScaleFactor = 2; mobile = $true }
        )
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $routeConfigPath -Encoding UTF8
}

Write-Host "Updated $Project visual/page routes:" -ForegroundColor Green
$routes | ForEach-Object { Write-Host "  $_" }
Write-Host "Next visual check:" -ForegroundColor Cyan
Write-Host ".\fleet-visual-check.ps1 -Project $Project -NoFailOnFindings"
