[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("Prompt", "ValidateResponse", "Compare", "CaptainSummary")]
    [string]$Mode = "Prompt",
    [string]$Role = "Issue Auditor",
    [string]$Ship = "",
    [string]$AuditPackagePath = "",
    [string]$Mission = "Audit the selected ship and recommend safe next work.",
    [string]$KnownConstraints = "Do not edit repos, bypass validation, touch secrets/auth/payments/deploy config, or ask for broad rewrites.",
    [ValidateSet("findings-only", "task-packet", "comparison")]
    [string]$DesiredOutputType = "task-packet",
    [ValidateSet("low", "normal", "urgent")]
    [string]$Urgency = "normal",
    [string]$ResponsePath = "",
    [string[]]$ResponsePaths = @(),
    [string]$ExpectedAuditId = "",
    [string]$ExpectedShip = "",
    [string]$ExpectedBaseCommit = "",
    [string]$ComparisonPath = "",
    [string[]]$RolesUsed = @(),
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-external-agent.ps1")

function Resolve-Stage9Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutPath = "out\stage9-external-agent\stage9-$stamp.json"
    if ($Mode -eq "Prompt") { $OutPath = "out\stage9-external-agent\stage9-$stamp-prompt.md" }
    if ($Mode -eq "CaptainSummary") { $OutPath = "out\stage9-external-agent\stage9-$stamp-captain-summary.md" }
}
$outFull = Resolve-Stage9Path $OutPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outFull) | Out-Null

switch ($Mode) {
    "Prompt" {
        if ([string]::IsNullOrWhiteSpace($Ship)) { throw "Prompt mode requires -Ship." }
        if ([string]::IsNullOrWhiteSpace($AuditPackagePath)) { throw "Prompt mode requires -AuditPackagePath." }
        $prompt = New-FleetExternalAgentPrompt -Role $Role -Ship $Ship -AuditPackagePath $AuditPackagePath -Mission $Mission -KnownConstraints $KnownConstraints -DesiredOutputType $DesiredOutputType -Urgency $Urgency
        $prompt | Set-Content -LiteralPath $outFull -Encoding UTF8
        Write-Host "STAGE9_PROMPT: $outFull"
    }
    "ValidateResponse" {
        if ([string]::IsNullOrWhiteSpace($ResponsePath)) { throw "ValidateResponse mode requires -ResponsePath." }
        $responseFull = Resolve-Stage9Path $ResponsePath
        if (!(Test-Path -LiteralPath $responseFull)) { throw "Response not found: $responseFull" }
        try {
            $response = Get-Content -LiteralPath $responseFull -Raw | ConvertFrom-Json
        } catch {
            $result = [pscustomobject]@{
                valid = $false
                errors = @("Malformed response JSON: $($_.Exception.Message)")
                warnings = @()
                taskCount = 0
            }
            $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outFull -Encoding UTF8
            Write-Host "STAGE9_RESPONSE_VALID: False"
            Write-Host "STAGE9_VALIDATION: $outFull"
            exit 1
        }
        $result = Test-FleetExternalAgentResponse -Response $response -ExpectedAuditId $ExpectedAuditId -ExpectedShip $ExpectedShip -ExpectedBaseCommit $ExpectedBaseCommit
        $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outFull -Encoding UTF8
        Write-Host "STAGE9_RESPONSE_VALID: $($result.valid)"
        Write-Host "STAGE9_VALIDATION: $outFull"
        if (!$result.valid) { exit 1 }
    }
    "Compare" {
        $responses = @()
        $expandedResponsePaths = @($ResponsePaths | ForEach-Object { [string]$_ } | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        foreach ($path in @($expandedResponsePaths)) {
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            $full = Resolve-Stage9Path $path
            if (!(Test-Path -LiteralPath $full)) { throw "Response not found: $full" }
            $responses += (Get-Content -LiteralPath $full -Raw | ConvertFrom-Json)
        }
        if ($responses.Count -eq 0) { throw "Compare mode requires at least one -ResponsePaths value." }
        $comparison = Compare-FleetExternalAgentResponses -Responses $responses
        $comparison | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $outFull -Encoding UTF8
        Write-Host "STAGE9_COMPARISON: $outFull"
    }
    "CaptainSummary" {
        if ([string]::IsNullOrWhiteSpace($ComparisonPath)) { throw "CaptainSummary mode requires -ComparisonPath." }
        $comparisonFull = Resolve-Stage9Path $ComparisonPath
        if (!(Test-Path -LiteralPath $comparisonFull)) { throw "Comparison not found: $comparisonFull" }
        $comparison = Get-Content -LiteralPath $comparisonFull -Raw | ConvertFrom-Json
        $summary = New-FleetExternalCaptainSummary -Comparison $comparison -Ship $Ship -AuditPackage $AuditPackagePath -RolesUsed $RolesUsed
        $summary | Set-Content -LiteralPath $outFull -Encoding UTF8
        Write-Host "STAGE9_CAPTAIN_SUMMARY: $outFull"
    }
}
