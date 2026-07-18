[CmdletBinding()]
param(
    [string]$BaseRef = 'refs/remotes/origin/main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$assertions = 0

function Assert-StaticIntegrity {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$Message
    )
    $script:assertions++
    if (-not $Condition) {
        throw "Static integrity assertion failed: $Message"
    }
}

Push-Location $repoRoot
try {
    $committedFiles = @(& git diff --name-only "$BaseRef...HEAD")
    $committedDiffExit = $LASTEXITCODE
    Assert-StaticIntegrity -Condition ($committedDiffExit -eq 0) -Message "git diff against $BaseRef must succeed"

    $workingFiles = @(
        & git status --porcelain=v1 -uall |
            ForEach-Object { $_.Substring(3) } |
            Where-Object { $_ -notlike '.codex-local/*' }
    )
    Assert-StaticIntegrity -Condition ($LASTEXITCODE -eq 0) -Message 'git status must succeed'
    $candidateFiles = @($committedFiles + $workingFiles | Where-Object { $_ } | Sort-Object -Unique)
    Assert-StaticIntegrity -Condition ($candidateFiles.Count -gt 0) -Message 'static correction files must be discoverable'

    $powerShellFiles = @($candidateFiles | Where-Object { $_ -like '*.ps1' })
    foreach ($relativePath in $powerShellFiles) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $repoRoot $relativePath),
            [ref]$tokens,
            [ref]$errors
        )
        Assert-StaticIntegrity -Condition ($errors.Count -eq 0) -Message "PowerShell parser: $relativePath"
    }

    $jsonFiles = @($candidateFiles | Where-Object { $_ -like '*.json' })
    foreach ($relativePath in $jsonFiles) {
        $json = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw | ConvertFrom-Json
        Assert-StaticIntegrity -Condition ($null -ne $json) -Message "JSON parse: $relativePath"
    }

    $csvFiles = @($candidateFiles | Where-Object { $_ -like '*.csv' })
    foreach ($relativePath in $csvFiles) {
        $csvRows = @(Import-Csv -LiteralPath (Join-Path $repoRoot $relativePath))
        Assert-StaticIntegrity -Condition ($csvRows.Count -gt 0) -Message "CSV parse and non-empty: $relativePath"
    }

    $nodeOutput = & node --check (Join-Path $repoRoot 'tools/tsf-codex-app-server-adapter.mjs') 2>&1
    Assert-StaticIntegrity -Condition ($LASTEXITCODE -eq 0) -Message "Node syntax: $($nodeOutput -join ' ')"

    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $diffCheck = & git diff --check "$BaseRef...HEAD" 2>&1
    $ErrorActionPreference = $savedErrorActionPreference
    Assert-StaticIntegrity -Condition ($LASTEXITCODE -eq 0) -Message "git committed candidate diff --check: $($diffCheck -join ' ')"

    $ErrorActionPreference = 'Continue'
    $workingDiffCheck = & git diff --check 2>&1
    $ErrorActionPreference = $savedErrorActionPreference
    Assert-StaticIntegrity -Condition ($LASTEXITCODE -eq 0) -Message "git working-tree diff --check: $($workingDiffCheck -join ' ')"

    $ErrorActionPreference = 'Continue'
    $stagedDiffCheck = & git diff --cached --check 2>&1
    $ErrorActionPreference = $savedErrorActionPreference
    Assert-StaticIntegrity -Condition ($LASTEXITCODE -eq 0) -Message "git diff --cached --check: $($stagedDiffCheck -join ' ')"

    $staleMarkers = @(
        & rg -n 'TO_BE_REPORTED_AFTER_SINGLE_LOCAL_COMMIT|POST_COMMIT_OBSERVATION_REQUIRED' docs 2>$null
    )
    Assert-StaticIntegrity -Condition ($staleMarkers.Count -eq 0) -Message 'stale or self-referential validation placeholders must be absent'

    Write-Output "PASS assertions=$assertions"
}
finally {
    Pop-Location
}
