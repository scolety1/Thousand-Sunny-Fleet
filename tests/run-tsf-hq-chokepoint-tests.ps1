param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$packetPath = Join-Path $repoRoot "tests/fixtures/fleet/hq-chokepoint/operator-console-sample.packet.json"
$responsePath = Join-Path $repoRoot "tests/fixtures/fleet/hq-chokepoint/mock-hq-response.green.json"
$validationPath = Join-Path $repoRoot "tests/fixtures/fleet/hq-chokepoint/mock-hq-response.green.validation.json"

& (Join-Path $repoRoot "tools/New-TsfHqEscalationPacket.ps1") `
    -PacketId "operator-console-sample" `
    -Trigger "operator-console-chatroom-control-plane-v1" `
    -DecisionRequested "Approve local-only continuation to publication readiness after validation." `
    -EvidenceSummary "Compressed local evidence only: operator console read-only shell, dry-run mission drafting, controlled multi-lane hardening, and no-API HQ packet contract. No raw repo dump, no credentials, no API call." `
    -OutFile $packetPath | Out-Null

$packet = Get-Content -Raw -LiteralPath $packetPath | ConvertFrom-Json
if ($packet.api_call_requested -ne $false) { throw "HQ packet must not request an API call." }
if ($packet.transport_enabled -ne $false) { throw "HQ packet transport must remain disabled." }
if ($packet.raw_repo_dump_included -ne $false) { throw "HQ packet must not include a raw repo dump." }
if ($packet.token_estimate -gt 1000) { throw "HQ packet token estimate is unexpectedly high." }

& (Join-Path $repoRoot "tools/Test-TsfHqEscalationResponse.ps1") `
    -ResponsePath $responsePath `
    -PacketPath $packetPath `
    -OutFile $validationPath | Out-Null

$validation = Get-Content -Raw -LiteralPath $validationPath | ConvertFrom-Json
if ($validation.verdict -ne "GREEN_HQ_RESPONSE_VALID") {
    throw "Expected GREEN_HQ_RESPONSE_VALID, found $($validation.verdict)."
}
if ($validation.api_called -ne $false) { throw "HQ response validation must not call an API." }

Write-Host "TSF HQ chokepoint tests passed."
