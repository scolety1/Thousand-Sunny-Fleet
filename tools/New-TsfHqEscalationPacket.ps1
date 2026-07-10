param(
    [Parameter(Mandatory = $true)]
    [string]$Trigger,

    [Parameter(Mandatory = $true)]
    [string]$DecisionRequested,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceSummary,

    [string]$OutFile = "",
    [string]$PacketId = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PacketId)) {
    $safeTrigger = ($Trigger.ToLowerInvariant() -replace "[^a-z0-9._-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeTrigger)) { $safeTrigger = "hq-escalation" }
    $PacketId = "$safeTrigger-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

if ($EvidenceSummary.Length -gt 4000) {
    throw "Compressed evidence must be 4000 characters or fewer. Raw repo dumps are not allowed."
}
if ($EvidenceSummary -match "(?i)-----BEGIN|api[_-]?key|token=|password|secret") {
    throw "Evidence appears to include secret-like material; refusing packet creation."
}

$packet = [pscustomobject]@{
    packet_schema = "hq_escalation_compressed_packet_v1"
    packet_id = $PacketId
    created_at = (Get-Date).ToString("o")
    trigger = $Trigger
    decision_requested = $DecisionRequested
    compressed_evidence = $EvidenceSummary
    token_estimate = [math]::Ceiling(($Trigger.Length + $DecisionRequested.Length + $EvidenceSummary.Length) / 4)
    allowed_verdicts = @(
        "GREEN_APPROVE_LOCAL_NEXT_STEP",
        "YELLOW_NEEDS_MORE_LOCAL_EVIDENCE",
        "RED_BLOCK_UNSAFE",
        "TIM_REQUIRED_SCOPE_OR_AUTHORITY"
    )
    api_call_requested = $false
    transport_enabled = $false
    raw_repo_dump_included = $false
    hard_gate_bypass_requested = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $packet | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$packet
