[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$ProjectName = "",

    [string]$RequestedCapability = "",

    [string]$OutDirectory = "",

    [int]$MaxFiles = 2500,

    [int]$MaxBytesPerFile = 262144
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function ConvertTo-OnboardingSlug {
    param([string]$Value)

    $slug = ([string]$Value).Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "repo-onboarding"
    }

    return $slug
}

function Get-OnboardingFullPath {
    param([string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-OnboardingPathInside {
    param(
        [string]$ChildPath,
        [string]$ParentPath
    )

    $child = Get-OnboardingFullPath $ChildPath
    $parent = Get-OnboardingFullPath $ParentPath
    if ([string]::Equals($child.TrimEnd([System.IO.Path]::DirectorySeparatorChar), $parent.TrimEnd([System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if (-not $parent.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $parent = $parent + [System.IO.Path]::DirectorySeparatorChar
    }

    return $child.StartsWith($parent, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-OnboardingRelativePath {
    param(
        [string]$BasePath,
        [string]$Path
    )

    $baseFull = Get-OnboardingFullPath $BasePath
    if (-not $baseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFull = $baseFull + [System.IO.Path]::DirectorySeparatorChar
    }

    $pathFull = Get-OnboardingFullPath $Path
    $baseUri = [Uri]$baseFull
    $pathUri = [Uri]$pathFull
    $relative = $baseUri.MakeRelativeUri($pathUri).ToString()
    return ([Uri]::UnescapeDataString($relative)).Replace("/", "\")
}

function New-OnboardingRow {
    param(
        [string]$AssetPath,
        [string]$AssetType,
        [string]$MatchedTerms,
        [string]$ApparentPurpose,
        [string]$Notes
    )

    [pscustomobject]@{
        asset_path       = $AssetPath
        asset_type       = $AssetType
        matched_terms    = $MatchedTerms
        apparent_purpose = $ApparentPurpose
        notes            = $Notes
    }
}

function Get-OnboardingAssetType {
    param([string]$RelativePath)

    $path = ([string]$RelativePath).Replace("/", "\")
    $name = Split-Path -Leaf $path
    $lower = $path.ToLowerInvariant()

    if ($lower -match "^\.github\\workflows\\") { return "ci_workflow" }
    if ($lower -match "(^|\\)(test|tests|__tests__)\\|(\.test\.|\.spec\.)") { return "test" }
    if ($lower -match "^(scripts|tools|bin)\\|\.ps1$|\.sh$|\.cmd$|\.bat$") { return "script_or_tool" }
    if ($lower -match "^(docs|documentation)\\|(^|\\)(readme|changelog|contributing|license|architecture|runbook)") { return "important_doc" }
    if ($lower -match "(protocol|workflow|guardrail|policy|handoff|runbook)") { return "project_protocol" }
    if ($lower -match "(^|\\)(package\.json|pnpm-lock\.yaml|package-lock\.json|yarn\.lock|pyproject\.toml|requirements\.txt|makefile|dockerfile|docker-compose\.ya?ml|vite\.config\.|next\.config\.|tsconfig\.json)") { return "package_or_build_file" }
    if ($lower -match "(^|\\)(config|configs|\.config)\\|\.config\.|\.ya?ml$|\.toml$|\.ini$|\.json$") { return "config" }
    if ($lower -match "^(data|datasets|sample-data|sample_data|fixtures)\\") { return "data_file" }
    if ($lower -match "^(dist|build|out|coverage|reports|generated|artifacts|\.next)\\") { return "generated_artifact_file" }
    if ($lower -match "(^|\\)(src|app|pages)\\(index|main|app|server)\.") { return "likely_app_entrypoint" }
    if ($lower -match "(^|\\)(test|tests|__tests__)\\(index|setup|runner)\.") { return "likely_test_entrypoint" }
    if ($name -match "^(README|CHANGELOG|CONTRIBUTING|LICENSE)") { return "important_doc" }

    return "other"
}

function Get-OnboardingTextTerms {
    param([string]$Value)

    $terms = [System.Collections.Generic.List[string]]::new()
    $normalized = ([string]$Value).Trim().ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($normalized)) {
        $terms.Add($normalized) | Out-Null
    }

    foreach ($part in ($normalized -split "[^a-z0-9]+")) {
        if ($part.Length -ge 3 -and -not $terms.Contains($part)) {
            $terms.Add($part) | Out-Null
        }
    }

    return @($terms)
}

function Test-OnboardingTextFile {
    param([System.IO.FileInfo]$File)

    if ($File.Length -gt $MaxBytesPerFile) {
        return $false
    }

    $name = $File.Name.ToLowerInvariant()
    if ($name -match "^\.env($|\.)|secret|credential|token|private|\.pem$|\.pfx$|id_rsa") {
        return $false
    }

    $extension = $File.Extension.ToLowerInvariant()
    $allowedExtensions = @(
        ".md", ".txt", ".ps1", ".psm1", ".js", ".jsx", ".ts", ".tsx", ".json",
        ".yml", ".yaml", ".html", ".css", ".scss", ".py", ".cs", ".go", ".rs",
        ".java", ".rb", ".php", ".toml", ".xml", ".sql", ".csv", ".ini", ".sh",
        ".cmd", ".bat"
    )

    return ($allowedExtensions -contains $extension)
}

function Get-OnboardingExcludedDirectoryNames {
    return @(
        ".git",
        ".venv",
        "venv",
        "env",
        "node_modules",
        "vendor",
        "dist",
        "build",
        "out",
        ".next",
        "coverage",
        "htmlcov",
        "reports",
        "cache",
        "caches",
        ".cache",
        "__pycache__",
        ".pytest_cache",
        ".ruff_cache",
        ".mypy_cache",
        ".tox",
        ".nox",
        ".turbo",
        ".parcel-cache",
        ".gradle",
        "target",
        "tmp",
        "temp",
        ".codex-local"
    )
}

function Get-OnboardingRepoItems {
    param([string]$RootPath)

    $excludedDirectoryNames = @(Get-OnboardingExcludedDirectoryNames)

    $directories = [System.Collections.Generic.List[object]]::new()
    $excludedDirectories = [System.Collections.Generic.List[object]]::new()
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue((Get-Item -LiteralPath $RootPath))
    $truncated = $false

    while ($queue.Count -gt 0 -and $files.Count -lt $MaxFiles) {
        $directory = $queue.Dequeue()
        $children = @(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue)
        foreach ($child in $children) {
            if ($child.PSIsContainer) {
                $relativeDir = Get-OnboardingRelativePath -BasePath $RootPath -Path $child.FullName
                $directories.Add([pscustomobject]@{
                    full_path     = $child.FullName
                    relative_path = $relativeDir
                    name          = $child.Name
                }) | Out-Null

                if ($excludedDirectoryNames -contains $child.Name.ToLowerInvariant()) {
                    $excludedDirectories.Add([pscustomobject]@{
                        full_path     = $child.FullName
                        relative_path = $relativeDir
                        name          = $child.Name
                    }) | Out-Null
                    continue
                }

                $queue.Enqueue($child)
            } else {
                $files.Add($child) | Out-Null
                if ($files.Count -ge $MaxFiles) {
                    $truncated = $true
                    break
                }
            }
        }
    }

    [pscustomobject]@{
        files                = @($files)
        directories          = @($directories)
        excluded_directories = @($excludedDirectories)
        truncated            = $truncated
    }
}

function Get-OnboardingGitSummary {
    param([string]$RootPath)

    $summary = [ordered]@{
        is_git_repo                 = $false
        repo_root                   = ""
        branch                      = ""
        head                        = ""
        status_short                = @()
        remotes_known_locally       = @()
        remote_status_checked_local = $false
        notes                       = @()
    }

    try {
        $repoRootOutput = @(git -C $RootPath rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -ne 0 -or $repoRootOutput.Count -eq 0) {
            $summary.notes = @("not_git_repo")
            return [pscustomobject]$summary
        }

        $summary.is_git_repo = $true
        $summary.repo_root = [string]$repoRootOutput[0]
        $summary.branch = [string](@(git -C $RootPath branch --show-current 2>$null) | Select-Object -First 1)
        $summary.head = [string](@(git -C $RootPath rev-parse --short HEAD 2>$null) | Select-Object -First 1)
        $summary.status_short = @(git -C $RootPath status --short 2>$null)
        $summary.remotes_known_locally = @(git -C $RootPath remote -v 2>$null | Select-Object -Unique)
        $summary.remote_status_checked_local = $true
        if ($summary.status_short.Count -eq 0) {
            $summary.notes = @("clean")
        } else {
            $summary.notes = @("dirty_or_untracked")
        }
    } catch {
        $summary.notes = @("git_status_unavailable: $($_.Exception.Message)")
    }

    return [pscustomobject]$summary
}

function Get-OnboardingPackageScripts {
    param([string]$RootPath)

    $packagePath = Join-Path $RootPath "package.json"
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        return @()
    }

    try {
        $packageJson = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
        if (-not $packageJson.scripts) {
            return @()
        }

        $rows = @()
        foreach ($property in $packageJson.scripts.PSObject.Properties) {
            $rows += [pscustomobject]@{
                name    = $property.Name
                command = [string]$property.Value
            }
        }

        return $rows
    } catch {
        return @([pscustomobject]@{
            name    = "package_json_parse_error"
            command = $_.Exception.Message
        })
    }
}

function Add-OnboardingInventoryRow {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$AssetPath,
        [string]$AssetType,
        [string]$MatchedTerms,
        [string]$ApparentPurpose,
        [string]$Notes = ""
    )

    $Rows.Add((New-OnboardingRow -AssetPath $AssetPath -AssetType $AssetType -MatchedTerms $MatchedTerms -ApparentPurpose $ApparentPurpose -Notes $Notes)) | Out-Null
}

function Get-OnboardingReuseDecision {
    param([string]$Classification)

    switch ($Classification) {
        "already_exists_operational" { return "REUSE" }
        "exists_partial" { return "EXTEND_EXISTING" }
        "exists_docs_only" { return "DOCUMENT_EXISTING" }
        "exists_test_only" { return "VALIDATE_EXISTING" }
        "exists_wrong_scope" { return "ADAPTER_NEEDED" }
        "exists_stale" { return "VALIDATE_EXISTING" }
        "exists_conflicting" { return "STOP" }
        "exists_duplicate" { return "STOP" }
        "not_found" { return "NEW_BUILD_MAY_BE_NEEDED_LATER" }
        default { return "VALIDATE_EXISTING" }
    }
}

function Get-OnboardingFindingClassification {
    param(
        [string]$AssetType,
        [int]$OperationalHitCount
    )

    if ($AssetType -eq "important_doc" -or $AssetType -eq "project_protocol") {
        return "exists_docs_only"
    }

    if ($AssetType -eq "test" -or $AssetType -eq "likely_test_entrypoint") {
        return "exists_test_only"
    }

    if ($AssetType -eq "generated_artifact_file") {
        return "exists_stale"
    }

    if ($AssetType -eq "script_or_tool" -or $AssetType -eq "package_or_build_file" -or $AssetType -eq "likely_app_entrypoint" -or $AssetType -eq "config") {
        if ($OperationalHitCount -gt 1) {
            return "exists_duplicate"
        }

        return "already_exists_operational"
    }

    return "exists_partial"
}

function Get-OnboardingMatchedLine {
    param(
        [string[]]$Lines,
        [string[]]$Terms
    )

    foreach ($line in $Lines) {
        $lower = $line.ToLowerInvariant()
        foreach ($term in $Terms) {
            if ($lower.Contains($term)) {
                return ($line.Trim() -replace "\s+", " ")
            }
        }
    }

    return ""
}

function Add-OnboardingOpportunity {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Id,
        [string]$Area,
        [string]$Evidence,
        [string]$Assets,
        [string]$Risk,
        [string]$SuggestedNextStep,
        [string]$WhyNoCoding
    )

    $Rows.Add([pscustomobject]@{
        opportunity_id          = $Id
        area                    = $Area
        evidence                = $Evidence
        existing_assets_involved = $Assets
        risk                    = $Risk
        suggested_next_step     = $SuggestedNextStep
        coding_allowed_now      = "false"
        why_or_why_not          = $WhyNoCoding
    }) | Out-Null
}

function Export-OnboardingCsv {
    param(
        [object[]]$Rows,
        [string]$Path,
        [hashtable]$Placeholder
    )

    $outputRows = @($Rows)
    if ($outputRows.Count -eq 0 -and $null -ne $Placeholder) {
        $outputRows = @([pscustomobject]$Placeholder)
    }

    $outputRows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$resolvedRepo = Resolve-Path -LiteralPath $Repo -ErrorAction Stop
$repoPath = $resolvedRepo.Path
if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
    throw "Repo must be an existing directory: $Repo"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Split-Path -Leaf $repoPath
}

$slug = ConvertTo-OnboardingSlug $ProjectName
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $OutDirectory = Join-Path $fleetRoot "fleet\status\repo-onboarding\$slug"
}

$outPath = Get-OnboardingFullPath $OutDirectory
if (Test-OnboardingPathInside -ChildPath $outPath -ParentPath $repoPath) {
    throw "OutDirectory must be outside the target repo so the inventory adapter remains read-only for that repo."
}

New-Item -ItemType Directory -Force -Path $outPath | Out-Null

$items = Get-OnboardingRepoItems -RootPath $repoPath
$files = @($items.files)
$directories = @($items.directories)
$excludedDirectories = @($items.excluded_directories)
$gitSummary = Get-OnboardingGitSummary -RootPath $repoPath
$packageScripts = @(Get-OnboardingPackageScripts -RootPath $repoPath)

$inventoryRows = [System.Collections.Generic.List[object]]::new()

foreach ($topLevelItem in @(Get-ChildItem -LiteralPath $repoPath -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $itemType = if ($topLevelItem.PSIsContainer) { "top_level_directory" } else { "top_level_file" }
    if ($topLevelItem.PSIsContainer -and (@(Get-OnboardingExcludedDirectoryNames) -contains $topLevelItem.Name.ToLowerInvariant())) {
        $itemType = "excluded_directory"
    }
    $notes = if ($itemType -eq "excluded_directory") { "not_traversed_by_onboarding_scanner" } else { "" }
    Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath $topLevelItem.Name -AssetType $itemType -MatchedTerms "top-level" -ApparentPurpose "Top-level repo structure item" -Notes $notes
}

foreach ($directory in $excludedDirectories) {
    if ($directory.relative_path -ne $directory.name) {
        Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath $directory.relative_path -AssetType "excluded_directory" -MatchedTerms "excluded" -ApparentPurpose "Excluded cache, dependency, virtual environment, or generated folder" -Notes "not_traversed_by_onboarding_scanner"
    }
}

foreach ($file in $files) {
    $relative = Get-OnboardingRelativePath -BasePath $repoPath -Path $file.FullName
    $assetType = Get-OnboardingAssetType -RelativePath $relative
    if ($assetType -eq "other") {
        continue
    }

    Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath $relative -AssetType $assetType -MatchedTerms $assetType -ApparentPurpose "Repo onboarding inventory candidate" -Notes "size_bytes=$($file.Length)"
}

$dataDirectories = @($directories | Where-Object { $_.relative_path.ToLowerInvariant() -match "^(data|datasets|sample-data|sample_data|fixtures)(\\|$)" })
foreach ($directory in $dataDirectories) {
    Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath $directory.relative_path -AssetType "data_folder" -MatchedTerms "data" -ApparentPurpose "Data or fixture folder" -Notes "folder_only"
}

$artifactDirectories = @($directories | Where-Object { $_.relative_path.ToLowerInvariant() -match "^(dist|build|out|coverage|reports|generated|artifacts|\.next)(\\|$)" })
foreach ($directory in $artifactDirectories) {
    Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath $directory.relative_path -AssetType "generated_artifact_folder" -MatchedTerms "generated;artifact" -ApparentPurpose "Generated or artifact folder" -Notes "folder_only"
}

foreach ($script in $packageScripts) {
    Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath "package.json#scripts.$($script.name)" -AssetType "likely_test_entrypoint" -MatchedTerms "package-script" -ApparentPurpose "Package script entrypoint" -Notes $script.command
}

$gitStatusText = if ($gitSummary.status_short.Count -gt 0) { ($gitSummary.status_short -join " | ") } else { ($gitSummary.notes -join " | ") }
Add-OnboardingInventoryRow -Rows $inventoryRows -AssetPath ".git" -AssetType "git_status_summary" -MatchedTerms "git;status" -ApparentPurpose "Current git status summary" -Notes $gitStatusText

$riskRows = [System.Collections.Generic.List[object]]::new()
foreach ($file in $files) {
    $relative = Get-OnboardingRelativePath -BasePath $repoPath -Path $file.FullName
    $lower = $relative.ToLowerInvariant()
    if ($lower -match "(^|\\)\.env($|\.)|secret|credential|token|private|deploy|migration|schema|auth|payment") {
        Add-OnboardingInventoryRow -Rows $riskRows -AssetPath $relative -AssetType "risk_area" -MatchedTerms "secret/deploy/migration/auth/payment" -ApparentPurpose "Obvious risk area requiring source trace before coding" -Notes "listed only; content not read when sensitive"
    }
}
foreach ($row in $riskRows) {
    $inventoryRows.Add($row) | Out-Null
}

$terms = @(Get-OnboardingTextTerms -Value $RequestedCapability)
$featureRows = [System.Collections.Generic.List[object]]::new()
$rawHits = [System.Collections.Generic.List[object]]::new()

if ($terms.Count -eq 0) {
    $classification = "not_found"
    $featureRows.Add([pscustomobject]@{
        feature_or_workflow = ""
        asset_path          = "_requested_capability_not_provided"
        asset_type          = "not_applicable"
        matched_terms       = ""
        evidence            = "No requested capability was provided."
        classification      = $classification
        reuse_decision      = Get-OnboardingReuseDecision -Classification $classification
        notes               = "Run again with -RequestedCapability to perform duplicate-tool detection."
    }) | Out-Null
} else {
    foreach ($file in $files) {
        if (-not (Test-OnboardingTextFile -File $file)) {
            continue
        }

        $relative = Get-OnboardingRelativePath -BasePath $repoPath -Path $file.FullName
        $text = ""
        try {
            $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        } catch {
            continue
        }

        $lowerText = $text.ToLowerInvariant()
        $matched = @($terms | Where-Object { $lowerText.Contains($_) })
        if ($matched.Count -eq 0) {
            continue
        }

        $assetType = Get-OnboardingAssetType -RelativePath $relative
        $rawHits.Add([pscustomobject]@{
            asset_path    = $relative
            asset_type    = $assetType
            matched_terms = ($matched -join ";")
            evidence      = Get-OnboardingMatchedLine -Lines ($text -split "`r?`n") -Terms $matched
        }) | Out-Null
    }

    foreach ($script in $packageScripts) {
        $scriptText = ("$($script.name) $($script.command)").ToLowerInvariant()
        $matched = @($terms | Where-Object { $scriptText.Contains($_) })
        if ($matched.Count -gt 0) {
            $rawHits.Add([pscustomobject]@{
                asset_path    = "package.json#scripts.$($script.name)"
                asset_type    = "package_or_build_file"
                matched_terms = ($matched -join ";")
                evidence      = "$($script.name): $($script.command)"
            }) | Out-Null
        }
    }

    $operationalHitCount = @($rawHits | Where-Object {
        $_.asset_type -eq "script_or_tool" -or
        $_.asset_type -eq "package_or_build_file" -or
        $_.asset_type -eq "likely_app_entrypoint" -or
        $_.asset_type -eq "config"
    }).Count

    if ($rawHits.Count -eq 0) {
        $classification = "not_found"
        $featureRows.Add([pscustomobject]@{
            feature_or_workflow = $RequestedCapability
            asset_path          = "_no_matches"
            asset_type          = "not_found"
            matched_terms       = ($terms -join ";")
            evidence            = "No existing feature, tool, workflow, doc, or test match found in scanned files."
            classification      = $classification
            reuse_decision      = Get-OnboardingReuseDecision -Classification $classification
            notes               = "Coding is still not approved by this packet; source trace only supports a future bounded proposal."
        }) | Out-Null
    } else {
        foreach ($hit in $rawHits) {
            $classification = Get-OnboardingFindingClassification -AssetType $hit.asset_type -OperationalHitCount $operationalHitCount
            $featureRows.Add([pscustomobject]@{
                feature_or_workflow = $RequestedCapability
                asset_path          = $hit.asset_path
                asset_type          = $hit.asset_type
                matched_terms       = $hit.matched_terms
                evidence            = $hit.evidence
                classification      = $classification
                reuse_decision      = Get-OnboardingReuseDecision -Classification $classification
                notes               = "Read-only finding; do not rebuild without comparing behavior and boundaries."
            }) | Out-Null
        }
    }
}

$opportunities = [System.Collections.Generic.List[object]]::new()
$opportunityIndex = 1

$hasReadme = @($inventoryRows | Where-Object { $_.asset_path -match "(^|\\)README(\.|$)" -or $_.asset_path -match "^README" }).Count -gt 0
if (-not $hasReadme) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "docs" -Evidence "No README detected in scanned inventory." -Assets "repo root" -Risk "New Codex runs may lack orientation." -SuggestedNextStep "Create a docs-only proposal after Tim approves product-repo mutation." -WhyNoCoding "This onboarding packet is source trace only."
    $opportunityIndex++
}

$hasTests = @($inventoryRows | Where-Object { $_.asset_type -eq "test" -or $_.asset_type -eq "likely_test_entrypoint" }).Count -gt 0
if (-not $hasTests) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "validation" -Evidence "No test folders, test files, or test entrypoints detected." -Assets "tests/package scripts" -Risk "Future implementation lanes may be hard to verify." -SuggestedNextStep "Ask for a bounded validation lane after source trace review." -WhyNoCoding "No coding is approved during onboarding."
    $opportunityIndex++
}

$hasCi = @($inventoryRows | Where-Object { $_.asset_type -eq "ci_workflow" }).Count -gt 0
if (-not $hasCi) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "ci" -Evidence "No CI workflow detected under .github/workflows." -Assets ".github/workflows" -Risk "Reviewers may need manual validation steps." -SuggestedNextStep "Document current manual validation first; automate only after approval." -WhyNoCoding "Source trace cannot approve workflow changes."
    $opportunityIndex++
}

$operationalFindings = @($featureRows | Where-Object { $_.classification -eq "already_exists_operational" -or $_.classification -eq "exists_duplicate" })
if ($terms.Count -gt 0 -and $operationalFindings.Count -eq 0) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "feature_trace" -Evidence "Requested capability found no operational implementation." -Assets ($featureRows.asset_path -join "; ") -Risk "A future build may be needed, but only after source trace review." -SuggestedNextStep "Create a bounded implementation proposal that cites this packet." -WhyNoCoding "Default is no coding until Tim approves a build lane."
    $opportunityIndex++
}

if (@($featureRows | Where-Object { $_.classification -eq "exists_duplicate" }).Count -gt 0) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "duplicate_prevention" -Evidence "Multiple operational matches for requested capability." -Assets (($featureRows | Where-Object { $_.classification -eq "exists_duplicate" }).asset_path -join "; ") -Risk "Parallel tools can diverge if new work rebuilds instead of reusing." -SuggestedNextStep "Stop rebuild work and choose a reuse/merge path." -WhyNoCoding "Duplicate resolution needs human-scoped follow-up."
    $opportunityIndex++
}

if ($riskRows.Count -gt 0) {
    Add-OnboardingOpportunity -Rows $opportunities -Id ("OPP-{0:D3}" -f $opportunityIndex) -Area "boundary" -Evidence "$($riskRows.Count) obvious risk-area paths detected." -Assets (($riskRows | Select-Object -First 12).asset_path -join "; ") -Risk "Secrets, deploy, migration, auth, or payment boundaries may apply." -SuggestedNextStep "Require explicit Tim approval before touching any listed risk area." -WhyNoCoding "Risk-area evidence creates stop conditions, not permission."
    $opportunityIndex++
}

if ($opportunities.Count -eq 0) {
    Add-OnboardingOpportunity -Rows $opportunities -Id "OPP-001" -Area "follow_up" -Evidence "No obvious docs, validation, CI, duplicate, or risk-area gap was detected by the read-only scan." -Assets "repo inventory" -Risk "Automated heuristics can miss domain-specific gaps." -SuggestedNextStep "Review packet manually before approving any product-repo change." -WhyNoCoding "Onboarding remains review-only."
}

$inventoryPath = Join-Path $outPath "repo_inventory.csv"
$featurePath = Join-Path $outPath "existing_feature_scan.csv"
$opportunityPath = Join-Path $outPath "improvement_opportunities.csv"
$handoffPath = Join-Path $outPath "onboarding_handoff.md"
$reviewPath = Join-Path $outPath "repo_onboarding_review.md"
$validationPath = Join-Path $outPath "repo_onboarding_validation.json"
$repoIdentityPath = Join-Path $outPath "repo_identity.json"
$baselinePath = Join-Path $outPath "repo_baseline_status.txt"
$assetTracePath = Join-Path $outPath "repo_existing_asset_trace.csv"
$structureInventoryPath = Join-Path $outPath "repo_structure_inventory.csv"
$docsInventoryPath = Join-Path $outPath "repo_docs_inventory.csv"
$testsCommandsInventoryPath = Join-Path $outPath "repo_tests_commands_inventory.csv"
$dataSourceInventoryPath = Join-Path $outPath "repo_data_source_inventory.csv"
$riskSurfacePath = Join-Path $outPath "repo_risk_surface_register.csv"
$reuseDecisionMatrixPath = Join-Path $outPath "repo_reuse_decision_matrix.csv"
$improvementQueuePath = Join-Path $outPath "repo_improvement_queue.csv"
$summaryPath = Join-Path $outPath "REPO_ONBOARDING_SUMMARY.md"

$safeCommandList = @(
    "git -C <repo> rev-parse --show-toplevel",
    "git -C <repo> branch --show-current",
    "git -C <repo> rev-parse --short HEAD",
    "git -C <repo> status --short",
    "git -C <repo> remote -v",
    "read-only file and folder inventory",
    "read bounded text files under the target repo"
)
$forbiddenCommandList = @(
    "git fetch/pull/push/merge/reset",
    "package install commands",
    "deploy commands",
    "migration commands",
    "secret/auth/payment mutation",
    "all-fleet commands",
    "proof runs",
    "background or overnight runners",
    "product repo mutation during onboarding"
)

$repoIdentity = [ordered]@{
    schema_version              = 1
    packet_type                 = "tsf_repo_onboarding"
    created_at_utc             = (Get-Date).ToUniversalTime().ToString("o")
    project_name               = $ProjectName
    repo_path                  = $repoPath
    requested_capability       = $RequestedCapability
    output_path                = $outPath
    max_files                  = $MaxFiles
    max_files_behavior         = "Scanner stops recursive file collection at MaxFiles and records scan_truncated=true when the cap is reached."
    excluded_directory_names   = @(Get-OnboardingExcludedDirectoryNames)
    excluded_directories       = @($excludedDirectories.relative_path)
    phase0_control_rule        = "Research first. Source trace first. Code second."
    lane_scope_declaration     = [ordered]@{
        lane_type                                = "repo_onboarding_read_only"
        allowed_search_scope                     = @($repoPath, $outPath)
        forbidden_search_scope                   = @("canonical NWR", "normal NWR packets", "PrivateLens", "secrets/auth/payments", "deploy/install/migration", "push/merge/remote fetch or pull", "all-fleet commands", "proof runs", "background or overnight runners")
        canonical_repo_inspection_allowed        = $false
        normal_nwr_packet_reads_allowed          = $false
        cross_lane_comparison_allowed            = $false
        product_repo_mutation_allowed            = $false
        tim_approval_required_for_scope_expansion = $true
    }
    safe_command_list           = $safeCommandList
    forbidden_command_list      = $forbiddenCommandList
    no_build_without_trace_rule = $true
    output_inside_target_repo   = (Test-OnboardingPathInside -ChildPath $outPath -ParentPath $repoPath)
}

$structureRows = @($inventoryRows | Where-Object {
    $_.asset_type -eq "top_level_directory" -or
    $_.asset_type -eq "top_level_file" -or
    $_.asset_type -eq "likely_app_entrypoint" -or
    $_.asset_type -eq "git_status_summary"
})
$docsRows = @($inventoryRows | Where-Object {
    $_.asset_type -eq "important_doc" -or
    $_.asset_type -eq "project_protocol"
})
$testCommandRows = @($inventoryRows | Where-Object {
    $_.asset_type -eq "test" -or
    $_.asset_type -eq "likely_test_entrypoint" -or
    $_.asset_path -match "^package\.json#scripts\."
})
$dataRows = @($inventoryRows | Where-Object {
    $_.asset_type -eq "data_file" -or
    $_.asset_type -eq "data_folder" -or
    $_.asset_type -eq "config"
})
$reuseRows = @($featureRows | ForEach-Object {
    [pscustomobject]@{
        requested_capability      = $_.feature_or_workflow
        asset_path                = $_.asset_path
        classification            = $_.classification
        reuse_decision            = $_.reuse_decision
        new_build_allowed_now     = "false"
        why_new_build_is_blocked  = "Repo onboarding is source trace only; future build work needs a bounded lane and Tim-approved scope."
        evidence                  = $_.evidence
    }
})
$queueRows = @($opportunities | ForEach-Object {
    [pscustomobject]@{
        queue_id                  = $_.opportunity_id
        classification            = "REVIEW_ONLY_CANDIDATE"
        area                      = $_.area
        evidence                  = $_.evidence
        existing_assets_involved  = $_.existing_assets_involved
        risk                      = $_.risk
        suggested_next_step       = $_.suggested_next_step
        coding_allowed_now        = $_.coding_allowed_now
        phase0_required_next      = "true"
        tim_approval_required     = "true"
    }
})

$repoIdentity | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $repoIdentityPath -Encoding UTF8

@(
    "Repo baseline status",
    "",
    "Project: $ProjectName",
    "Repo path: $repoPath",
    "Requested capability: $RequestedCapability",
    "Is git repo: $($gitSummary.is_git_repo)",
    "Repo root: $($gitSummary.repo_root)",
    "Branch: $($gitSummary.branch)",
    "HEAD: $($gitSummary.head)",
    "Status short:",
    $(if ($gitSummary.status_short.Count -eq 0) { "  clean" } else { @($gitSummary.status_short | ForEach-Object { "  $_" }) }),
    "Remotes known locally only:",
    $(if ($gitSummary.remotes_known_locally.Count -eq 0) { "  none" } else { @($gitSummary.remotes_known_locally | ForEach-Object { "  $_" }) }),
    "No fetch, pull, push, merge, install, deploy, migration, proof run, all-fleet command, or background runner was performed."
) | Set-Content -LiteralPath $baselinePath -Encoding UTF8

Export-OnboardingCsv -Rows $inventoryRows -Path $inventoryPath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "none"; matched_terms = ""; apparent_purpose = "No inventory rows produced."; notes = "" })
Export-OnboardingCsv -Rows $featureRows -Path $featurePath -Placeholder ([ordered]@{ feature_or_workflow = $RequestedCapability; asset_path = "_none"; asset_type = "none"; matched_terms = ""; evidence = "No trace rows produced."; classification = "not_found"; reuse_decision = "NEW_BUILD_MAY_BE_NEEDED_LATER"; notes = "" })
Export-OnboardingCsv -Rows $opportunities -Path $opportunityPath -Placeholder ([ordered]@{ opportunity_id = "OPP-000"; area = "none"; evidence = "No opportunities produced."; existing_assets_involved = ""; risk = ""; suggested_next_step = "Review manually."; coding_allowed_now = "false"; why_or_why_not = "Onboarding never approves coding." })
Export-OnboardingCsv -Rows $featureRows -Path $assetTracePath -Placeholder ([ordered]@{ feature_or_workflow = $RequestedCapability; asset_path = "_none"; asset_type = "none"; matched_terms = ""; evidence = "No trace rows produced."; classification = "not_found"; reuse_decision = "NEW_BUILD_MAY_BE_NEEDED_LATER"; notes = "" })
Export-OnboardingCsv -Rows $structureRows -Path $structureInventoryPath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "none"; matched_terms = ""; apparent_purpose = "No structure rows produced."; notes = "" })
Export-OnboardingCsv -Rows $docsRows -Path $docsInventoryPath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "none"; matched_terms = ""; apparent_purpose = "No docs found."; notes = "" })
Export-OnboardingCsv -Rows $testCommandRows -Path $testsCommandsInventoryPath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "none"; matched_terms = ""; apparent_purpose = "No tests or validation commands found."; notes = "" })
Export-OnboardingCsv -Rows $dataRows -Path $dataSourceInventoryPath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "none"; matched_terms = ""; apparent_purpose = "No data or source registry files found."; notes = "" })
Export-OnboardingCsv -Rows $riskRows -Path $riskSurfacePath -Placeholder ([ordered]@{ asset_path = "_none"; asset_type = "risk_area"; matched_terms = ""; apparent_purpose = "No obvious risk surfaces detected."; notes = "review manually" })
Export-OnboardingCsv -Rows $reuseRows -Path $reuseDecisionMatrixPath -Placeholder ([ordered]@{ requested_capability = $RequestedCapability; asset_path = "_none"; classification = "not_found"; reuse_decision = "NEW_BUILD_MAY_BE_NEEDED_LATER"; new_build_allowed_now = "false"; why_new_build_is_blocked = "Onboarding is source trace only."; evidence = "" })
Export-OnboardingCsv -Rows $queueRows -Path $improvementQueuePath -Placeholder ([ordered]@{ queue_id = "OPP-000"; classification = "REVIEW_ONLY_CANDIDATE"; area = "none"; evidence = "No opportunities produced."; existing_assets_involved = ""; risk = ""; suggested_next_step = "Review manually."; coding_allowed_now = "false"; phase0_required_next = "true"; tim_approval_required = "true" })

$doNotRebuild = @($featureRows | Where-Object {
    $_.classification -eq "already_exists_operational" -or
    $_.classification -eq "exists_duplicate" -or
    $_.classification -eq "exists_partial" -or
    $_.classification -eq "exists_docs_only" -or
    $_.classification -eq "exists_test_only"
} | Select-Object -First 20)

$handoffLines = [System.Collections.Generic.List[string]]::new()
$handoffLines.Add("# Repo Onboarding Handoff - $ProjectName") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("Evidence only; not executable authority or product-repo mutation approval.") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add(('- Repo scanned: `{0}`' -f $repoPath)) | Out-Null
$handoffLines.Add(('- Requested capability/workflow: `{0}`' -f $RequestedCapability)) | Out-Null
$handoffLines.Add(('- Output packet: `{0}`' -f $outPath)) | Out-Null
$handoffLines.Add("- Files scanned: $($files.Count)") | Out-Null
$handoffLines.Add("- Directories noted: $($directories.Count)") | Out-Null
$handoffLines.Add("- Scan truncated: $($items.truncated)") | Out-Null
$handoffLines.Add("- Git status: $gitStatusText") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## What Was Scanned") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("Top-level structure, important docs, scripts/tools, tests, configs, package/build files, CI workflows, data folders, generated/artifact folders, project protocols, likely app/test entrypoints, current git status, and obvious risk paths.") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## What Already Exists") | Out-Null
$handoffLines.Add("") | Out-Null
foreach ($finding in ($featureRows | Select-Object -First 20)) {
    $handoffLines.Add(('- `{0}` / `{1}`: `{2}` - {3}' -f $finding.classification, $finding.reuse_decision, $finding.asset_path, $finding.evidence)) | Out-Null
}
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## What Should Not Be Rebuilt") | Out-Null
$handoffLines.Add("") | Out-Null
if ($doNotRebuild.Count -eq 0) {
    $handoffLines.Add("- No reusable implementation was proven by the detector; future build work still needs Tim approval.") | Out-Null
} else {
    foreach ($finding in $doNotRebuild) {
        $handoffLines.Add(('- Do not rebuild `{0}` before reviewing `{1}` (`{2}`).' -f $finding.feature_or_workflow, $finding.asset_path, $finding.classification)) | Out-Null
    }
}
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## Gaps Remaining") | Out-Null
$handoffLines.Add("") | Out-Null
foreach ($opportunity in ($opportunities | Select-Object -First 20)) {
    $handoffLines.Add(('- `{0}` `{1}`: {2} Suggested next step: {3}' -f $opportunity.opportunity_id, $opportunity.area, $opportunity.evidence, $opportunity.suggested_next_step)) | Out-Null
}
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## Safe Future Lanes") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("- TSF-local review of this packet.") | Out-Null
$handoffLines.Add("- Docs-only clarification inside TSF about the onboarding packet.") | Out-Null
$handoffLines.Add("- A future product-repo lane only after Tim approves exact scope.") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## Requires Tim Approval") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("- Product repo mutation, installs, migrations, secrets, push, merge, deploy, proof runs, all-fleet commands, background runners, or risk-area edits.") | Out-Null
$handoffLines.Add("- Any decision to implement gaps found by this review packet.") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("## Product Repo Boundaries") | Out-Null
$handoffLines.Add("") | Out-Null
$handoffLines.Add("This adapter reads the target repo and writes only the configured output directory. The output directory is rejected when it is inside the scanned target repo.") | Out-Null
$handoffLines | Set-Content -LiteralPath $handoffPath -Encoding UTF8

$reviewLines = [System.Collections.Generic.List[string]]::new()
$reviewLines.Add("# Repo Onboarding Review - $ProjectName") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add("Evidence only; not executable authority or product-repo mutation approval.") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add("## Summary") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add(('- Repo scanned: `{0}`' -f $repoPath)) | Out-Null
$reviewLines.Add(('- Requested capability/workflow: `{0}`' -f $RequestedCapability)) | Out-Null
$reviewLines.Add(('- Output directory: `{0}`' -f $outPath)) | Out-Null
$reviewLines.Add("- Files scanned: $($files.Count)") | Out-Null
$reviewLines.Add("- Scan truncated: $($items.truncated)") | Out-Null
$reviewLines.Add("- Git: $gitStatusText") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add("## Output Artifacts") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add('- `repo_identity.json`') | Out-Null
$reviewLines.Add('- `repo_baseline_status.txt`') | Out-Null
$reviewLines.Add('- `repo_existing_asset_trace.csv`') | Out-Null
$reviewLines.Add('- `repo_structure_inventory.csv`') | Out-Null
$reviewLines.Add('- `repo_docs_inventory.csv`') | Out-Null
$reviewLines.Add('- `repo_tests_commands_inventory.csv`') | Out-Null
$reviewLines.Add('- `repo_data_source_inventory.csv`') | Out-Null
$reviewLines.Add('- `repo_risk_surface_register.csv`') | Out-Null
$reviewLines.Add('- `repo_reuse_decision_matrix.csv`') | Out-Null
$reviewLines.Add('- `repo_improvement_queue.csv`') | Out-Null
$reviewLines.Add('- `REPO_ONBOARDING_SUMMARY.md`') | Out-Null
$reviewLines.Add('- `repo_inventory.csv`') | Out-Null
$reviewLines.Add('- `existing_feature_scan.csv`') | Out-Null
$reviewLines.Add('- `improvement_opportunities.csv`') | Out-Null
$reviewLines.Add('- `onboarding_handoff.md`') | Out-Null
$reviewLines.Add('- `repo_onboarding_validation.json`') | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add("## Existing Feature / Duplicate Detector") | Out-Null
$reviewLines.Add("") | Out-Null
foreach ($finding in ($featureRows | Select-Object -First 20)) {
    $reviewLines.Add(('- `{0}` / `{1}`: `{2}` - {3}' -f $finding.classification, $finding.reuse_decision, $finding.asset_path, $finding.evidence)) | Out-Null
}
$reviewLines.Add("") | Out-Null
$reviewLines.Add("## Improvement Opportunities") | Out-Null
$reviewLines.Add("") | Out-Null
foreach ($opportunity in ($opportunities | Select-Object -First 20)) {
    $reviewLines.Add(('- `{0}` `{1}`: {2} Coding allowed now: `{3}`.' -f $opportunity.opportunity_id, $opportunity.area, $opportunity.evidence, $opportunity.coding_allowed_now)) | Out-Null
}
$reviewLines.Add("") | Out-Null
$reviewLines.Add("## Stop Before Mutation") | Out-Null
$reviewLines.Add("") | Out-Null
$reviewLines.Add("This packet is the review boundary before product-repo mutation. It does not approve coding, installs, migrations, push, merge, deploy, all-fleet commands, background runners, or secret access.") | Out-Null
$reviewLines | Set-Content -LiteralPath $reviewPath -Encoding UTF8

$summaryLines = [System.Collections.Generic.List[string]]::new()
$summaryLines.Add("# Repo Onboarding Summary - $ProjectName") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("Evidence only; not executable authority or product-repo mutation approval.") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Phase 0 Gate") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("Research first. Source trace first. Code second.") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add('- `lane_scope_declaration`: repo onboarding read-only') | Out-Null
$summaryLines.Add('- `allowed_search_scope`: target repo read-only scan plus TSF output packet') | Out-Null
$summaryLines.Add('- `forbidden_search_scope`: canonical NWR, normal NWR packets, PrivateLens, secrets/auth/payments, deploy/install/migration, push/merge/remote fetch or pull, all-fleet, proof runs, background runners') | Out-Null
$summaryLines.Add('- `existing_asset_trace`: `repo_existing_asset_trace.csv`') | Out-Null
$summaryLines.Add('- `reuse_decision`: `repo_reuse_decision_matrix.csv`') | Out-Null
$summaryLines.Add('- `build_permission`: no build is approved by onboarding') | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Repo Identity") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add(('- Repo path: `{0}`' -f $repoPath)) | Out-Null
$summaryLines.Add(('- Requested capability/workflow: `{0}`' -f $RequestedCapability)) | Out-Null
$summaryLines.Add(('- Output packet: `{0}`' -f $outPath)) | Out-Null
$summaryLines.Add(('- MaxFiles cap: `{0}`' -f $MaxFiles)) | Out-Null
$summaryLines.Add(('- Scan truncated: `{0}`' -f $items.truncated)) | Out-Null
$summaryLines.Add(('- Excluded directories noted: `{0}`' -f $excludedDirectories.Count)) | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Baseline") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add(('- Git repo: `{0}`' -f $gitSummary.is_git_repo)) | Out-Null
$summaryLines.Add(('- Branch: `{0}`' -f $gitSummary.branch)) | Out-Null
$summaryLines.Add(('- HEAD: `{0}`' -f $gitSummary.head)) | Out-Null
$summaryLines.Add(('- Dirty baseline: `{0}`' -f $gitStatusText)) | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Required Inventories") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add('- `repo_structure_inventory.csv`') | Out-Null
$summaryLines.Add('- `repo_docs_inventory.csv`') | Out-Null
$summaryLines.Add('- `repo_tests_commands_inventory.csv`') | Out-Null
$summaryLines.Add('- `repo_data_source_inventory.csv`') | Out-Null
$summaryLines.Add('- `repo_risk_surface_register.csv`') | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Do Not Rebuild Findings") | Out-Null
$summaryLines.Add("") | Out-Null
if ($doNotRebuild.Count -eq 0) {
    $summaryLines.Add("- No reusable implementation was proven by this packet; future work still needs Phase 0 and Tim-approved scope.") | Out-Null
} else {
    foreach ($finding in $doNotRebuild) {
        $summaryLines.Add(('- Do not rebuild `{0}` before reviewing `{1}` (`{2}`).' -f $finding.feature_or_workflow, $finding.asset_path, $finding.classification)) | Out-Null
    }
}
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Next Safe Queue") | Out-Null
$summaryLines.Add("") | Out-Null
foreach ($opportunity in ($queueRows | Select-Object -First 20)) {
    $summaryLines.Add(('- `{0}` `{1}`: {2} Coding allowed now: `{3}`.' -f $opportunity.queue_id, $opportunity.area, $opportunity.evidence, $opportunity.coding_allowed_now)) | Out-Null
}
$summaryLines.Add("") | Out-Null
$summaryLines.Add("## Stop Conditions") | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("- Stop before product repo mutation, installs, migrations, secrets, push, merge, deploy, all-fleet commands, proof runs, background runners, or risk-area edits.") | Out-Null
$summaryLines.Add('- Stop if a future lane needs a useful asset outside the declared scope and return `TIM_REQUIRED_SCOPE_EXPANSION`.') | Out-Null
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$requiredFiles = @(
    $repoIdentityPath,
    $baselinePath,
    $assetTracePath,
    $structureInventoryPath,
    $docsInventoryPath,
    $testsCommandsInventoryPath,
    $dataSourceInventoryPath,
    $riskSurfacePath,
    $reuseDecisionMatrixPath,
    $improvementQueuePath,
    $summaryPath,
    $inventoryPath,
    $featurePath,
    $opportunityPath,
    $handoffPath,
    $reviewPath,
    $validationPath
)

$validation = [ordered]@{
    verdict                     = "GREEN_REPO_ONBOARDING_PACKET_CREATED"
    output_path                 = $outPath
    tsf_repo                    = $fleetRoot
    target_repo                 = $repoPath
    project_name                = $ProjectName
    requested_capability        = $RequestedCapability
    files_scanned               = $files.Count
    directories_noted           = $directories.Count
    scan_truncated              = [bool]$items.truncated
    max_files                   = $MaxFiles
    max_files_behavior          = "Recursive file collection stops at MaxFiles; scan_truncated records whether the cap was reached."
    max_bytes_per_file          = $MaxBytesPerFile
    excluded_directory_names    = @(Get-OnboardingExcludedDirectoryNames)
    excluded_directories        = @($excludedDirectories.relative_path)
    excluded_directory_count    = $excludedDirectories.Count
    output_inside_target_repo   = (Test-OnboardingPathInside -ChildPath $outPath -ParentPath $repoPath)
    target_repo_mutated         = $false
    product_repos_mutated       = $false
    installs_run                = $false
    migrations_run              = $false
    push_merge_deploy_run       = $false
    all_fleet_run               = $false
    background_runners_started  = $false
    phase0_linkage_enforced     = $true
    lane_scope_declaration      = $repoIdentity.lane_scope_declaration
    allowed_search_scope        = $repoIdentity.lane_scope_declaration.allowed_search_scope
    forbidden_search_scope      = $repoIdentity.lane_scope_declaration.forbidden_search_scope
    existing_asset_trace        = [System.IO.Path]::GetFileName($assetTracePath)
    reuse_decision_matrix       = [System.IO.Path]::GetFileName($reuseDecisionMatrixPath)
    safe_command_list           = $safeCommandList
    forbidden_command_list      = $forbiddenCommandList
    dirty_worktree_baseline     = @($gitSummary.status_short)
    no_build_without_trace_rule = $true
    improvement_queue_classification = "REVIEW_ONLY_CANDIDATE"
    required_files_created      = @($requiredFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    git_summary                 = $gitSummary
    stop_conditions_hit         = @()
    confidence                  = "medium_high"
}

$validation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $validationPath -Encoding UTF8

Write-Host "Repo onboarding packet written: $outPath"
foreach ($path in $requiredFiles) {
    Write-Host " - $path"
}
