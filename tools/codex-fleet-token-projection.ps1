[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$PromptText = "",
    [string[]]$ReadFiles = @(),
    [string[]]$ValidationCommands = @(),
    [int]$ExpectedPatchTokens = 0,
    [int]$ReserveOutputTokens = 8000,
    [int]$MaxContextTokens = 128000,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Get-FleetEstimatedTokenCount {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $charEstimate = [Math]::Ceiling($Text.Length / 4.0)
    $wordCount = @($Text -split "\s+" | Where-Object { ![string]::IsNullOrWhiteSpace($_) }).Count
    $wordEstimate = [Math]::Ceiling($wordCount * 1.35)
    return [int]([Math]::Max($charEstimate, $wordEstimate))
}

function ConvertTo-FleetTokenProjectionStringArray {
    param([AllowNull()][object]$Value)

    $items = @()
    foreach ($item in @($Value)) {
        if ($null -eq $item) { continue }
        foreach ($part in ([string]$item -split ",")) {
            $trimmed = $part.Trim()
            if (![string]::IsNullOrWhiteSpace($trimmed)) { $items += $trimmed }
        }
    }
    return @($items)
}

function Resolve-FleetTokenProjectionPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$FleetRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($FleetRoot)
    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $resolvedRoot $Path }
    $resolved = [System.IO.Path]::GetFullPath($candidate)
    if (!$resolved.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Token projection refuses to read outside fleet root: $Path"
    }
    if ($resolved -match "(?i)(^|[\\/])\.env($|[\\/])|secret|credential|private[-_]?key|payment|stripe") {
        throw "Token projection refuses to read sensitive-looking path: $Path"
    }
    return $resolved
}

function New-FleetTokenProjection {
    param(
        [string]$PromptText = "",
        [string[]]$ReadFiles = @(),
        [string[]]$ValidationCommands = @(),
        [int]$ExpectedPatchTokens = 0,
        [int]$ReserveOutputTokens = 8000,
        [int]$MaxContextTokens = 128000,
        [string]$FleetRoot = (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    )

    if ($MaxContextTokens -le 0) { throw "MaxContextTokens must be positive." }
    if ($ReserveOutputTokens -lt 0) { throw "ReserveOutputTokens cannot be negative." }
    if ($ExpectedPatchTokens -lt 0) { throw "ExpectedPatchTokens cannot be negative." }

    $readFileRecords = @()
    $readFileTokens = 0
    foreach ($path in @(ConvertTo-FleetTokenProjectionStringArray -Value $ReadFiles)) {
        $resolved = Resolve-FleetTokenProjectionPath -Path $path -FleetRoot $FleetRoot
        if (!(Test-Path -LiteralPath $resolved -PathType Leaf)) {
            throw "Token projection read file does not exist: $path"
        }
        $text = Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop
        $tokens = Get-FleetEstimatedTokenCount -Text $text
        $readFileTokens += $tokens
        $readFileRecords += [pscustomobject]@{
            path = $path
            estimatedTokens = $tokens
            characterCount = $text.Length
        }
    }

    $promptTokens = Get-FleetEstimatedTokenCount -Text $PromptText
    $validationText = (@(ConvertTo-FleetTokenProjectionStringArray -Value $ValidationCommands) -join "`n")
    $validationTokens = Get-FleetEstimatedTokenCount -Text $validationText
    $totalEstimatedTokens = $promptTokens + $readFileTokens + $validationTokens + $ExpectedPatchTokens + $ReserveOutputTokens
    $usagePercent = [Math]::Round(($totalEstimatedTokens / [double]$MaxContextTokens) * 100, 2)

    $decision = "GREEN_PROCEED"
    $pressure = "normal"
    $recommendations = @("Proceed with one bounded task and keep the final report concise.")
    if ($usagePercent -ge 90) {
        $decision = "RED_SPLIT_OR_STOP"
        $pressure = "critical"
        $recommendations = @(
            "Split or repacketize before implementation.",
            "Replace long source material with a compact digest.",
            "Reduce readFirst files or expected patch scope."
        )
    } elseif ($usagePercent -ge 70) {
        $decision = "YELLOW_COMPRESS"
        $pressure = "watch"
        $recommendations = @(
            "Compress historical context before running.",
            "Read only the active task and exact readFirst files.",
            "Avoid broad searches and long validation logs."
        )
    }

    return [pscustomobject]@{
        schemaVersion = 1
        evidenceOnly = $true
        executes = $false
        decision = $decision
        pressure = $pressure
        maxContextTokens = $MaxContextTokens
        reserveOutputTokens = $ReserveOutputTokens
        expectedPatchTokens = $ExpectedPatchTokens
        promptTokens = $promptTokens
        readFileTokens = $readFileTokens
        validationCommandTokens = $validationTokens
        totalEstimatedTokens = $totalEstimatedTokens
        usagePercent = $usagePercent
        readFiles = @($readFileRecords)
        recommendations = @($recommendations)
        nonAuthorityNotice = "Token projection is local conservative evidence only. It is not billing proof, model availability proof, execution authority, product-repo approval, or permission to weaken safety boundaries."
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $projection = New-FleetTokenProjection -PromptText $PromptText -ReadFiles $ReadFiles -ValidationCommands $ValidationCommands -ExpectedPatchTokens $ExpectedPatchTokens -ReserveOutputTokens $ReserveOutputTokens -MaxContextTokens $MaxContextTokens
    if ($AsJson) {
        $projection | ConvertTo-Json -Depth 8
    } else {
        Write-Host "Token projection: $($projection.decision) ($($projection.usagePercent)% of max context)"
        Write-Host "Estimated total: $($projection.totalEstimatedTokens)"
        Write-Host "Prompt: $($projection.promptTokens) | Read files: $($projection.readFileTokens) | Validation: $($projection.validationCommandTokens) | Patch: $($projection.expectedPatchTokens) | Reserve: $($projection.reserveOutputTokens)"
        foreach ($recommendation in @($projection.recommendations)) {
            Write-Host "- $recommendation"
        }
    }
}
