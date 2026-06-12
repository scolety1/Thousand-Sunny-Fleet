[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskPacket
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$allowedAliases = @(
    "fast_readonly",
    "standard_patch",
    "deep_reasoning",
    "premium_audit"
)

function Resolve-FleetPacketPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Get-PublicPacketLabel {
    param([string]$Path)

    $fullRoot = [System.IO.Path]::GetFullPath($fleetRoot).TrimEnd("\", "/")
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($fullRoot.Length).TrimStart("\", "/") -replace "\\", "/"
    }

    return Split-Path -Leaf $fullPath
}

function Test-SafeDenialLine {
    param([string]$Line)

    return $Line -match "(?i)\b(do not|does not|must not|cannot|not approved|not allowed|without|forbidden|blocked|stop if|stop before|stop for human review before|remain blocked|request-only|evidence only|preserve no)\b|^\s*-\s+no\s+"
}

function Get-ActivePacketLines {
    param([string[]]$Lines)

    $activeLines = @()
    $inSafeSection = $false
    foreach ($line in $Lines) {
        if ($line -match "(?i)^\s*#{1,6}\s*(stop if|hard limits|stop conditions|forbidden|non-goals)\b") {
            $inSafeSection = $true
            continue
        }

        if ($line -match "^\s*#{1,6}\s+" -and $line -notmatch "(?i)^\s*#{1,6}\s*(stop if|hard limits|stop conditions|forbidden|non-goals)\b") {
            $inSafeSection = $false
        }

        if ($inSafeSection) {
            continue
        }

        if (Test-SafeDenialLine -Line $line) {
            continue
        }

        $activeLines += $line
    }

    return $activeLines
}

function Find-UnsafeGrantLines {
    param(
        [string[]]$Lines,
        [string]$Pattern
    )

    $matchedLines = @()
    foreach ($line in $Lines) {
        if ((Test-SafeDenialLine -Line $line)) {
            continue
        }

        if ($line -match $Pattern) {
            $matchedLines += $line.Trim()
        }
    }

    return $matchedLines
}

function Get-QualityMode {
    param([string]$Text)

    $qualityMatch = [regex]::Match($Text, "(?im)\bquality\s*mode\s*:\s*`?([A-Za-z_]+)`?")
    if ($qualityMatch.Success) {
        $candidate = $qualityMatch.Groups[1].Value.ToLowerInvariant()
        if ($candidate -in @("best_value", "perfection")) {
            return $candidate
        }
    }

    $camelQualityMatch = [regex]::Match($Text, "(?im)\bqualityMode\s*:\s*`?([A-Za-z_]+)`?")
    if ($camelQualityMatch.Success) {
        $candidate = $camelQualityMatch.Groups[1].Value.ToLowerInvariant()
        if ($candidate -in @("best_value", "perfection")) {
            return $candidate
        }
    }

    return "best_value"
}

function Get-TokenPressureNote {
    param([string]$Text)

    $byteCount = [System.Text.Encoding]::UTF8.GetByteCount($Text)
    $readSetCount = @([regex]::Matches($Text, "(?im)^\s*-\s+`?[^`\r\n]+\.(md|json|ps1|ts|tsx|css|html)`?\s*$")).Count

    if ($byteCount -gt 50000 -or $readSetCount -gt 30) {
        return "HIGH: packet is $byteCount bytes with about $readSetCount listed file references; consider a thinner packet before execution."
    }

    if ($byteCount -gt 15000 -or $readSetCount -gt 12) {
        return "MEDIUM: packet is $byteCount bytes with about $readSetCount listed file references; token projection may be useful before a long run."
    }

    return "LOW: packet is $byteCount bytes with about $readSetCount listed file references."
}

function Get-ModelRoutingRecommendation {
    param(
        [string]$Text,
        [string[]]$Lines,
        [string]$QualityMode,
        [string]$TokenPressureNote
    )

    $blockedConditions = @()
    $escalationTriggers = @()

    $hasAllowedFiles = $Text -match "(?i)\ballowed\s*files\b|\ballowedFiles\b"
    $hasValidationCommands = $Text -match "(?i)\bvalidation\s*commands\b|\bvalidationCommands\b|\bvalidation\b"
    if (-not $hasAllowedFiles) {
        $blockedConditions += "unclear allowedFiles"
    }
    if (-not $hasValidationCommands) {
        $blockedConditions += "unclear validationCommands"
    }

    $activeLines = @(Get-ActivePacketLines -Lines $Lines)
    $activeText = ($activeLines -join "`n")

    $unsafePatterns = [ordered]@{
        "secrets" = "(?i)\b(secret|secrets|token|tokens|credential|credentials|password|passwords|MFA|recovery code|private key|API key)\b"
        "product-repo access beyond approved scope" = "(?i)\b(any product repo|all product repos|unrestricted product repo|broad product repo|product[- ]repo access)\b"
        "deploy/merge/push" = "(?i)\b(deploy|merge|push)\b"
        "all-fleet" = "(?i)\ball-fleet\b"
        "overnight runner" = "(?i)\bovernight runner\b|\bovernight\b"
        "broad authority" = "(?i)\b(broad authority|broader authority|future authority|unbounded|unrestricted)\b"
    }

    foreach ($name in $unsafePatterns.Keys) {
        $unsafeLines = @(Find-UnsafeGrantLines -Lines $activeLines -Pattern $unsafePatterns[$name])
        if ($unsafeLines.Count -gt 0) {
            $blockedConditions += $name
        }
    }

    if ($activeText -match "(?i)repeated uncertainty") {
        $escalationTriggers += "repeated uncertainty"
    }
    if ($activeText -match "(?i)validation failed twice|fails twice") {
        $escalationTriggers += "validation failed twice"
    }
    if ($activeText -match "(?i)security boundary unclear|unclear security boundary") {
        $escalationTriggers += "security boundary unclear"
    }
    if ($TokenPressureNote -match "^HIGH") {
        $escalationTriggers += "high token pressure"
    }
    if ($activeText -match "(?i)product/deploy/secrets boundary") {
        $escalationTriggers += "product/deploy/secrets boundary"
    }
    if ($activeText -match '(?i)\bperfect\b|best possible|perfection') {
        $escalationTriggers += 'explicit Tim "perfect" request'
    }

    $blockedConditions = @($blockedConditions | Sort-Object -Unique)
    $escalationTriggers = @($escalationTriggers | Sort-Object -Unique)

    if ($blockedConditions.Count -gt 0) {
        return [pscustomobject]@{
            recommendationStatus = "BLOCKED"
            recommendedModelAlias = $null
            reason = "Blocked conditions found; choose no model alias and send to HQ for repacketization."
            confidence = "HIGH"
            escalationTriggersFound = $escalationTriggers
            blockedConditionsFound = $blockedConditions
        }
    }

    $isReadOnly = $Text -match "(?i)\bread-only\b|status check|status review|audit"
    $isPatch = $Text -match "(?i)\bpatch\b|allowed files|bounded|edit|docs/tests|script"
    $isPolicyOrSecurity = $activeText -match "(?i)\bworkflow\b|\bpolicy\b|\barchitecture\b|security boundary|ambiguous|meaningful ambiguity"
    $isAudit = $activeText -match "(?i)external audit|go/no-go|final audit|high-stakes safety"
    $isSelectedBoundedTask = $Text -match "(?i)selected task|proof-run|allowed files"

    if ($QualityMode -eq "perfection" -or $isAudit) {
        $alias = "premium_audit"
        $reason = "Audit or perfection-mode packet without blocked conditions."
        $confidence = "HIGH"
    } elseif ($isPolicyOrSecurity -and -not $isSelectedBoundedTask) {
        $alias = "deep_reasoning"
        $reason = "Workflow, policy, architecture, or security-boundary task without blocked conditions."
        $confidence = "MEDIUM"
    } elseif ($isReadOnly -and -not $isPatch) {
        $alias = "fast_readonly"
        $reason = "Read-only/status packet with no patch indicators."
        $confidence = "HIGH"
    } else {
        $alias = "standard_patch"
        $reason = "Bounded best-value patch or proof task with allowed files and validation commands."
        $confidence = "HIGH"
    }

    if ($escalationTriggers.Count -gt 0 -and $confidence -eq "HIGH") {
        $confidence = "MEDIUM"
    }

    return [pscustomobject]@{
        recommendationStatus = "GREEN"
        recommendedModelAlias = $alias
        reason = $reason
        confidence = $confidence
        escalationTriggersFound = $escalationTriggers
        blockedConditionsFound = $blockedConditions
    }
}

$resolvedPacket = Resolve-FleetPacketPath -Path $TaskPacket
if (-not (Test-Path -LiteralPath $resolvedPacket -PathType Leaf)) {
    throw "Task packet not found: $(Get-PublicPacketLabel -Path $resolvedPacket)"
}

$packetText = Get-Content -LiteralPath $resolvedPacket -Raw -ErrorAction Stop
$packetLines = $packetText -split "`r?`n"
$qualityMode = Get-QualityMode -Text $packetText
$tokenPressureNote = Get-TokenPressureNote -Text $packetText
$recommendation = Get-ModelRoutingRecommendation -Text $packetText -Lines $packetLines -QualityMode $qualityMode -TokenPressureNote $tokenPressureNote

[pscustomobject]@{
    schemaVersion = 1
    tool = "fleet-model-routing-preflight"
    evidenceOnly = $true
    recommendationOnly = $true
    executesTasks = $false
    modifiesTaskPacket = $false
    callsModelApis = $false
    taskPacket = Get-PublicPacketLabel -Path $resolvedPacket
    qualityMode = $qualityMode
    recommendationStatus = $recommendation.recommendationStatus
    recommendedModelAlias = $recommendation.recommendedModelAlias
    reason = $recommendation.reason
    confidence = $recommendation.confidence
    escalationTriggersFound = @($recommendation.escalationTriggersFound)
    blockedConditionsFound = @($recommendation.blockedConditionsFound)
    tokenPressureNote = $tokenPressureNote
    allowedAliases = $allowedAliases
} | ConvertTo-Json -Depth 6
