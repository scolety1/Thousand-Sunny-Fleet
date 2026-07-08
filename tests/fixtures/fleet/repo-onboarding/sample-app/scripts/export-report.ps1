[CmdletBinding()]
param(
    [string]$OutFile = ""
)

$payload = [pscustomobject]@{
    kind = "report export"
    generated_by = "fixture"
}

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $payload | ConvertTo-Json
} else {
    $payload | ConvertTo-Json | Set-Content -LiteralPath $OutFile -Encoding UTF8
}
