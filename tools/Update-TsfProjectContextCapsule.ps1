param(
    [Parameter(Mandatory = $true)]
    [string]$CapsulePath,

    [Parameter(Mandatory = $true)]
    [string]$MissionId,

    [Parameter(Mandatory = $true)]
    [string]$MissionResult,

    [string]$WorkerRole = "",
    [string]$CurrentLane = "",
    [string[]]$ArtifactsCreated = @(),
    [string[]]$BlockersEncountered = @(),
    [string[]]$ApprovalsRequired = @(),
    [string]$NextRecommendedAction = "",
    [string]$DoNotRepeatLesson = "",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

function ConvertTo-TsfContextArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }
    return @([string]$Value)
}

function Add-TsfUniqueValues {
    param([object[]]$Existing, [object[]]$NewValues)
    $set = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Existing + $NewValues)) {
        $text = [string]$item
        if (![string]::IsNullOrWhiteSpace($text) -and $set -notcontains $text) {
            $set.Add($text) | Out-Null
        }
    }
    return @($set)
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $targetPath = $OutFile
} else {
    $targetPath = $CapsulePath
}

if (Test-Path -LiteralPath $CapsulePath) {
    $capsule = Get-Content -LiteralPath $CapsulePath -Raw | ConvertFrom-Json
} else {
    $capsule = [pscustomobject]@{
        capsule_id = "project-context-$(Get-Date -Format 'yyyyMMddHHmmss')"
        project_id = "thousand-sunny-fleet"
        project_goal = "Maintain TSF project context for foreground mission lifecycle."
        current_branch = ""
        current_lane = ""
        completed_missions = @()
        active_blockers = @()
        approvals = @()
        known_risks = @()
        do_not_repeat_lessons = @()
        next_recommended_action = ""
        hq_escalation_history = @()
        updated_at = (Get-Date).ToString("o")
    }
}

$missionSummary = "$MissionId|$MissionResult"
if (![string]::IsNullOrWhiteSpace($WorkerRole)) {
    $missionSummary = "$missionSummary|$WorkerRole"
}

$capsule.completed_missions = @(Add-TsfUniqueValues -Existing (ConvertTo-TsfContextArray $capsule.completed_missions) -NewValues @($missionSummary))
$capsule.active_blockers = @(Add-TsfUniqueValues -Existing (ConvertTo-TsfContextArray $capsule.active_blockers) -NewValues $BlockersEncountered)
$capsule.approvals = @(Add-TsfUniqueValues -Existing (ConvertTo-TsfContextArray $capsule.approvals) -NewValues $ApprovalsRequired)
if (!($capsule.PSObject.Properties.Name -contains "artifacts_created")) {
    $capsule | Add-Member -NotePropertyName "artifacts_created" -NotePropertyValue @()
}
$capsule.artifacts_created = @(Add-TsfUniqueValues -Existing (ConvertTo-TsfContextArray $capsule.artifacts_created) -NewValues $ArtifactsCreated)
if (!($capsule.PSObject.Properties.Name -contains "last_worker_role")) {
    $capsule | Add-Member -NotePropertyName "last_worker_role" -NotePropertyValue ""
}
if (!($capsule.PSObject.Properties.Name -contains "last_mission_result")) {
    $capsule | Add-Member -NotePropertyName "last_mission_result" -NotePropertyValue ""
}
$capsule.last_worker_role = $WorkerRole
$capsule.last_mission_result = $MissionResult
if (![string]::IsNullOrWhiteSpace($DoNotRepeatLesson)) {
    $capsule.do_not_repeat_lessons = @(Add-TsfUniqueValues -Existing (ConvertTo-TsfContextArray $capsule.do_not_repeat_lessons) -NewValues @($DoNotRepeatLesson))
}
if (![string]::IsNullOrWhiteSpace($CurrentLane)) {
    $capsule.current_lane = $CurrentLane
}
if (![string]::IsNullOrWhiteSpace($NextRecommendedAction)) {
    $capsule.next_recommended_action = $NextRecommendedAction
}
$capsule.updated_at = (Get-Date).ToString("o")

$parent = Split-Path -Parent $targetPath
if (![string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$capsule | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $targetPath -Encoding UTF8

[pscustomobject]@{
    schema_version = "project_context_capsule_update_result_v1"
    capsule_path = $targetPath
    mission_id = $MissionId
    mission_result = $MissionResult
    worker_role = $WorkerRole
    updated = $true
    background_runner_started = $false
    api_called = $false
}
