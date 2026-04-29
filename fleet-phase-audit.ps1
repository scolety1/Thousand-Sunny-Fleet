[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [string]$OutFile = "out\phase-readiness.md",

    [switch]$Strict
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

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

function Get-PhaseValue {
    param(
        [string]$Text,
        [string]$Name
    )

    $match = [regex]::Match($Text, "(?im)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-Projects {
    if (!(Test-Path -LiteralPath $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) {
            Stop-WithMessage "Project not found: $Project"
        }
    }

    $exclude = @(ConvertTo-ProjectList -Values $ExcludeProject)
    if ($exclude.Count -gt 0) {
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
    }

    return $projects
}

$requiredFields = @(
    "Current Phase",
    "Audience",
    "Product Promise",
    "Primary Action",
    "Showable Moment",
    "What Not To Build",
    "No More Features Lock",
    "Complexity Budget",
    "Before/After Judgment",
    "Human Taste Note",
    "Phase Model Policy",
    "Parking State",
    "Evidence Required",
    "Done Signal",
    "Next Phase Criteria"
)

$rows = New-Object System.Collections.Generic.List[object]
foreach ($ship in @(Get-Projects)) {
    $name = [string]$ship.name
    $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
    $phasePath = Join-Path $repo "docs\codex\PHASE_STATE.md"

    $status = "READY"
    $phase = "missing"
    $parking = "missing"
    $issues = New-Object System.Collections.Generic.List[string]

    if (!(Test-Path -LiteralPath $phasePath)) {
        $status = "MISSING"
        $issues.Add("PHASE_STATE.md missing") | Out-Null
    } else {
        $text = Get-Content -LiteralPath $phasePath -Raw
        $phase = Get-PhaseValue -Text $text -Name "Current Phase"
        $parking = Get-PhaseValue -Text $text -Name "Parking State"

        foreach ($field in $requiredFields) {
            $value = Get-PhaseValue -Text $text -Name $field
            if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^TODO:') {
                $issues.Add("$field missing/TODO") | Out-Null
            }
        }

        $featureLock = Get-PhaseValue -Text $text -Name "No More Features Lock"
        if ($phase -in @("simplicity", "polish", "proof", "parked") -and $featureLock -ne "true") {
            $issues.Add("feature lock should be true in $phase") | Out-Null
        }

        if ($phase -eq "parked" -and $parking -ne "PARKED_REVIEW_READY") {
            $issues.Add("parked phase should set PARKED_REVIEW_READY") | Out-Null
        }

        if ($issues.Count -gt 0) {
            $status = "INCOMPLETE"
        }
        if ($parking -eq "PARKED_REVIEW_READY") {
            $status = if ($issues.Count -gt 0) { "PARKED_INCOMPLETE" } else { "PARKED_READY" }
        }
    }

    $rows.Add([pscustomobject]@{
        project = $name
        status = $status
        phase = $phase
        parking = $parking
        issues = if ($issues.Count -gt 0) { $issues -join "; " } else { "none" }
        path = $phasePath
    }) | Out-Null
}

$outPath = Join-Path $fleetRoot $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Fleet Phase Readiness") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Ship | Status | Phase | Parking | Issues |") | Out-Null
$lines.Add("| --- | --- | --- | --- | --- |") | Out-Null
foreach ($row in $rows) {
    $issues = ([string]$row.issues).Replace("|", "\|")
    $lines.Add("| $($row.project) | $($row.status) | $($row.phase) | $($row.parking) | $issues |") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("Status key: READY can run with phase validation; MISSING/INCOMPLETE need phase setup; PARKED_READY should not run unattended.") | Out-Null

Set-Content -LiteralPath $outPath -Value $lines

foreach ($row in $rows) {
    $color = switch ($row.status) {
        "READY" { "Green" }
        "PARKED_READY" { "Cyan" }
        default { "Yellow" }
    }
    Write-Host "$($row.project): $($row.status) ($($row.phase))" -ForegroundColor $color
}
Write-Host "Phase readiness report: $outPath" -ForegroundColor Cyan

$blocking = @($rows | Where-Object { $_.status -in @("MISSING", "INCOMPLETE", "PARKED_INCOMPLETE") })
if ($Strict -and $blocking.Count -gt 0) {
    Write-Host "Strict phase readiness failed for: $((@($blocking | ForEach-Object { $_.project })) -join ', ')" -ForegroundColor Red
    exit 1
}

exit 0
