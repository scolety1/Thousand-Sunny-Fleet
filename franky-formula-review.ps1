[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$Project = "",

    [string]$OutFile = "docs/codex/FRANKY_FORMULA_REVIEW.md"
)

$ErrorActionPreference = "Continue"

function Normalize-Path {
    param([string]$Path)
    return ([string]$Path).Replace("\", "/")
}

function Get-MarkdownValue {
    param([string]$Text, [string]$Heading)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $match = [regex]::Match($Text, "(?is)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (!$match.Success) { return "" }
    return $match.Groups["body"].Value.Trim()
}

function Test-ConcreteSection {
    param([string]$Text, [string]$Heading)
    $value = Get-MarkdownValue -Text $Text -Heading $Heading
    return (![string]::IsNullOrWhiteSpace($value) -and $value -notmatch "(?i)\b(todo|tbd|placeholder|unknown|later)\b")
}

function Get-TrackedFiles {
    return @(git ls-files 2>$null | ForEach-Object { Normalize-Path $_ })
}

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Split-Path -Leaf $repoPath.Path
}

$branch = git branch --show-current 2>$null
$head = git rev-parse --short HEAD 2>$null
$dirty = @(git status --short 2>$null)
$branchChanged = @(git diff --name-only "$BaseBranch..HEAD" 2>$null | ForEach-Object { Normalize-Path $_ })
$stagedChanged = @(git diff --cached --name-only 2>$null | ForEach-Object { Normalize-Path $_ })
$worktreeChanged = @(git diff --name-only 2>$null | ForEach-Object { Normalize-Path $_ })
$statusChanged = @(git status --porcelain 2>$null | ForEach-Object {
        $line = [string]$_
        if ($line.Length -gt 3) { Normalize-Path $line.Substring(3).Trim() }
    } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
$changed = @($branchChanged + $stagedChanged + $worktreeChanged + $statusChanged | Sort-Object -Unique)
$changedStatus = @(git diff --name-status "$BaseBranch..HEAD" 2>$null)
$tracked = @(Get-TrackedFiles)

$taskQueue = if (Test-Path "docs/codex/TASK_QUEUE.md") { Get-Content "docs/codex/TASK_QUEUE.md" -Raw } else { "" }
$phaseState = if (Test-Path "docs/codex/PHASE_STATE.md") { Get-Content "docs/codex/PHASE_STATE.md" -Raw } else { "" }
$formulaSpec = if (Test-Path "docs/codex/FORMULA_SPEC.md") { Get-Content "docs/codex/FORMULA_SPEC.md" -Raw } else { "" }
$fixturePlan = if (Test-Path "docs/codex/FIXTURE_TEST_PLAN.md") { Get-Content "docs/codex/FIXTURE_TEST_PLAN.md" -Raw } else { "" }
$analysisApproval = if (Test-Path "docs/codex/ANALYSIS_APPROVAL.md") { Get-Content "docs/codex/ANALYSIS_APPROVAL.md" -Raw } else { "" }
$numberProvenance = if (Test-Path "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md") { Get-Content "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md" -Raw } else { "" }
$calibration = if (Test-Path "docs/codex/CALIBRATION_READINESS.md") { Get-Content "docs/codex/CALIBRATION_READINESS.md" -Raw } else { "" }

$formulaPathPattern = "(?i)(^|/)(models|model|scoring|score|formula|analytics|analysis|rank|ranking|valuation|projection|recommendation|services)(/|$)|(^|/)tests?/.*(score|formula|model|trade|rank|pick|keeper|import|calibration)|FORMULA_SPEC\.md|FIXTURE_TEST_PLAN\.md|MODEL_SPEC\.md|DATA_MODEL\.md"
$formulaIntentPattern = "(?i)\b(formula|score|rank|ranking|probability|forecast|valuation|keeper|trade|pick value|confidence|calibration|expected output|fixture|model output|recommendation)\b"

$formulaFilesChanged = @($changed | Where-Object { $_ -match $formulaPathPattern })
$formulaIntent = (
    $formulaFilesChanged.Count -gt 0 -or
    $taskQueue -match $formulaIntentPattern -or
    $phaseState -match "(?i)(formula-spec|fixture-tests|engine-build|calibration|dashboard|scenario-tools|analysis-proof)"
)

$testFilesChanged = @($changed | Where-Object { $_ -match "(?i)(^|/)tests?/|test_.*\.py$|\.test\.(js|jsx|ts|tsx)$|\.spec\.(js|jsx|ts|tsx)$" })
$formulaTestsTracked = @($tracked | Where-Object { $_ -match "(?i)(^|/)tests?/.*(formula|score|model|trade|rank|pick|keeper|calibration|import)|test_.*(formula|score|model|trade|rank|pick|keeper|calibration|import).*\.py$|.*(formula|score|model|trade|rank|pick|keeper|calibration|import).*\.(test|spec)\.(js|jsx|ts|tsx)$" })

$issues = [System.Collections.Generic.List[object]]::new()
function Add-Issue {
    param([string]$Level, [string]$Message)
    $issues.Add([pscustomobject]@{ level = $Level; message = $Message }) | Out-Null
}

if (!$formulaIntent) {
    Add-Issue -Level "INFO" -Message "No formula-sensitive task, phase, or file change detected."
} else {
    if ([string]::IsNullOrWhiteSpace($formulaSpec)) {
        Add-Issue -Level "RED" -Message "Formula-sensitive work is present but docs/codex/FORMULA_SPEC.md is missing."
    } else {
        foreach ($heading in @("Formulas", "Inputs", "Outputs")) {
            if (-not (Test-ConcreteSection -Text $formulaSpec -Heading $heading)) {
                Add-Issue -Level "RED" -Message "FORMULA_SPEC.md needs concrete non-placeholder content under '$heading'."
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($fixturePlan)) {
        Add-Issue -Level "RED" -Message "Formula-sensitive work is present but docs/codex/FIXTURE_TEST_PLAN.md is missing."
    } else {
        foreach ($heading in @("Fixture Data", "Expected Outputs", "Formula Tests")) {
            if (-not (Test-ConcreteSection -Text $fixturePlan -Heading $heading)) {
                Add-Issue -Level "RED" -Message "FIXTURE_TEST_PLAN.md needs concrete non-placeholder content under '$heading'."
            }
        }
    }

    if ($analysisApproval -notmatch "(?im)^\s*Status:\s*APPROVED\s*$") {
        Add-Issue -Level "YELLOW" -Message "Analysis approval is missing or not approved; formula work should stay narrow until approved."
    }

    if ($formulaFilesChanged.Count -gt 0 -and $testFilesChanged.Count -eq 0 -and $formulaTestsTracked.Count -eq 0) {
        Add-Issue -Level "RED" -Message "Formula/model files changed but no formula-oriented tests are changed or tracked."
    } elseif ($formulaFilesChanged.Count -gt 0 -and $testFilesChanged.Count -eq 0) {
        Add-Issue -Level "YELLOW" -Message "Formula/model files changed without changed tests; verify existing formula tests assert the new behavior."
    }

    if ($numberProvenance -match "(?is)## Verdict\s+RED\b") {
        Add-Issue -Level "RED" -Message "Analytical number provenance is RED."
    } elseif ([string]::IsNullOrWhiteSpace($numberProvenance)) {
        Add-Issue -Level "YELLOW" -Message "No analytical number provenance report found."
    }

    if ($calibration -match "(?is)## Verdict\s+RED\b") {
        Add-Issue -Level "YELLOW" -Message "Calibration readiness is RED; do not present formula outputs as reliable insight."
    }
}

$redCount = @($issues | Where-Object { $_.level -eq "RED" }).Count
$yellowCount = @($issues | Where-Object { $_.level -eq "YELLOW" }).Count
$verdict = if ($redCount -gt 0) { "RED" } elseif ($yellowCount -gt 0) { "YELLOW" } else { "GREEN" }
$nextStep = if ($verdict -eq "RED") { "stop for human formula review" } elseif ($verdict -eq "YELLOW") { "continue but verify formula evidence first" } else { "continue" }

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = @(
    "# Franky Formula Review",
    "",
    "Generated: $date",
    "Project: $Project",
    "Branch: $branch",
    "HEAD: $head",
    "Base branch: $BaseBranch",
    "",
    "## Verdict",
    $verdict,
    "",
    "## Franky's Read",
    "Franky checked the formula specs, fixture expectations, tests, provenance, and confidence boundaries so analytical work does not become fake-confidence soup.",
    "",
    "## Formula Surface",
    "- Formula intent detected: $formulaIntent",
    "- Formula-sensitive changed files: $(if ($formulaFilesChanged.Count -gt 0) { $formulaFilesChanged -join ', ' } else { 'none' })",
    "- Test files changed: $(if ($testFilesChanged.Count -gt 0) { $testFilesChanged -join ', ' } else { 'none' })",
    "- Tracked formula tests: $(if ($formulaTestsTracked.Count -gt 0) { $formulaTestsTracked -join ', ' } else { 'none' })",
    "- Dirty files: $(if ($dirty.Count -gt 0) { $dirty -join '; ' } else { 'clean' })",
    "",
    "## Findings"
)

foreach ($issue in $issues) {
    $lines += "- [$($issue.level)] $($issue.message)"
}

$lines += @(
    "",
    "## Formula Evidence Rules",
    "- Every formula change needs a plain-English or pseudocode formula in FORMULA_SPEC.md.",
    "- Every important formula needs at least one fixture input and hand-calculated expected output.",
    "- Formula/model code changes need formula-oriented tests or explicit evidence that existing tests cover the behavior.",
    "- User-facing scores, ranks, probabilities, and recommendations must be computed, sourced, or fixture-backed.",
    "- Calibration gaps must be visible; do not let the UI imply certainty the model has not earned.",
    "",
    "## Stop Or Continue",
    $nextStep
)

$parent = Split-Path -Parent $OutFile
if (![string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$lines -join "`n" | Set-Content $OutFile -Encoding UTF8

Write-Host "Franky formula review: $verdict"
Write-Host "Report: $OutFile"

if ($verdict -eq "RED") { exit 1 }
exit 0
