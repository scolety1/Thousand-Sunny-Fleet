param(
    [Parameter(Mandatory = $true)]
    [string]$ResponsePath,

    [string]$PacketPath = "",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $ResponsePath)) {
    throw "Missing HQ response fixture: $ResponsePath"
}
$response = Get-Content -Raw -LiteralPath $ResponsePath | ConvertFrom-Json
$allowed = @(
    "GREEN_APPROVE_LOCAL_NEXT_STEP",
    "YELLOW_NEEDS_MORE_LOCAL_EVIDENCE",
    "RED_BLOCK_UNSAFE",
    "TIM_REQUIRED_SCOPE_OR_AUTHORITY"
)
$checks = New-Object System.Collections.ArrayList
$blocked = New-Object System.Collections.ArrayList

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Message)
    $script:checks.Add([pscustomobject]@{ name = $Name; status = $Status; message = $Message }) | Out-Null
}

if ($allowed -contains [string]$response.verdict) {
    Add-Check -Name "verdict.allowed" -Status "PASS" -Message "Verdict is in allowed set."
} else {
    Add-Check -Name "verdict.allowed" -Status "FAIL" -Message "Verdict is outside allowed set."
    $blocked.Add("Invalid verdict.") | Out-Null
}

if ($response.hard_gate_bypass_requested -eq $true) {
    Add-Check -Name "hard_gate_bypass.blocked" -Status "FAIL" -Message "Response requests a hard gate bypass."
    $blocked.Add("Hard gate bypass requested.") | Out-Null
} else {
    Add-Check -Name "hard_gate_bypass.blocked" -Status "PASS" -Message "No hard gate bypass requested."
}

if ([string]::IsNullOrWhiteSpace([string]$response.approved_next_action)) {
    Add-Check -Name "approved_next_action.present" -Status "FAIL" -Message "Response lacks approved_next_action."
    $blocked.Add("Missing approved_next_action.") | Out-Null
} else {
    Add-Check -Name "approved_next_action.present" -Status "PASS" -Message "Response includes approved_next_action."
}

if (![string]::IsNullOrWhiteSpace($PacketPath)) {
    if (!(Test-Path -LiteralPath $PacketPath)) { throw "Missing HQ packet fixture: $PacketPath" }
    $packet = Get-Content -Raw -LiteralPath $PacketPath | ConvertFrom-Json
    if ([string]$packet.packet_id -eq [string]$response.packet_id) {
        Add-Check -Name "packet_id.matches" -Status "PASS" -Message "Response matches packet id."
    } else {
        Add-Check -Name "packet_id.matches" -Status "FAIL" -Message "Response packet id does not match packet."
        $blocked.Add("Packet id mismatch.") | Out-Null
    }
}

$result = [pscustomobject]@{
    schema_version = "hq_response_validation_result_v1"
    verdict = if ($blocked.Count -eq 0) { "GREEN_HQ_RESPONSE_VALID" } else { "RED_HQ_RESPONSE_INVALID" }
    checks = @($checks)
    blocked_reasons = @($blocked)
    api_called = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
