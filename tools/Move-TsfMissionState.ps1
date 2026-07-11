param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$FromState,

    [Parameter(Mandatory = $true)]
    [string]$ToState,

    [string]$QueueRoot = "fleet/missions",
    [string]$PolicyPath = "",
    [string]$ExecutorPolicyPath = "",
    [string]$OutFile = "",
    [string]$RecoveryEnvelopePath = "",
    [string]$RecoveryTransactionPath = "",
    [switch]$TestOnlyAllowAlternateQueueRoot,
    [object]$TestOnlyPolicyCapability = $null,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
Import-Module (Join-Path $fleetRoot 'tools\TsfDurableContract.psm1')

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

$queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
$transitionPolicyAuthority=Resolve-TsfTransitionPolicyAuthority -QueueAuthority $queueAuthority -StatePolicyPath $PolicyPath -ExecutorPolicyPath $ExecutorPolicyPath -TestOnlyPolicyCapability $TestOnlyPolicyCapability
$policy = Read-QueueJson -Path ([string]$transitionPolicyAuthority.state_policy_path)
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
$isRecovery = ![string]::IsNullOrWhiteSpace($RecoveryEnvelopePath)
if(![string]::IsNullOrWhiteSpace($RecoveryTransactionPath)){throw 'PARTIAL_RECOVERY_TRANSACTION_INPUT_REJECTED'}
if ($isRecovery) {
    $recoveryPath = Get-QueueFullPath -Path $RecoveryEnvelopePath
    if (!(Test-Path -LiteralPath $recoveryPath -PathType Leaf)) {
        $blocked.Add("Canonical recovery envelope not found.") | Out-Null
    } else {
        $recoveryCheck=Test-TsfCanonicalRecoveryEnvelope -EnvelopePath $recoveryPath -ExpectedMissionPath $missionFull -ExpectedFromState $from -ExpectedToState $to -QueueRootPath ([string]$queueAuthority.root) -RepositoryRoot $fleetRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
        if(!$recoveryCheck.valid){foreach($reason in @($recoveryCheck.errors)){$blocked.Add([string]$reason)|Out-Null};[void](Write-TsfRecoveryConflictDiagnostic -EnvelopePath $recoveryPath -Errors @($recoveryCheck.errors))}else{$recovery=$recoveryCheck.transaction}
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
    transition_policy_authority_kind = [string]$transitionPolicyAuthority.kind
    transition_policy_authority_identity_sha256 = [string]$transitionPolicyAuthority.authority_identity_sha256
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
