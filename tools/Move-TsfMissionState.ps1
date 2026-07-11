param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$FromState,

    [Parameter(Mandatory = $true)]
    [string]$ToState,

    [string]$QueueRoot = "fleet/missions",
    [string]$PolicyPath = "fleet/control/mission-queue-state-policy.v1.json",
    [string]$OutFile = "",
    [string]$RecoveryTransactionPath = "",
    [switch]$TestOnlyAllowAlternateQueueRoot,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")

function Get-QueueFullPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return Get-TsfKernelFullPath -Path $Path
    }
    return Get-TsfKernelFullPath -Path $Path -BasePath $fleetRoot
}

function Test-QueuePathInside {
    param([string]$ChildPath, [string]$ParentPath)
    return (Test-TsfKernelPathInside -ChildPath $ChildPath -ParentPath $ParentPath) -and
        (Test-TsfKernelReparseContained -ChildPath $ChildPath -RepositoryRoot $ParentPath)
}

function Read-QueueJson {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$policy = Read-QueueJson -Path (Get-QueueFullPath -Path $PolicyPath)
$queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
$queueRootFull = [string]$queueAuthority.root
$missionFull = Get-QueueFullPath -Path $MissionPath
$from = $FromState.Trim()
$to = $ToState.Trim()
$blocked = New-Object System.Collections.ArrayList
if(![string]::IsNullOrWhiteSpace($OutFile)-and[string]$queueAuthority.kind-eq'PRODUCTION'){
    try{Assert-TsfRuntimePathUnderCanonicalRoot (Get-QueueFullPath $OutFile)|Out-Null}catch{$blocked.Add('Production transition evidence must use the canonical compact runtime plan.')|Out-Null}
}

if (@($policy.states | Where-Object { [string]$_ -eq $from }).Count -eq 0) {
    $blocked.Add("Unknown from state: $from") | Out-Null
}
if (@($policy.states | Where-Object { [string]$_ -eq $to }).Count -eq 0) {
    $blocked.Add("Unknown to state: $to") | Out-Null
}
if (!(Test-Path -LiteralPath $missionFull)) {
    $blocked.Add("Mission file not found: $missionFull") | Out-Null
}

$recovery = $null
$isRecovery = ![string]::IsNullOrWhiteSpace($RecoveryTransactionPath)
if ($isRecovery) {
    $recoveryPath = Get-QueueFullPath -Path $RecoveryTransactionPath
    if (!(Test-Path -LiteralPath $recoveryPath -PathType Leaf)) {
        $blocked.Add("Recovery transaction marker not found.") | Out-Null
    } else {
        $recovery = Read-QueueJson -Path $recoveryPath
        if ([string]$recovery.schema_version -ne 'tsf_admission_transaction_v1' -or [string]$recovery.state -notin @('PREPARED','RECOVERY_REQUIRED')) {
            $blocked.Add("Recovery transaction marker is not in a recoverable state.") | Out-Null
        }
        if ([string]$recovery.queue_state_to -ne $from -or [string]$recovery.queue_state_from -ne $to) {
            $blocked.Add("Recovery transition does not reverse the bound admission transition.") | Out-Null
        }
        if (![string]::Equals((Get-TsfKernelFullPath ([string]$recovery.destination_path)), $missionFull, [StringComparison]::OrdinalIgnoreCase)) {
            $blocked.Add("Recovery mission path does not match the bound transaction destination.") | Out-Null
        }
        if (Test-Path -LiteralPath $missionFull -PathType Leaf) {
            $missionDocument = Read-QueueJson -Path $missionFull
            $missionHash=Get-TsfContractJsonHash $missionDocument.durable_mission
            $queueHash=Get-TsfContractJsonHash $missionDocument
            if ([string]$missionDocument.source_binding.durable_mission_id -ne [string]$recovery.mission_id -or
                [int]$missionDocument.source_binding.durable_mission_revision -ne [int]$recovery.mission_revision -or
                [string]$missionDocument.source_binding.durable_mission_content_hash -ne [string]$recovery.mission_content_hash -or
                $missionHash -ne [string]$recovery.mission_content_hash -or
                [string]$missionDocument.source_binding.policy_fingerprint -ne [string]$recovery.policy_fingerprint -or
                [string]$missionDocument.source_binding.translator_version -ne [string]$recovery.translator_version -or
                $queueHash -ne [string]$recovery.queue_document_sha256) {
                $blocked.Add("Recovery mission identity does not match the transaction marker.") | Out-Null
            }
        }
    }
}

$allowed = if ($isRecovery) { $blocked.Count -eq 0 } else { @($policy.allowed_transitions | Where-Object { [string]$_.from -eq $from -and [string]$_.to -eq $to }).Count -gt 0 }
if (!$allowed) {
    $blocked.Add("Transition is not allowed: $from -> $to") | Out-Null
}

$expectedFromRoot = Join-Path $queueRootFull $from
if (!(Test-QueuePathInside -ChildPath $missionFull -ParentPath $expectedFromRoot)) {
    $blocked.Add("Mission path is not inside from-state folder.") | Out-Null
}

$destinationDir = Join-Path $queueRootFull $to
$destinationPath = Join-Path $destinationDir ([System.IO.Path]::GetFileName($missionFull))
if ($isRecovery -and $null -ne $recovery -and ![string]::Equals((Get-TsfKernelFullPath ([string]$recovery.source_path)), $destinationPath, [StringComparison]::OrdinalIgnoreCase)) {
    $blocked.Add("Recovery destination does not match the original transaction source.") | Out-Null
}
if (Test-Path -LiteralPath $destinationPath) {
    $blocked.Add("Destination mission already exists: $destinationPath") | Out-Null
}

$verdict = if ($blocked.Count -eq 0) { "GREEN" } else { "RED" }
if ($verdict -eq "GREEN" -and !$DryRun) {
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Move-Item -LiteralPath $missionFull -Destination $destinationPath
}

$result = [pscustomobject]@{
    schema_version = "mission_queue_transition_result_v1"
    verdict = $verdict
    from_state = $from
    to_state = $to
    mission_path = $missionFull
    destination_path = $destinationPath
    dry_run = [bool]$DryRun
    moved = ($verdict -eq "GREEN" -and !$DryRun)
    recovery = $isRecovery
    queue_authority_kind = [string]$queueAuthority.kind
    queue_authority_identity_sha256 = [string]$queueAuthority.identity_sha256
    blocked_reasons = @($blocked)
    background_runner_started = $false
    push_performed = $false
    merge_performed = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $outParent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($outParent)) {
        New-Item -ItemType Directory -Force -Path $outParent | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
