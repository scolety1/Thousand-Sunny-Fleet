[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",
    [string[]]$Project = @(),
    [string]$OutRoot = ".codex-local\audit-packages",
    [string]$AuditId = "",
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")

function Resolve-LocalPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Copy-IfPresent {
    param(
        [string]$Source,
        [string]$DestinationRoot,
        [string]$RelativePath,
        [System.Collections.Generic.List[object]]$Included
    )
    if (!(Test-Path -LiteralPath $Source)) { return }
    $destination = Join-Path $DestinationRoot $RelativePath
    $parent = Split-Path -Parent $destination
    if (![string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    $Included.Add([pscustomobject]@{ path = $RelativePath; sha256 = $hash }) | Out-Null
}

function Test-AuditAllowedEvidencePath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
    $normalized = $RelativePath -replace "\\", "/"
    if ($normalized -match "(^|/)\.\.(/|$)") { return $false }
    if ($normalized -match "(?i)(^|/)(\.env|node_modules|dist|build|\.git)(/|$)") { return $false }
    if ($normalized -match "(?i)(secret|token|credential|private[-_]?key)") { return $false }
    return $true
}

function ConvertTo-AuditEvidencePath {
    param([string]$RelativePath)
    return (($RelativePath -replace "^[A-Za-z]:", "") -replace "[\\/]+", "/").Trim("/")
}

function Get-AuditRelativePath {
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
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()) -replace "/", [System.IO.Path]::DirectorySeparatorChar
}

$configFullPath = Resolve-LocalPath $ConfigPath
if (!(Test-Path -LiteralPath $configFullPath)) { throw "Config not found: $configFullPath" }
$projects = @(Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
$selected = @($Project | ForEach-Object { [string]$_ } | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($selected.Count -gt 0) {
    $projects = @($projects | Where-Object { $selected -contains [string]$_.name })
}
if ($projects.Count -eq 0) { throw "No projects selected for audit package." }

if ([string]::IsNullOrWhiteSpace($AuditId)) {
    $AuditId = "audit-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}
$outFullRoot = Resolve-LocalPath $OutRoot
$packageRoot = Join-Path $outFullRoot $AuditId
if (Test-Path -LiteralPath $packageRoot) { throw "Audit package already exists: $packageRoot" }
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

$included = [System.Collections.Generic.List[object]]::new()
Copy-IfPresent -Source $configFullPath -DestinationRoot $packageRoot -RelativePath "fleet/projects.json" -Included $included

$shipEntries = @()
foreach ($shipConfig in $projects) {
    $name = [string]$shipConfig.name
    $repoValue = [string]$shipConfig.repo
    if ([string]::IsNullOrWhiteSpace($repoValue)) { throw "Project '$name' is missing repo path." }
    $repo = if ([System.IO.Path]::IsPathRooted($repoValue)) {
        [System.IO.Path]::GetFullPath($repoValue)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $repoValue))
    }
    $safeName = ConvertTo-FleetSafeFileName -Name $name
    $repoState = Get-FleetRepoState -Repo $repo
    $shipRoot = "ships/$safeName"
    if (Test-Path -LiteralPath $repo) {
        foreach ($relative in @("docs/codex/RUN_RESULT.json", "docs/codex/RUN_SUMMARY.md", "docs/codex/EVIDENCE_INDEX.md", "docs/codex/test-summary.md", "docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md", "docs/codex/MAGIC_SCORECARD.md")) {
            Copy-IfPresent -Source (Join-Path $repo $relative) -DestinationRoot $packageRoot -RelativePath (Join-Path $shipRoot $relative) -Included $included
        }
        $runResultPath = Join-Path $repo "docs/codex/RUN_RESULT.json"
        if (Test-Path -LiteralPath $runResultPath) {
            try {
                $runResult = Get-Content -LiteralPath $runResultPath -Raw | ConvertFrom-Json
                foreach ($item in @($runResult.evidence)) {
                    $evidencePath = [string]$item.path
                    if (Test-AuditAllowedEvidencePath -RelativePath $evidencePath) {
                        $source = Join-Path $repo $evidencePath
                        $safeEvidence = ConvertTo-AuditEvidencePath -RelativePath $evidencePath
                        Copy-IfPresent -Source $source -DestinationRoot $packageRoot -RelativePath (Join-Path $shipRoot "referenced-evidence/$safeEvidence") -Included $included
                    }
                }
                foreach ($check in @($runResult.checks)) {
                    foreach ($evidencePath in @($check.evidence)) {
                        if (Test-AuditAllowedEvidencePath -RelativePath ([string]$evidencePath)) {
                            $source = Join-Path $repo ([string]$evidencePath)
                            $safeEvidence = ConvertTo-AuditEvidencePath -RelativePath ([string]$evidencePath)
                            Copy-IfPresent -Source $source -DestinationRoot $packageRoot -RelativePath (Join-Path $shipRoot "referenced-evidence/$safeEvidence") -Included $included
                        }
                    }
                }
            } catch {
                $warningPath = Join-Path $packageRoot (Join-Path $shipRoot "run-result-read-warning.txt")
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $warningPath) | Out-Null
                Set-Content -Path $warningPath -Encoding UTF8 -Value "Unable to read RUN_RESULT evidence references: $($_.Exception.Message)"
                $included.Add([pscustomobject]@{ path = (Join-Path $shipRoot "run-result-read-warning.txt"); sha256 = (Get-FileHash -LiteralPath $warningPath -Algorithm SHA256).Hash }) | Out-Null
            }
        }
        $statusText = (& git -C $repo -c core.safecrlf=false status --short 2>$null | ForEach-Object { [string]$_ }) -join "`n"
        $diffStat = (& git -C $repo -c core.safecrlf=false diff --stat 2>$null | ForEach-Object { [string]$_ }) -join "`n"
        $statusPath = Join-Path $packageRoot (Join-Path $shipRoot "git-status.txt")
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $statusPath) | Out-Null
        Set-Content -Path $statusPath -Value $statusText -Encoding UTF8
        $included.Add([pscustomobject]@{ path = (Join-Path $shipRoot "git-status.txt"); sha256 = (Get-FileHash -LiteralPath $statusPath -Algorithm SHA256).Hash }) | Out-Null
        $diffPath = Join-Path $packageRoot (Join-Path $shipRoot "git-diff-stat.txt")
        Set-Content -Path $diffPath -Value $diffStat -Encoding UTF8
        $included.Add([pscustomobject]@{ path = (Join-Path $shipRoot "git-diff-stat.txt"); sha256 = (Get-FileHash -LiteralPath $diffPath -Algorithm SHA256).Hash }) | Out-Null

        $changedRoot = Join-Path $packageRoot (Join-Path $shipRoot "changed-source")
        $diffRoot = Join-Path $packageRoot (Join-Path $shipRoot "diffs")
        $changedEntries = @($statusText -split "`n" | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        foreach ($entry in $changedEntries) {
            $pathPart = ($entry.Substring([Math]::Min(3, $entry.Length))).Trim()
            if ($pathPart -match " -> ") { $pathPart = ($pathPart -split " -> ")[-1].Trim() }
            $normalized = $pathPart -replace "\\", "/"
            $sourcePath = Join-Path $repo $normalized
            if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                if (!(Test-AuditAllowedEvidencePath -RelativePath $normalized)) { continue }
                if ($normalized -notmatch "(?i)\.(ps1|psm1|psd1|json|md|mjs|js|ts|tsx|css|html|yml|yaml|txt)$") { continue }
                $snapshotRelative = Join-Path $shipRoot ("changed-source/" + $normalized)
                Copy-IfPresent -Source $sourcePath -DestinationRoot $packageRoot -RelativePath $snapshotRelative -Included $included
            } elseif (Test-Path -LiteralPath $sourcePath -PathType Container) {
                $childFiles = @(Get-ChildItem -LiteralPath $sourcePath -Recurse -File -ErrorAction SilentlyContinue)
                foreach ($child in $childFiles) {
                    $childRelative = (Get-AuditRelativePath -BasePath $repo -ChildPath $child.FullName) -replace "\\", "/"
                    if (!(Test-AuditAllowedEvidencePath -RelativePath $childRelative)) { continue }
                    if ($childRelative -notmatch "(?i)\.(ps1|psm1|psd1|json|md|mjs|js|ts|tsx|css|html|yml|yaml|txt)$") { continue }
                    Copy-IfPresent -Source $child.FullName -DestinationRoot $packageRoot -RelativePath (Join-Path $shipRoot ("changed-source/" + $childRelative)) -Included $included
                }
            }

            $diffText = (& git -C $repo -c core.safecrlf=false diff -- "$normalized" 2>$null | ForEach-Object { [string]$_ }) -join "`n"
            if (![string]::IsNullOrWhiteSpace($diffText)) {
                $diffFile = Join-Path $diffRoot (($normalized -replace "[/:\\]+", "__") + ".diff")
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $diffFile) | Out-Null
                Set-Content -Path $diffFile -Encoding UTF8 -Value $diffText
                $included.Add([pscustomobject]@{ path = (Join-Path $shipRoot ("diffs/" + (Split-Path -Leaf $diffFile))); sha256 = (Get-FileHash -LiteralPath $diffFile -Algorithm SHA256).Hash }) | Out-Null
            }
        }
    }
    $shipEntries += [pscustomobject]@{ name = $name; repo = $repo; state = $repoState.state; branch = $repoState.branch; head = $repoState.head; changedFileCount = @($repoState.changedFiles).Count }
}

$readmePath = Join-Path $packageRoot "README_AUDIT_PACKAGE.md"
Set-Content -Path $readmePath -Encoding UTF8 -Value @(
    "# Codex Fleet Audit Package",
    "",
    "- Audit ID: $AuditId",
    "- Generated: $((Get-Date).ToUniversalTime().ToString('o'))",
    "- Ships: $($shipEntries.Count)",
    "",
    "This package is read-only evidence for external review. It excludes dependency folders, build outputs, secrets, and live runtime locks."
)
$included.Add([pscustomobject]@{ path = "README_AUDIT_PACKAGE.md"; sha256 = (Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash }) | Out-Null

$promptDir = Join-Path $packageRoot "prompts"
New-Item -ItemType Directory -Force -Path $promptDir | Out-Null
$promptPath = Join-Path $promptDir "external-audit-prompt.md"
Set-Content -Path $promptPath -Encoding UTF8 -Value @(
    "# External Audit Prompt",
    "",
    "Review this Codex Fleet audit package for Golden Gameplan Stage 4.5: Evidence Repair and Audit Package V2.",
    "",
    "Answer these questions:",
    "",
    "1. Is the package complete enough to externally review Stages 1-4 and proceed to Stage 5 dry-run state-machine work?",
    "2. Does RUN_RESULT.json contain non-empty checks, commands, exit codes, timestamps, statuses, and evidence references?",
    "3. Does EVIDENCE_INDEX.md point to real evidence artifacts?",
    "3a. Does docs/codex/test-summary.md exist when full test transcripts are present, and does it summarize stage/scenario results while linking back to full stdout/stderr logs?",
    "4. Are changed harness scripts, schemas, tests, docs, and sanitized diffs/snapshots included enough for review?",
    "5. Is task-packet validation evidenced for accepted, stale, malformed, duplicate, and forbidden-scope packets?",
    "6. Is the runtime scope policy clear enough about allowed roots, forbidden paths, sensitive domains, and budget limits?",
    "7. What remains GREEN/YELLOW/RED before Stage 5?",
    "",
    "Do not ask the fleet to bypass validation, touch secrets/auth/payments/deploy config, edit product repos, delete locks, push, deploy, or merge. Recommend only harness/docs/tests repairs if needed."
)
$included.Add([pscustomobject]@{ path = "prompts/external-audit-prompt.md"; sha256 = (Get-FileHash -LiteralPath $promptPath -Algorithm SHA256).Hash }) | Out-Null

$manifest = [pscustomobject]@{
    auditId = $AuditId
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    fleetRoot = $fleetRoot
    configPath = $configFullPath
    ships = $shipEntries
    exclusions = @("node_modules", ".git", "dist", "build", ".env", ".codex-local/locks")
    files = @($included)
}
$manifestPath = Join-Path $packageRoot "manifest.json"
$manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $manifestPath -Encoding UTF8

$validationDir = Join-Path $packageRoot "validation"
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null
$manifestValidationPath = Join-Path $validationDir "manifest-validation.json"
$manifestValidation = [pscustomobject]@{
    schema = "templates/audit-manifest-schema.json"
    status = if ($manifest.auditId -and $manifest.generatedAt -and @($manifest.files).Count -gt 0) { "passed" } else { "failed" }
    fileCount = @($manifest.files).Count
    checkedAt = (Get-Date).ToUniversalTime().ToString("o")
}
$manifestValidation | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestValidationPath -Encoding UTF8
$included.Add([pscustomobject]@{ path = "validation/manifest-validation.json"; sha256 = (Get-FileHash -LiteralPath $manifestValidationPath -Algorithm SHA256).Hash }) | Out-Null
$manifest.files = @($included)
$manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $manifestPath -Encoding UTF8

$zipPath = ""
if (!$NoZip) {
    $zipPath = Join-Path $outFullRoot "$AuditId.zip"
    Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force
}

Write-Host "AUDIT_PACKAGE: $packageRoot"
if ($zipPath) { Write-Host "AUDIT_ZIP: $zipPath" }
