[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath,
    [string]$OutRoot = ".codex-local\audit-loop-packages",
    [string]$AuditId = "",
    [int]$MaxFiles = 20,
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Resolve-FleetPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )
    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)
    if (!$baseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = [System.Uri]::new($baseFull)
    $childUri = [System.Uri]::new($childFull)
    return ([System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()) -replace "/", [System.IO.Path]::DirectorySeparatorChar)
}

function Test-AuditLoopSafeRelativePath {
    param(
        [string]$RelativePath,
        [string[]]$ForbiddenDataSources
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) { return $false }
    $normalized = ($RelativePath -replace "\\", "/").Trim("/")
    if ($normalized -match "(^|/)\.\.(/|$)") { return $false }
    if ($normalized -match "(?i)(^|/)(\.env|\.git|node_modules|dist|build|\.codex-local/locks)(/|$)") { return $false }
    if ($normalized -match "(?i)(secret|token|credential|private[-_]?key)") { return $false }
    foreach ($forbidden in @($ForbiddenDataSources)) {
        if ([string]::IsNullOrWhiteSpace($forbidden)) { continue }
        $forbiddenNormalized = ([string]$forbidden -replace "\\", "/").Trim("/")
        if ($normalized.Equals($forbiddenNormalized, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($normalized.StartsWith($forbiddenNormalized.TrimEnd("/") + "/", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($forbiddenNormalized.Contains("*") -and ($normalized -like $forbiddenNormalized)) { return $false }
    }
    return $true
}

function Test-AuditLoopSafeSource {
    param(
        [string]$RelativePath,
        [string[]]$SafeDataSources
    )
    if (@($SafeDataSources).Count -eq 0) { return $true }
    $normalized = ($RelativePath -replace "\\", "/").Trim("/")
    foreach ($safe in @($SafeDataSources)) {
        if ([string]::IsNullOrWhiteSpace($safe)) { continue }
        $safeNormalized = ([string]$safe -replace "\\", "/").Trim("/")
        if ($safeNormalized -eq "." -or $safeNormalized -eq "") { return $true }
        if ($normalized.Equals($safeNormalized, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($normalized.StartsWith($safeNormalized.TrimEnd("/") + "/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Add-IncludedFile {
    param(
        [string]$Source,
        [string]$DestinationRoot,
        [string]$RelativePath,
        [System.Collections.Generic.List[object]]$Included
    )
    $destination = Join-Path $DestinationRoot $RelativePath
    $parent = Split-Path -Parent $destination
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    $Included.Add([pscustomobject]@{
        path = ($RelativePath -replace "\\", "/")
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    }) | Out-Null
}

$metadataFullPath = Resolve-FleetPath $MetadataPath
if (!(Test-Path -LiteralPath $metadataFullPath)) { throw "Metadata not found: $metadataFullPath" }
$metadata = Get-Content -LiteralPath $metadataFullPath -Raw | ConvertFrom-Json

$repo = Resolve-FleetPath ([string]$metadata.repository)
if (!(Test-Path -LiteralPath $repo -PathType Container)) { throw "Repository not found: $repo" }
if ([string]::IsNullOrWhiteSpace($AuditId)) {
    $safeName = ([string]$metadata.projectName -replace "[^A-Za-z0-9._-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "audit-loop" }
    $AuditId = "$safeName-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$outFullRoot = Resolve-FleetPath $OutRoot
$packageRoot = Join-Path $outFullRoot $AuditId
if (Test-Path -LiteralPath $packageRoot) { throw "Audit loop package already exists: $packageRoot" }
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

$included = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

Add-IncludedFile -Source $metadataFullPath -DestinationRoot $packageRoot -RelativePath "metadata/audit-loop-metadata.json" -Included $included

foreach ($declaredFile in @($metadata.auditPackageFiles)) {
    $relative = ([string]$declaredFile -replace "\\", "/").Trim("/")
    if (!(Test-AuditLoopSafeRelativePath -RelativePath $relative -ForbiddenDataSources @($metadata.forbiddenDataSources))) {
        $skipped.Add([pscustomobject]@{ path = $relative; reason = "forbidden-or-unsafe-path" }) | Out-Null
        continue
    }
    if (!(Test-AuditLoopSafeSource -RelativePath $relative -SafeDataSources @($metadata.safeDataSources))) {
        $skipped.Add([pscustomobject]@{ path = $relative; reason = "not-listed-in-safeDataSources" }) | Out-Null
        continue
    }
    $source = Join-Path $repo $relative
    if (!(Test-Path -LiteralPath $source -PathType Leaf)) {
        $skipped.Add([pscustomobject]@{ path = $relative; reason = "missing" }) | Out-Null
        continue
    }
    Add-IncludedFile -Source $source -DestinationRoot $packageRoot -RelativePath (Join-Path "files" $relative) -Included $included
}

if ($MaxFiles -gt 0 -and @($included).Count -gt $MaxFiles) {
    $warnings.Add(("Included file count {0} exceeds MaxFiles {1}." -f @($included).Count, $MaxFiles)) | Out-Null
}

$templatePath = Join-Path $fleetRoot "docs\templates\audit-loop\external-audit-prompt-template.md"
$template = if (Test-Path -LiteralPath $templatePath) {
    Get-Content -LiteralPath $templatePath -Raw
} else {
    "# External Audit Prompt`n`nReview this package as read-only evidence."
}
$prompt = $template
$prompt = $prompt.Replace("{{projectName}}", [string]$metadata.projectName)
$prompt = $prompt.Replace("{{repository}}", $repo)
$prompt = $prompt.Replace("{{riskTier}}", [string]$metadata.riskTier)
$prompt = $prompt.Replace("{{inScopeSurfaces}}", (@($metadata.inScopeSurfaces) -join ", "))
$prompt = $prompt.Replace("{{outOfScopeSurfaces}}", (@($metadata.surfaces | Where-Object { @($metadata.inScopeSurfaces) -notcontains $_ }) -join ", "))
$prompt = $prompt.Replace("{{maxTasks}}", [string]$metadata.maxTasks)
$prompt = $prompt.Replace("{{auditPackageName}}", $AuditId)
$prompt = $prompt.Replace("{{manifestPath}}", "manifest.json")
$prompt = $prompt.Replace("{{evidenceIndexPath}}", "PACKAGE_REPORT.md")
$prompt = $prompt.Replace("{{acceptedLimitations}}", (@($metadata.acceptedLimitations) -join "; "))
$promptPath = Join-Path $packageRoot "prompts\external-audit-prompt.md"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $promptPath) | Out-Null
Set-Content -LiteralPath $promptPath -Encoding UTF8 -Value $prompt
$included.Add([pscustomobject]@{ path = "prompts/external-audit-prompt.md"; sha256 = (Get-FileHash -LiteralPath $promptPath -Algorithm SHA256).Hash }) | Out-Null

$reportPath = Join-Path $packageRoot "PACKAGE_REPORT.md"
$report = @(
    "# Audit Loop Package Report",
    "",
    "- Project: $($metadata.projectName)",
    "- Risk tier: $($metadata.riskTier)",
    "- Generated: $((Get-Date).ToUniversalTime().ToString('o'))",
    "- Included files: $(@($included).Count)",
    "- Skipped files: $(@($skipped).Count)",
    "- MaxFiles: $MaxFiles",
    "",
    "## Safety",
    "",
    "This package is metadata-driven, read-only evidence. It includes only files declared in `auditPackageFiles` that also pass safe-data and forbidden-path checks. It excludes secrets, `.git`, dependency folders, build outputs, generated locks, parent traversal, and absolute package file paths.",
    "",
    "## Included Files",
    ""
)
$report += @($included | ForEach-Object { "- ``{0}``" -f $_.path })
if (@($skipped).Count -gt 0) {
    $report += @("", "## Skipped Files", "")
    $report += @($skipped | ForEach-Object { "- ``{0}`` - {1}" -f $_.path, $_.reason })
}
if (@($warnings).Count -gt 0) {
    $report += @("", "## Warnings", "")
    $report += @($warnings | ForEach-Object { "- $_" })
}
Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value $report
$included.Add([pscustomobject]@{ path = "PACKAGE_REPORT.md"; sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash }) | Out-Null

$manifest = [pscustomobject]@{
    packageType = "audit-loop"
    auditId = $AuditId
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    projectName = [string]$metadata.projectName
    repository = $repo
    riskTier = [string]$metadata.riskTier
    inScopeSurfaces = @($metadata.inScopeSurfaces)
    maxTasks = [int]$metadata.maxTasks
    maxFiles = $MaxFiles
    warnings = @($warnings)
    skipped = @($skipped)
    files = @($included)
    exclusions = @(".env", ".git", "node_modules", "dist", "build", ".codex-local/locks", "secrets", "tokens", "credentials")
}
$manifestPath = Join-Path $packageRoot "manifest.json"
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$included.Add([pscustomobject]@{ path = "manifest.json"; sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash }) | Out-Null
$manifest.files = @($included)
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$zipPath = ""
if (!$NoZip) {
    $zipPath = Join-Path $outFullRoot "$AuditId.zip"
    Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force
}

Write-Host "AUDIT_LOOP_PACKAGE: $packageRoot"
if ($zipPath) { Write-Host "AUDIT_LOOP_ZIP: $zipPath" }
