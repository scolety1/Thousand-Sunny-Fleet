[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$Project = "",

    [string]$OutFile = "docs/codex/FRANKY_FORMULA_REVIEW.md",

    [string]$JsonOutFile = "docs/codex/FRANKY_FORMULA_REVIEW.json",

    [switch]$Template
)

$ErrorActionPreference = "Continue"

function Normalize-Path {
    param([string]$Path)
    return ([string]$Path).Replace("\", "/")
}

function Ensure-OutputParent {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function New-TemplateFileIfMissing {
    param([string]$Path, [string[]]$Lines)
    if (Test-Path -LiteralPath $Path) {
        Write-Host "Template already exists: $Path"
        return
    }
    Ensure-OutputParent -Path $Path
    $Lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Host "Created template: $Path"
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

if ($Template) {
    New-TemplateFileIfMissing -Path "docs/codex/FORMULA_SPEC.md" -Lines @(
        "# Formula Spec",
        "",
        "Project: $Project",
        "",
        "## Formulas",
        "TBD: list each deterministic formula by name with weights, constants, and tie-break rules.",
        "",
        "## Inputs",
        "TBD: list every required input column, unit, accepted range, default, and missing-data rule.",
        "",
        "## Outputs",
        "TBD: list every score, rank, probability, recommendation, and confidence label shown to users.",
        "",
        "## Guardrails",
        "- Do not present uncalibrated probabilities as certainty.",
        "- Do not mix official/source rankings with private strategy scores unless the formula says how.",
        "- Every visible number needs a source, formula, or fixture-backed derivation."
    )
    New-TemplateFileIfMissing -Path "docs/codex/FIXTURE_TEST_PLAN.md" -Lines @(
        "# Fixture Test Plan",
        "",
        "Project: $Project",
        "",
        "## Fixture Data",
        "TBD: add small hand-checkable input rows that cover normal, edge, and missing-data cases.",
        "",
        "## Expected Outputs",
        "TBD: add hand-calculated expected results for each important formula and recommendation.",
        "",
        "## Formula Tests",
        "TBD: name the exact tests or acceptance commands that prove the fixture outputs match the code."
    )
    New-TemplateFileIfMissing -Path "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md" -Lines @(
        "# Analytical Number Provenance",
        "",
        "## Verdict",
        "YELLOW",
        "",
        "## Source Map",
        "TBD: map every user-facing number to a formula, fixture, source file, or imported dataset.",
        "",
        "## Unverified Numbers",
        "TBD: list numbers that are demo-only, manually seeded, or still need source verification."
    )
    New-TemplateFileIfMissing -Path "docs/codex/CALIBRATION_READINESS.md" -Lines @(
        "# Calibration Readiness",
        "",
        "## Verdict",
        "YELLOW",
        "",
        "## Calibration Status",
        "TBD: explain whether probabilities/scores are calibrated, heuristic-only, or demo-only.",
        "",
        "## User-Facing Caveats",
        "TBD: define the exact caveats needed anywhere confidence, probability, or recommendation labels appear."
    )
    exit 0
}

$branch = git branch --show-current 2>$null
$head = git rev-parse --short HEAD 2>$null
$dirty = @(git status --short 2>$null)
$baseExists = $false
git rev-parse --verify "$BaseBranch^{commit}" *> $null
if ($LASTEXITCODE -eq 0) {
    $baseExists = $true
}
$branchChanged = if ($baseExists) { @(git diff --name-only "$BaseBranch..HEAD" 2>$null | ForEach-Object { Normalize-Path $_ }) } else { @() }
$stagedChanged = @(git diff --cached --name-only 2>$null | ForEach-Object { Normalize-Path $_ })
$worktreeChanged = @(git diff --name-only 2>$null | ForEach-Object { Normalize-Path $_ })
$statusChanged = @(git status --porcelain 2>$null | ForEach-Object {
        $line = [string]$_
        if ($line.Length -gt 3) { Normalize-Path $line.Substring(3).Trim() }
    } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
$changed = @($branchChanged + $stagedChanged + $worktreeChanged + $statusChanged | Sort-Object -Unique)
$changedStatus = if ($baseExists) { @(git diff --name-status "$BaseBranch..HEAD" 2>$null) } else { @() }
$tracked = @(Get-TrackedFiles)

$taskQueue = if (Test-Path "docs/codex/TASK_QUEUE.md") { Get-Content "docs/codex/TASK_QUEUE.md" -Raw } else { "" }
$phaseState = if (Test-Path "docs/codex/PHASE_STATE.md") { Get-Content "docs/codex/PHASE_STATE.md" -Raw } else { "" }
$formulaSpec = if (Test-Path "docs/codex/FORMULA_SPEC.md") { Get-Content "docs/codex/FORMULA_SPEC.md" -Raw } else { "" }
$fixturePlan = if (Test-Path "docs/codex/FIXTURE_TEST_PLAN.md") { Get-Content "docs/codex/FIXTURE_TEST_PLAN.md" -Raw } else { "" }
$analysisApproval = if (Test-Path "docs/codex/ANALYSIS_APPROVAL.md") { Get-Content "docs/codex/ANALYSIS_APPROVAL.md" -Raw } else { "" }
$numberProvenance = if (Test-Path "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md") { Get-Content "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md" -Raw } else { "" }
$calibration = if (Test-Path "docs/codex/CALIBRATION_READINESS.md") { Get-Content "docs/codex/CALIBRATION_READINESS.md" -Raw } else { "" }

$formulaPathPattern = "(?i)(^|/)(models|model|scoring|score|formula|analytics|analysis|rank|ranking|valuation|projection|recommendation|services)(/|$)|(^|/)tests?/.*(score|formula|model|trade|rank|pick|keeper|import|calibration)|FORMULA_SPEC\.md|FIXTURE_TEST_PLAN\.md|MODEL_SPEC\.md|DATA_MODEL\.md"
$formulaIntentPattern = "(?i)\b(formula|score|rank|ranking|probability|forecast|valuation|keeper|trade|pick value|confidence|calibration|expected output|fixture|model output)\b"
$currentPhaseMatch = [regex]::Match($phaseState, "(?im)^Current Phase:\s*(problem-brief|data-contract|formula-spec|fixture-tests|engine-build|calibration|dashboard|scenario-tools|analysis-proof)\s*$")
$analyticalPhaseIntent = $currentPhaseMatch.Success
$analyticalDocsPresent = (
    (Test-Path "docs/codex/ANALYSIS_BRIEF.md") -or
    (Test-Path "docs/codex/DATA_CONTRACT.md") -or
    (Test-Path "docs/codex/FORMULA_SPEC.md") -or
    (Test-Path "docs/codex/FIXTURE_TEST_PLAN.md") -or
    (Test-Path "docs/codex/ANALYSIS_APPROVAL.md")
)

$formulaFilesChanged = @($changed | Where-Object { $_ -match $formulaPathPattern })
$taskFormulaIntent = ($taskQueue -match $formulaIntentPattern) -and ($analyticalPhaseIntent -or $analyticalDocsPresent)
$formulaIntent = (
    $formulaFilesChanged.Count -gt 0 -or
    $taskFormulaIntent -or
    $analyticalPhaseIntent
)

$testFilesChanged = @($changed | Where-Object { $_ -match "(?i)(^|/)tests?/|test_.*\.py$|\.test\.(js|jsx|ts|tsx)$|\.spec\.(js|jsx|ts|tsx)$" })
$formulaTestsTracked = @($tracked | Where-Object { $_ -match "(?i)(^|/)tests?/.*(formula|score|model|trade|rank|pick|keeper|calibration|import)|test_.*(formula|score|model|trade|rank|pick|keeper|calibration|import).*\.py$|.*(formula|score|model|trade|rank|pick|keeper|calibration|import).*\.(test|spec)\.(js|jsx|ts|tsx)$" })

$issues = [System.Collections.Generic.List[object]]::new()
function Add-Issue {
    param([string]$Level, [string]$Message, [string]$Action = "")
    if ([string]::IsNullOrWhiteSpace($Action)) {
        $Action = "Review the finding and add concrete formula evidence before treating analytical output as trustworthy."
    }
    $issues.Add([pscustomobject]@{ level = $Level; message = $Message; action = $Action }) | Out-Null
}

if (!$formulaIntent) {
    Add-Issue -Level "INFO" -Message "No formula-sensitive task, phase, or file change detected." -Action "No formula repair needed."
} else {
    if ([string]::IsNullOrWhiteSpace($formulaSpec)) {
        Add-Issue -Level "RED" -Message "Formula-sensitive work is present but docs/codex/FORMULA_SPEC.md is missing." -Action "Create docs/codex/FORMULA_SPEC.md with concrete Formulas, Inputs, and Outputs sections."
    } else {
        foreach ($heading in @("Formulas", "Inputs", "Outputs")) {
            if (-not (Test-ConcreteSection -Text $formulaSpec -Heading $heading)) {
                Add-Issue -Level "RED" -Message "FORMULA_SPEC.md needs concrete non-placeholder content under '$heading'." -Action "Replace the '$heading' placeholder with specific formula evidence, not TBD/unknown/later language."
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($fixturePlan)) {
        Add-Issue -Level "RED" -Message "Formula-sensitive work is present but docs/codex/FIXTURE_TEST_PLAN.md is missing." -Action "Create docs/codex/FIXTURE_TEST_PLAN.md with fixture rows, hand-calculated expected outputs, and the formula tests that assert them."
    } else {
        foreach ($heading in @("Fixture Data", "Expected Outputs", "Formula Tests")) {
            if (-not (Test-ConcreteSection -Text $fixturePlan -Heading $heading)) {
                Add-Issue -Level "RED" -Message "FIXTURE_TEST_PLAN.md needs concrete non-placeholder content under '$heading'." -Action "Fill '$heading' with hand-checkable evidence tied to actual tests."
            }
        }
    }

    if ($analysisApproval -notmatch "(?im)^\s*Status:\s*APPROVED\s*$") {
        Add-Issue -Level "YELLOW" -Message "Analysis approval is missing or not approved; formula work should stay narrow until approved." -Action "Keep the next task to evidence or fixture setup until docs/codex/ANALYSIS_APPROVAL.md is explicitly approved."
    }

    if ($formulaFilesChanged.Count -gt 0 -and $testFilesChanged.Count -eq 0 -and $formulaTestsTracked.Count -eq 0) {
        Add-Issue -Level "RED" -Message "Formula/model files changed but no formula-oriented tests are changed or tracked." -Action "Add or update formula-oriented tests before continuing formula/model implementation."
    } elseif ($formulaFilesChanged.Count -gt 0 -and $testFilesChanged.Count -eq 0) {
        Add-Issue -Level "YELLOW" -Message "Formula/model files changed without changed tests; verify existing formula tests assert the new behavior." -Action "Either update the relevant formula tests or cite the existing tests that assert this changed behavior."
    }

    if ($numberProvenance -match "(?is)## Verdict\s+RED\b") {
        Add-Issue -Level "RED" -Message "Analytical number provenance is RED." -Action "Resolve ANALYTICAL_NUMBER_PROVENANCE.md before exposing generated numbers as reliable."
    } elseif ([string]::IsNullOrWhiteSpace($numberProvenance)) {
        Add-Issue -Level "YELLOW" -Message "No analytical number provenance report found." -Action "Run analytical-number-provenance or document where each user-facing number comes from."
    }

    if ($calibration -match "(?is)## Verdict\s+RED\b") {
        Add-Issue -Level "YELLOW" -Message "Calibration readiness is RED; do not present formula outputs as reliable insight." -Action "Add calibration caveats or calibration evidence before presenting probabilities/recommendations as trusted."
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
    "- Analytical phase/docs detected: $($analyticalPhaseIntent -or $analyticalDocsPresent)",
    "- Test files changed: $(if ($testFilesChanged.Count -gt 0) { $testFilesChanged -join ', ' } else { 'none' })",
    "- Tracked formula tests: $(if ($formulaTestsTracked.Count -gt 0) { $formulaTestsTracked -join ', ' } else { 'none' })",
    "- Dirty files: $(if ($dirty.Count -gt 0) { $dirty -join '; ' } else { 'clean' })",
    "",
    "## Findings"
)

foreach ($issue in $issues) {
    $lines += "- [$($issue.level)] $($issue.message)"
}

$requiredActions = @($issues | Where-Object { $_.level -in @("RED", "YELLOW") } | ForEach-Object { $_.action } | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($requiredActions.Count -gt 0) {
    $lines += @(
        "",
        "## Required Actions"
    )
    foreach ($action in $requiredActions) {
        $lines += "- $action"
    }
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
    "## Repair Task Draft"
)

if ($verdict -eq "RED") {
    $lines += "- [ ] User pain: Analytical output is blocked by missing formula evidence. Target: docs/codex formula evidence and related tests. Change: resolve Franky's RED findings by adding concrete formulas, fixture rows, expected outputs, and formula test evidence. Remove/simplify: remove placeholder/TBD formula language and unsupported numeric claims. Guardrails: no UI polish, no unrelated feature work, no source-data invention. Acceptance: powershell -NoProfile -ExecutionPolicy Bypass -File ..\codex-fleet\franky-formula-review.ps1 -Repo . [class:test risk:medium mode:single scope:docs/codex/,tests/,src/]"
} else {
    $lines += "No RED formula repair task needed."
}

$lines += @(
    "",
    "## Stop Or Continue",
    $nextStep
)

$parent = Split-Path -Parent $OutFile
Ensure-OutputParent -Path $OutFile
$lines -join "`n" | Set-Content $OutFile -Encoding UTF8

if (![string]::IsNullOrWhiteSpace($JsonOutFile)) {
    Ensure-OutputParent -Path $JsonOutFile
    [pscustomobject]@{
        project = $Project
        branch = [string]$branch
        head = [string]$head
        baseBranch = $BaseBranch
        generatedAt = $date
        verdict = $verdict
        nextStep = $nextStep
        formulaIntent = [bool]$formulaIntent
        formulaSensitiveChangedFiles = @($formulaFilesChanged)
        analyticalPhaseOrDocsDetected = [bool]($analyticalPhaseIntent -or $analyticalDocsPresent)
        testFilesChanged = @($testFilesChanged)
        trackedFormulaTests = @($formulaTestsTracked)
        issueCounts = [pscustomobject]@{
            red = $redCount
            yellow = $yellowCount
            total = $issues.Count
        }
        issues = @($issues)
    } | ConvertTo-Json -Depth 6 | Set-Content $JsonOutFile -Encoding UTF8
}

Write-Host "Franky formula review: $verdict"
Write-Host "Report: $OutFile"
if (![string]::IsNullOrWhiteSpace($JsonOutFile)) {
    Write-Host "JSON: $JsonOutFile"
}

if ($verdict -eq "RED") { exit 1 }
exit 0
