[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath,
    [Parameter(Mandatory = $true)]
    [string]$OutPath,
    [switch]$CaptainApproved
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Resolve-FleetPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Test-AuditLoopForbiddenText {
    param(
        [string]$Value,
        [string[]]$ForbiddenDataSources
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $normalized = ($Value -replace "\\", "/")
    if ([System.IO.Path]::IsPathRooted($Value)) { return $true }
    if ($normalized -match "(^|/)\.\.(/|$)") { return $true }
    if ($normalized -match "(?i)(^|/)(\.env|\.git|node_modules|dist|build|\.codex-local/locks)(/|$)") { return $true }
    if ($normalized -match "(?i)(secret|token|credential|private[-_]?key)") { return $true }
    if ($normalized -match "(?i)(auth|payment|deploy|migration|package\.json|pnpm-lock|package-lock)") { return $true }
    foreach ($forbidden in @($ForbiddenDataSources)) {
        if ([string]::IsNullOrWhiteSpace($forbidden)) { continue }
        $f = ([string]$forbidden -replace "\\", "/").Trim("/")
        $candidate = $normalized.Trim("/")
        if ($candidate.Equals($f, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($candidate.StartsWith($f.TrimEnd("/") + "/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($f.Contains("*") -and ($candidate -like $f)) { return $true }
    }
    return $false
}

function Get-TaskValidationErrors {
    param(
        [object]$Task,
        [string[]]$ForbiddenDataSources
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    $required = @(
        "id",
        "title",
        "dispatchPhrase",
        "goal",
        "readList",
        "workList",
        "acceptanceCriteria",
        "requiredChecks",
        "commitExpectation",
        "riskLevel",
        "notes",
        "stopIf",
        "proof"
    )
    foreach ($field in $required) {
        if (!($Task.PSObject.Properties.Name -contains $field)) {
            $errors.Add("missing field: $field") | Out-Null
            continue
        }
        $value = $Task.$field
        if ($null -eq $value -or ([string]$value).Trim().Length -eq 0) {
            if ($field -notin @("readList", "workList", "acceptanceCriteria", "requiredChecks", "stopIf", "proof")) {
                $errors.Add("empty field: $field") | Out-Null
            }
        }
    }
    foreach ($listField in @("readList", "workList", "acceptanceCriteria", "requiredChecks", "stopIf", "proof")) {
        if ($Task.PSObject.Properties.Name -contains $listField) {
            if (@($Task.$listField).Count -eq 0) {
                $errors.Add("empty list: $listField") | Out-Null
            }
        }
    }
    if ($Task.PSObject.Properties.Name -contains "id" -and [string]$Task.id -notmatch "^[a-z0-9][a-z0-9._-]*$") {
        $errors.Add("invalid id") | Out-Null
    }
    if ($Task.PSObject.Properties.Name -contains "riskLevel" -and [string]$Task.riskLevel -notin @("low", "medium", "high")) {
        $errors.Add("invalid riskLevel") | Out-Null
    }
    if ($Task.PSObject.Properties.Name -contains "commitExpectation" -and [string]$Task.commitExpectation -notin @("none", "optional", "one-commit", "captain-decides")) {
        $errors.Add("invalid commitExpectation") | Out-Null
    }
    foreach ($field in @("readList", "workList")) {
        foreach ($item in @($Task.$field)) {
            if (Test-AuditLoopForbiddenText -Value ([string]$item) -ForbiddenDataSources $ForbiddenDataSources) {
                $errors.Add("forbidden scope in $field`: $item") | Out-Null
            }
        }
    }
    return @($errors)
}

function Test-AcceptedLimitation {
    param(
        [object]$Finding,
        [string[]]$AcceptedLimitations
    )
    $haystack = @(
        [string]$Finding.title,
        [string]$Finding.summary,
        [string]$Finding.limitation,
        [string]$Finding.notes
    ) -join "`n"
    foreach ($limitation in @($AcceptedLimitations)) {
        if ([string]::IsNullOrWhiteSpace($limitation)) { continue }
        if ($haystack -match [regex]::Escape([string]$limitation)) { return $true }
    }
    return $false
}

$reportFullPath = Resolve-FleetPath $ReportPath
$metadataFullPath = Resolve-FleetPath $MetadataPath
if (!(Test-Path -LiteralPath $reportFullPath)) { throw "Report not found: $reportFullPath" }
if (!(Test-Path -LiteralPath $metadataFullPath)) { throw "Metadata not found: $metadataFullPath" }

$report = Get-Content -LiteralPath $reportFullPath -Raw | ConvertFrom-Json
$metadata = Get-Content -LiteralPath $metadataFullPath -Raw | ConvertFrom-Json
$maxTasks = [int]$metadata.maxTasks
if ($maxTasks -lt 1) { throw "Metadata maxTasks must be at least 1." }

$accepted = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()
$rejected = [System.Collections.Generic.List[object]]::new()
$seenIds = @{}

foreach ($finding in @($report.findings)) {
    $findingId = if ($finding.PSObject.Properties.Name -contains "id") { [string]$finding.id } else { [string]$finding.title }
    if (Test-AcceptedLimitation -Finding $finding -AcceptedLimitations @($metadata.acceptedLimitations)) {
        $skipped.Add([pscustomobject]@{ id = $findingId; reason = "accepted-limitation" }) | Out-Null
        continue
    }
    if (!($finding.PSObject.Properties.Name -contains "task") -or $null -eq $finding.task) {
        $skipped.Add([pscustomobject]@{ id = $findingId; reason = "no-task" }) | Out-Null
        continue
    }
    $task = $finding.task
    $errors = @(Get-TaskValidationErrors -Task $task -ForbiddenDataSources @($metadata.forbiddenDataSources))
    if ($seenIds.ContainsKey([string]$task.id)) {
        $errors += "duplicate task id"
    }
    if (($metadata.requiresCaptainApproval -or [bool]$finding.requiresCaptainApproval) -and !$CaptainApproved) {
        $errors += "captain approval required"
    }
    if (@($errors).Count -gt 0) {
        $rejected.Add([pscustomobject]@{ id = [string]$task.id; reason = "invalid-task"; errors = @($errors) }) | Out-Null
        continue
    }
    $seenIds[[string]$task.id] = $true
    $accepted.Add($task) | Out-Null
}

if (@($accepted).Count -gt $maxTasks) {
    $rejected.Add([pscustomobject]@{ id = "queue"; reason = "maxTasks-exceeded"; errors = @("accepted task count $(@($accepted).Count) exceeds maxTasks $maxTasks") }) | Out-Null
}

$outFullPath = Resolve-FleetPath $OutPath
$outParent = Split-Path -Parent $outFullPath
if (![string]::IsNullOrWhiteSpace($outParent)) {
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null
}
$validationPath = [System.IO.Path]::ChangeExtension($outFullPath, ".validation.json")
$validation = [pscustomobject]@{
    status = if (@($rejected).Count -eq 0) { "passed" } else { "failed" }
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    reportPath = $reportFullPath
    metadataPath = $metadataFullPath
    maxTasks = $maxTasks
    acceptedCount = @($accepted).Count
    skipped = @($skipped)
    rejected = @($rejected)
}
$validation | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $validationPath -Encoding UTF8

if (@($rejected).Count -gt 0) {
    Write-Host "AUDIT_LOOP_QUEUE_REJECTED: $validationPath"
    exit 1
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Audit Loop Generated Queue") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(("- Source report: ``{0}``" -f $ReportPath)) | Out-Null
$lines.Add(("- Metadata: ``{0}``" -f $MetadataPath)) | Out-Null
$lines.Add("- Generated: $((Get-Date).ToUniversalTime().ToString('o'))") | Out-Null
$lines.Add("- Accepted tasks: $(@($accepted).Count)") | Out-Null
$lines.Add("- Skipped findings: $(@($skipped).Count)") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Temporary Audit Loop Mode Queue") | Out-Null
$lines.Add("") | Out-Null
foreach ($task in @($accepted)) {
    $lines.Add("- [ ] $($task.title)") | Out-Null
    $lines.Add(("  - id: ``{0}``" -f $task.id)) | Out-Null
    $lines.Add("  - dispatchPhrase: $($task.dispatchPhrase)") | Out-Null
    $lines.Add("  - goal: $($task.goal)") | Out-Null
    $lines.Add("  - readList: $(@($task.readList) -join '; ')") | Out-Null
    $lines.Add("  - workList: $(@($task.workList) -join '; ')") | Out-Null
    $lines.Add("  - acceptanceCriteria: $(@($task.acceptanceCriteria) -join '; ')") | Out-Null
    $lines.Add("  - requiredChecks: $(@($task.requiredChecks) -join '; ')") | Out-Null
    $lines.Add("  - commitExpectation: $($task.commitExpectation)") | Out-Null
    $lines.Add("  - riskLevel: $($task.riskLevel)") | Out-Null
    $lines.Add("  - stopIf: $(@($task.stopIf) -join '; ')") | Out-Null
    $lines.Add("  - proof: $(@($task.proof) -join '; ')") | Out-Null
    $lines.Add("") | Out-Null
}
if (@($skipped).Count -gt 0) {
    $lines.Add("## Skipped Findings") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($skip in @($skipped)) {
        $lines.Add(("- ``{0}`` - {1}" -f $skip.id, $skip.reason)) | Out-Null
    }
}
$lines | Set-Content -LiteralPath $outFullPath -Encoding UTF8

Write-Host "AUDIT_LOOP_QUEUE: $outFullPath"
Write-Host "AUDIT_LOOP_QUEUE_VALIDATION: $validationPath"
