[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/SCENARIO_READINESS.md",

    [switch]$Template,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"
$script:OriginalLocation = (Get-Location).Path
$script:DefaultOutFile = "docs/codex/SCENARIO_READINESS.md"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-MarkdownSection {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $escaped = [regex]::Escape($Heading)
    $match = [regex]::Match($Text, "(?ims)^##\s+$escaped\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (!$match.Success) { return "" }
    return $match.Groups["body"].Value.Trim()
}

function Test-SectionHasSubstance {
    param(
        [string]$Text,
        [string]$Heading
    )

    $body = Get-MarkdownSection -Text $Text -Heading $Heading
    if ([string]::IsNullOrWhiteSpace($body)) { return $false }
    if ($body -match "(?i)\bTODO\b|to be decided|tbd|placeholder") { return $false }
    $contentLines = @($body -split "\r?\n" | Where-Object {
        $line = ([string]$_).Trim()
        ![string]::IsNullOrWhiteSpace($line) -and
            $line -notmatch "^\s*<!--" -and
            $line -notmatch "^\s*$"
    })
    return ($contentLines.Count -gt 0)
}

function Get-TrackedOrExistingFiles {
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(git ls-files 2>$null) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace([string]$_)) {
            $files.Add(([string]$_).Replace("\", "/")) | Out-Null
        }
    }

    foreach ($root in @("tests", "test", "__tests__", "fixtures", "sample_data", "data_packs")) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $base = (Get-Location).Path.TrimEnd("\", "/")
                $full = $_.FullName
                $relative = if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $full.Substring($base.Length).TrimStart("\", "/")
                } else {
                    $full
                }
                $files.Add($relative.Replace("\", "/")) | Out-Null
            }
        }
    }

    return @($files)
}

function Resolve-OutputPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    if ($Path -eq $script:DefaultOutFile) {
        return $Path
    }

    return (Join-Path $script:OriginalLocation $Path)
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$specPath = "docs/codex/SCENARIO_SPEC.md"
$approvalPath = "docs/codex/SCENARIO_APPROVAL.md"

if ($Template) {
    New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
    if (!(Test-Path $specPath)) {
        Set-Content -Path $specPath -Encoding UTF8 -Value @(
            "# Scenario Spec",
            "",
            "## Scenario Inventory",
            "",
            "List each approved what-if scenario, strategy mode, slider, toggle, or weight change.",
            "",
            "## Inputs That May Change",
            "",
            "Name every input the scenario can change and its allowed range or options.",
            "",
            "## Formulas Affected",
            "",
            "Name the formulas, scores, validators, reports, or tables affected by each scenario.",
            "",
            "## Expected Output Changes",
            "",
            "Describe which output columns, labels, scores, probabilities, or rankings should move when each input changes.",
            "",
            "## Outputs That Must Remain Fixed",
            "",
            "Name outputs that must not change under the scenario, such as official ranks, source metadata, immutable IDs, imported facts, or raw snapshot values.",
            "",
            "## Scenario Tests",
            "",
            "List the test files or expected fixtures that prove changing an input changes the expected output and leaves fixed outputs unchanged.",
            "",
            "## UI Label Assumptions",
            "",
            "Write the exact plain-language assumptions the UI must show near scenario controls."
        )
    }
    if (!(Test-Path $approvalPath)) {
        Set-Content -Path $approvalPath -Encoding UTF8 -Value @(
            "# Scenario Approval",
            "",
            "Status: DRAFT",
            "",
            "Approve only after SCENARIO_SPEC.md names the allowed scenario inputs, affected formulas, expected output changes, fixed outputs, tests, and UI assumption labels."
        )
    }
    Write-Host "Scenario templates are ready." -ForegroundColor Green
    exit 0
}

$issues = [System.Collections.Generic.List[string]]::new()
if (!(Test-Path $specPath)) {
    $issues.Add("Missing docs/codex/SCENARIO_SPEC.md. Run analytical-scenario-approval.ps1 -Template first.") | Out-Null
    $specText = ""
} else {
    $specText = Get-Content $specPath -Raw
}

$requiredHeadings = @(
    "Scenario Inventory",
    "Inputs That May Change",
    "Formulas Affected",
    "Expected Output Changes",
    "Outputs That Must Remain Fixed",
    "Scenario Tests",
    "UI Label Assumptions"
)
foreach ($heading in $requiredHeadings) {
    if ($specText -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
        $issues.Add("SCENARIO_SPEC.md missing heading: $heading.") | Out-Null
    } elseif (!(Test-SectionHasSubstance -Text $specText -Heading $heading)) {
        $issues.Add("SCENARIO_SPEC.md section needs concrete non-TODO content: $heading.") | Out-Null
    }
}

if (!(Test-Path $approvalPath)) {
    $issues.Add("Missing docs/codex/SCENARIO_APPROVAL.md.") | Out-Null
} else {
    $approvalText = Get-Content $approvalPath -Raw
    if ($approvalText -notmatch "(?im)^\s*Status:\s*APPROVED\s*$") {
        $issues.Add("SCENARIO_APPROVAL.md must contain 'Status: APPROVED' before scenario-tools work.") | Out-Null
    }
}

$files = @(Get-TrackedOrExistingFiles)
$scenarioTestFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(tests?|__tests__)(/|$).*(scenario|what.?if|strategy|mode|sensitivity|weight|slider).*\.(py|js|jsx|ts|tsx|ps1|md)$"
})
$scenarioFixtureFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(fixtures?|sample_data|data_packs)(/|$).*(scenario|what.?if|strategy|mode|sensitivity|weight|expected).*\.(csv|tsv|json|jsonl|yaml|yml|md|txt)$"
})
if ($scenarioTestFiles.Count -eq 0 -and $scenarioFixtureFiles.Count -eq 0) {
    $issues.Add("No scenario test or expected fixture evidence found. Add a test/fixture showing one input change affects expected outputs and preserves fixed outputs.") | Out-Null
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Scenario Readiness",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "## Verdict",
    "",
    $verdict,
    "",
    "## Findings",
    ""
)
if ($issues.Count -eq 0) {
    $lines += "- Scenario approval gate passed."
} else {
    $issues | ForEach-Object { $lines += "- [RED] $_" }
}
$lines += ""
$lines += "## Evidence"
$lines += ""
$lines += "- Scenario test files: $($scenarioTestFiles.Count)"
$lines += "- Scenario fixture files: $($scenarioFixtureFiles.Count)"
foreach ($file in @($scenarioTestFiles + $scenarioFixtureFiles | Sort-Object -Unique | Select-Object -First 40)) {
    $lines += "  - $file"
}
$lines += ""
$lines += "## Rule"
$lines += ""
$lines += "Scenario tools require an approved spec before controls can change formula behavior. Each scenario must say which inputs may change, which formulas are affected, which outputs should change, which outputs must remain fixed, and what assumptions the UI must label."

if (!$ValidateOnly -or $issues.Count -gt 0) {
    $resolvedOutFile = Resolve-OutputPath -Path $OutFile
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutFile) | Out-Null
    Set-Content -Path $resolvedOutFile -Encoding UTF8 -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Scenario approval failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Scenario approval passed." -ForegroundColor Green
exit 0
