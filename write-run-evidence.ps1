[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Repo = "",
    [string]$Ship = "",
    [string]$RunId = "",
    [string]$Status = "MANUAL_EVIDENCE",
    [string]$Phase = "",
    [string]$DecisionHint = "PARK",
    [string]$Notes = "",
    [string[]]$EvidencePath = @(),
    [string]$CheckJson = "",
    [switch]$WriteArtifactIndexFixture,
    [string]$FixtureRoot = "",
    [string]$ArtifactPath = "",
    [string]$ArtifactType = "run-result",
    [string]$RetentionClass = "run-local",
    [string]$SensitiveExportPolicy = "",
    [string]$SourceCommand = "write-run-evidence.ps1",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")

function Test-FleetArtifactSecretLikePath {
    param([string]$Path)

    $value = ([string]$Path).Replace("\", "/")
    return ($value -match '(^|/)\.env($|[./-])' -or
        $value -match '(^|/)\.git(/|$)' -or
        $value -match '(^|/)node_modules(/|$)' -or
        $value -match '(secret|private-key|credential|token|auth|payment|stripe|deploy|production)')
}

function New-FleetArtifactIndexFixtureRecord {
    param(
        [Parameter(Mandatory = $true)][string]$FixtureRoot,
        [Parameter(Mandatory = $true)][string]$ArtifactPath,
        [string]$ArtifactType = "run-result",
        [string]$ShipId = "FixtureShip",
        [string]$RunId = "fixture-run",
        [string]$RetentionClass = "run-local",
        [string]$SensitiveExportPolicy = "",
        [string]$SourceCommand = "write-run-evidence.ps1",
        [datetime]$CreatedAt = (Get-Date),
        [string[]]$EvidenceRefs = @()
    )

    if ([string]::IsNullOrWhiteSpace($FixtureRoot)) { throw "FixtureRoot is required for artifact index fixture writing." }
    if ([string]::IsNullOrWhiteSpace($ArtifactPath)) { throw "ArtifactPath is required for artifact index fixture writing." }

    $fixtureFull = [System.IO.Path]::GetFullPath($FixtureRoot)
    $artifactFull = if ([System.IO.Path]::IsPathRooted($ArtifactPath)) {
        [System.IO.Path]::GetFullPath($ArtifactPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $fixtureFull $ArtifactPath))
    }

    if (!$artifactFull.StartsWith($fixtureFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ArtifactPath escapes fixture root: $ArtifactPath"
    }

    $displayPath = if ([System.IO.Path]::IsPathRooted($ArtifactPath)) {
        [System.IO.Path]::GetRelativePath($fixtureFull, $artifactFull).Replace("\", "/")
    } else {
        ([string]$ArtifactPath).Replace("\", "/")
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $exists = Test-Path -LiteralPath $artifactFull -PathType Leaf
    $hash = ""
    if ($exists) {
        $hash = (Get-FileHash -LiteralPath $artifactFull -Algorithm SHA256).Hash.ToLowerInvariant()
        $reasons.Add("artifact-exists") | Out-Null
        $reasons.Add("hash-present") | Out-Null
    } else {
        $reasons.Add("artifact-missing") | Out-Null
        $reasons.Add("hash-missing") | Out-Null
    }

    $policy = if ([string]::IsNullOrWhiteSpace($SensitiveExportPolicy)) { "exportable" } else { $SensitiveExportPolicy }
    if (Test-FleetArtifactSecretLikePath -Path $displayPath) {
        $policy = "non-exportable"
        $reasons.Add("secret-like-path") | Out-Null
    }

    $reasons.Add("retention-classified") | Out-Null
    $reasons.Add($policy) | Out-Null
    $reasons.Add("source-command-reference-only") | Out-Null

    return [pscustomobject]@{
        schemaVersion = 1
        artifactId = "artifact:${ShipId}:${RunId}:$($CreatedAt.ToUniversalTime().ToString("yyyyMMddHHmmss"))"
        path = $displayPath
        artifactType = $ArtifactType
        shipId = $ShipId
        runId = $RunId
        sha256 = $hash
        createdAt = $CreatedAt.ToUniversalTime().ToString("o")
        retentionClass = $RetentionClass
        sensitiveExportPolicy = $policy
        sourceCommand = $SourceCommand
        evidenceRefs = @($EvidenceRefs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        validation = [pscustomobject]@{
            status = if ($exists) { "valid" } else { "unknown" }
            reasons = @($reasons | Select-Object -Unique)
        }
    }
}

if ($WriteArtifactIndexFixture) {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw "OutputPath is required with -WriteArtifactIndexFixture." }
    if ([string]::IsNullOrWhiteSpace($FixtureRoot)) { throw "FixtureRoot is required with -WriteArtifactIndexFixture." }

    $fixtureFull = [System.IO.Path]::GetFullPath($FixtureRoot)
    $outputFull = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        [System.IO.Path]::GetFullPath($OutputPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $fixtureFull $OutputPath))
    }
    if (!$outputFull.StartsWith($fixtureFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputPath escapes fixture root: $OutputPath"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputFull) | Out-Null
    $record = New-FleetArtifactIndexFixtureRecord -FixtureRoot $FixtureRoot -ArtifactPath $ArtifactPath -ArtifactType $ArtifactType -ShipId $Ship -RunId $RunId -RetentionClass $RetentionClass -SensitiveExportPolicy $SensitiveExportPolicy -SourceCommand $SourceCommand -EvidenceRefs $EvidencePath
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputFull -Encoding UTF8
    Write-Host "ARTIFACT_INDEX_RECORD: $outputFull"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Repo)) { throw "Repo is required unless -WriteArtifactIndexFixture is used." }

$checkRecords = @()
if (![string]::IsNullOrWhiteSpace($CheckJson)) {
    $checkPath = if ([System.IO.Path]::IsPathRooted($CheckJson)) { $CheckJson } else { Join-Path (Get-Location) $CheckJson }
    if (!(Test-Path -LiteralPath $checkPath)) { throw "CheckJson not found: $checkPath" }
    $checkRecords = @(Get-Content -LiteralPath $checkPath -Raw | ConvertFrom-Json)
}

$written = Write-FleetRunEvidence -Repo $Repo -Ship $Ship -RunId $RunId -Status $Status -Phase $Phase -DecisionHint $DecisionHint -Notes $Notes -EvidencePaths $EvidencePath -CheckRecords $checkRecords
Write-Host "RUN_RESULT: $($written.runResult)"
Write-Host "RUN_SUMMARY: $($written.runSummary)"
Write-Host "EVIDENCE_INDEX: $($written.evidenceIndex)"
