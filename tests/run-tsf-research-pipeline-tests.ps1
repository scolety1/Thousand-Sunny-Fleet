param([string]$ResultsPath = "")

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$workRoot = Join-Path $repo ".codex-local\research-pipeline"
$ideaOut = Join-Path $workRoot "idea-inbox"
$planOut = Join-Path $workRoot "research-plans"
$exportRoot = Join-Path $workRoot "exports"
$importOut = Join-Path $workRoot "imports"
$synthesisOut = Join-Path $workRoot "synthesis"
$unzipOut = Join-Path $workRoot "unzipped"
if ([string]::IsNullOrWhiteSpace($ResultsPath)) { $ResultsPath = Join-Path $workRoot "executed-test-coverage.csv" }
Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

$script:results = New-Object System.Collections.ArrayList
function Save-TsfResults {
    $parent = Split-Path -Parent $ResultsPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    @($script:results) | Export-Csv -LiteralPath $ResultsPath -NoTypeInformation -Encoding UTF8
}

function Assert-TsfResearch {
    param(
        [string]$CaseId,
        [string]$Category,
        [bool]$Condition,
        [string]$Expected,
        [string]$Observed,
        [string]$Message
    )
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    [void]$script:results.Add([pscustomobject]@{ case_id = $CaseId; category = $Category; assertion = $Message; expected = $Expected; observed = $Observed; status = $status })
    Save-TsfResults
    if (!$Condition) { throw "FAIL [$CaseId]: $Message (expected: $Expected; observed: $Observed)" }
    Write-Host "PASS [$CaseId]: $Message"
}

function Assert-TsfThrows {
    param([string]$CaseId, [string]$Category, [scriptblock]$Action, [string]$ExpectedPattern, [string]$Message)
    $thrown = $false
    $observed = "NO_EXCEPTION"
    try { $null = & $Action } catch { $thrown = $true; $observed = $_.Exception.Message }
    Assert-TsfResearch -CaseId $CaseId -Category $Category -Condition ($thrown -and $observed -match $ExpectedPattern) -Expected "exception matching $ExpectedPattern" -Observed $observed -Message $Message
}

function Copy-TsfPlan {
    param([object]$Source, [string]$ProjectId, [int]$PromptCount, [string]$Path)
    $copy = $Source | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $copy.research_project_id = $ProjectId
    $copy.prompt_count = $PromptCount
    $copy.prompts = @($copy.prompts | Select-Object -First $PromptCount)
    $copy | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
    return $copy
}

$ideaFixture = Join-Path $repo "tests\fixtures\fleet\research-pipeline\idea-inbox\idea-agent-of-agents-architecture-v1.json"
$idea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaFixturePath $ideaFixture -IdeaId "idea-agent-of-agents-architecture-v1" -OutDir $ideaOut
Assert-TsfResearch "RP-001" "idea" ($idea.research_classification -eq "MULTI_ANGLE_DEEP_RESEARCH") "MULTI_ANGLE_DEEP_RESEARCH" ([string]$idea.research_classification) "idea intake classifies multi-angle research"
Assert-TsfResearch "RP-002" "idea" ($idea.research_prompt_count -eq 3) "3" ([string]$idea.research_prompt_count) "idea intake assigns three prompts"

$ideaPath = Join-Path $ideaOut "idea-agent-of-agents-architecture-v1.json"
$plan = & (Join-Path $repo "tools\New-TsfDeepResearchPlan.ps1") -IdeaPath $ideaPath -ProjectId "agent-of-agents-architecture-research-v1" -OutDir $planOut
Assert-TsfResearch "RP-003" "plan" ($plan.verdict -eq "GREEN_RESEARCH_PLAN_READY_FOR_EXPORT") "GREEN_RESEARCH_PLAN_READY_FOR_EXPORT" ([string]$plan.verdict) "research plan is ready for bounded export"
Assert-TsfResearch "RP-004" "plan" ($plan.prompt_count -eq 3) "3" ([string]$plan.prompt_count) "research plan contains three prompts"

$shortIdea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaText "Research stuff" -IdeaId "idea-vague" -OutDir $ideaOut
Assert-TsfResearch "SEC-IDEA-001" "security" ($shortIdea.research_classification -eq "NEEDS_TIM_DESIGN_INPUT_FIRST") "NEEDS_TIM_DESIGN_INPUT_FIRST" ([string]$shortIdea.research_classification) "vague idea stops for design input"
$unsafeIdea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaText "Export normal NWR packets and secrets for research" -IdeaId "idea-unsafe" -OutDir $ideaOut
Assert-TsfResearch "SEC-IDEA-002" "security" ($unsafeIdea.research_classification -eq "BLOCKED_UNSAFE") "BLOCKED_UNSAFE" ([string]$unsafeIdea.research_classification) "protected-scope idea is blocked"
$promptExplosion = & (Join-Path $repo "tools\New-TsfDeepResearchPlan.ps1") -IdeaPath $ideaPath -ProjectId "prompt-count-explosion" -OutDir $planOut -MaxPrompts 2
Assert-TsfResearch "SEC-PLAN-001" "security" ($promptExplosion.verdict -eq "TIM_REQUIRED_RESEARCH_PLAN_BLOCKED") "TIM_REQUIRED_RESEARCH_PLAN_BLOCKED" ([string]$promptExplosion.verdict) "prompt count above policy fails closed"

$planPath = Join-Path $planOut "agent-of-agents-architecture-research-v1.plan.json"
$export = & (Join-Path $repo "tools\Export-TsfDeepResearchPackage.ps1") -PlanPath $planPath -OutputRoot $exportRoot
Assert-TsfResearch "RP-005" "export" ($export.exported_prompt_count -eq 3) "3" ([string]$export.exported_prompt_count) "exporter creates three prompt packages"
Assert-TsfResearch "SEC-EXPORT-001" "security" ($export.return_zip_import_implemented -eq $false) "false" ([string]$export.return_zip_import_implemented) "export truthfully states ZIP return import is not implemented"
foreach ($item in @($export.exports)) {
    Assert-TsfResearch "RP-EXPORT-ZIP-$($item.prompt_id)" "export" ([bool]$item.zip_exists) "true" ([string]$item.zip_exists) "export ZIP exists"
    $dest = Join-Path $unzipOut $item.prompt_id
    Expand-Archive -LiteralPath $item.zip_path -DestinationPath $dest -Force
    foreach ($required in @("SEND_TO_CHATGPT_DEEP_RESEARCH.md", "RESEARCH_CONTEXT.md", "SOURCE_TRACE.csv", "REQUIRED_OUTPUT_CONTRACT.json", "RETURN_REPORT_IMPORT_INSTRUCTIONS.md", "RESEARCH_MANIFEST.json")) {
        $present = Test-Path -LiteralPath (Join-Path $dest $required)
        Assert-TsfResearch "RP-EXPORT-$($item.prompt_id)-$required" "export" $present "present" ([string]$present) "export ZIP contains required file"
    }
}

$siblingRoot = $exportRoot + "_EVIL"
Assert-TsfThrows "SEC-EXPORT-002" "security" { & (Join-Path $repo "tools\Export-TsfDeepResearchPackage.ps1") -PlanPath $planPath -OutputRoot $siblingRoot } "approved research export root" "sibling-prefix export root is rejected"
Assert-TsfResearch "SEC-EXPORT-003" "security" (!(Test-Path -LiteralPath $siblingRoot)) "path absent" ([string](Test-Path -LiteralPath $siblingRoot)) "sibling-prefix rejection occurs before partial export"
$traversalRoot = Join-Path $exportRoot "..\escaped"
Assert-TsfThrows "SEC-EXPORT-004" "security" { & (Join-Path $repo "tools\Export-TsfDeepResearchPackage.ps1") -PlanPath $planPath -OutputRoot $traversalRoot } "approved research export root" "dot-dot traversal export root is rejected"

$badIds = @(
    [pscustomobject]@{ id = "C:\absolute-project"; case = "SEC-EXPORT-005"; label = "drive-rooted project identifier" },
    [pscustomobject]@{ id = "\\server\share\project"; case = "SEC-EXPORT-006"; label = "UNC project identifier" },
    [pscustomobject]@{ id = "project\child"; case = "SEC-EXPORT-007"; label = "backslash project identifier" },
    [pscustomobject]@{ id = "project/child"; case = "SEC-EXPORT-008"; label = "alternate-separator project identifier" },
    [pscustomobject]@{ id = "project..child"; case = "SEC-EXPORT-009"; label = "project identifier traversal token" },
    [pscustomobject]@{ id = "project$([char]1)child"; case = "SEC-EXPORT-010"; label = "control-character project identifier" },
    [pscustomobject]@{ id = "con"; case = "SEC-EXPORT-011"; label = "reserved Windows device project identifier" }
)
foreach ($bad in $badIds) {
    $badPath = Join-Path $planOut "$($bad.case).plan.json"
    $badPlan = $plan | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $badPlan.research_project_id = $bad.id
    $badPlan | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $badPath -Encoding UTF8
    Assert-TsfThrows $bad.case "security" { & (Join-Path $repo "tools\Export-TsfDeepResearchPackage.ps1") -PlanPath $badPath -OutputRoot $exportRoot } "research_project_id" "$($bad.label) is rejected"
}

$returns = Join-Path $repo "tests\fixtures\fleet\research-pipeline\returns"
$validReports = @("architecture-supervisor-hierarchy.synthetic.md", "research-intake-import-export.synthetic.md", "operator-console-supervision-and-risk.synthetic.md")
foreach ($report in $validReports) {
    $expectedPrompt = $report -replace '\.synthetic\.md$', ''
    $result = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns $report) -ExpectedProjectId "agent-of-agents-architecture-research-v1" -ExpectedPromptId $expectedPrompt -OutDir $importOut
    Assert-TsfResearch "RP-IMPORT-$expectedPrompt" "import" ($result.status -eq "IMPORTED_VALID") "IMPORTED_VALID" ([string]$result.status) "complete synthetic report imports"
    Assert-TsfResearch "RP-LABEL-$expectedPrompt" "import" ($result.synthetic_fixture -eq $true) "true" ([string]$result.synthetic_fixture) "synthetic report remains labeled"
    Assert-TsfResearch "SEC-CITE-$expectedPrompt" "security" ($result.citation_validation -eq "BASIC_CITATION_PRESENCE_VALIDATED" -and $result.claim_to_source_verification -eq $false) "basic presence true; claim verification false" "$($result.citation_validation); claim verification=$($result.claim_to_source_verification)" "import reports only basic citation presence"
}

$duplicate = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "architecture-supervisor-hierarchy.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -ExpectedPromptId "architecture-supervisor-hierarchy" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-001" "security" ($duplicate.status -eq "DUPLICATE_REPORT") "DUPLICATE_REPORT" ([string]$duplicate.status) "duplicate report is detected"
$missingCitations = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "missing-citations.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-002" "security" ($missingCitations.status -eq "INCOMPLETE_REPORT" -and $missingCitations.missing_or_empty_sections -contains "Sources") "INCOMPLETE_REPORT with Sources missing" "$($missingCitations.status); $($missingCitations.missing_or_empty_sections -join ',')" "missing Sources section is incomplete"
$emptySources = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "empty-sources.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-003" "security" ($emptySources.status -eq "INCOMPLETE_REPORT" -and $emptySources.missing_or_empty_sections -contains "Sources") "INCOMPLETE_REPORT with empty Sources" "$($emptySources.status); $($emptySources.missing_or_empty_sections -join ',')" "empty Sources section is incomplete"
$partial = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "missing-sections.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -ExpectedPromptId "architecture-supervisor-hierarchy" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-004" "security" ($partial.status -eq "INCOMPLETE_REPORT") "INCOMPLETE_REPORT" ([string]$partial.status) "partial report is rejected as incomplete"
$wrongProject = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "wrong-project.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-005" "security" ($wrongProject.status -eq "WRONG_RESEARCH_PROJECT") "WRONG_RESEARCH_PROJECT" ([string]$wrongProject.status) "valid prompt ID from another project is rejected"
$malicious = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "malicious.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-006" "security" ($malicious.status -eq "UNSAFE_CONTENT_BLOCKED") "UNSAFE_CONTENT_BLOCKED" ([string]$malicious.status) "malicious instruction text is blocked"
$unexpected = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "unexpected-prompt.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch "SEC-IMPORT-007" "security" ($unexpected.status -eq "IMPORTED_VALID") "IMPORTED_VALID before plan filtering" ([string]$unexpected.status) "complete unexpected prompt is imported for later plan filtering"
$encodingFixture = Join-Path $workRoot "invalid-utf8.synthetic.md"
[System.IO.File]::WriteAllBytes($encodingFixture, [byte[]](0xff, 0xfe, 0x41, 0x00))
$badEncoding = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath $encodingFixture -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir (Join-Path $importOut "bad-encoding")
Assert-TsfResearch "SEC-IMPORT-008" "security" ($badEncoding.status -eq "REJECTED_TEXT_ENCODING") "REJECTED_TEXT_ENCODING" ([string]$badEncoding.status) "non-UTF-8 report encoding is explicitly rejected"
$largeFixture = Join-Path $workRoot "too-large.synthetic.md"
[System.IO.File]::WriteAllBytes($largeFixture, [System.Text.Encoding]::UTF8.GetBytes(("x" * 300)))
$tooLarge = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath $largeFixture -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir (Join-Path $importOut "too-large") -MaxReportBytes 256
Assert-TsfResearch "SEC-IMPORT-009" "security" ($tooLarge.status -eq "INCOMPLETE_REPORT_TOO_LARGE") "INCOMPLETE_REPORT_TOO_LARGE" ([string]$tooLarge.status) "report size limit is enforced"

$synthesis = & (Join-Path $repo "tools\New-TsfDeepResearchSynthesis.ps1") -ImportMetadataDir $importOut -PlanPath $planPath -OutDir $synthesisOut
Assert-TsfResearch "SEC-SYNTH-001" "security" ($synthesis.verdict -eq "GREEN_CONTENT_DERIVED_SYNTHESIS_READY_FOR_ADVISORY_REVIEW") "GREEN_CONTENT_DERIVED_SYNTHESIS_READY_FOR_ADVISORY_REVIEW" ([string]$synthesis.verdict) "complete expected report set produces content-derived advisory synthesis"
Assert-TsfResearch "SEC-SYNTH-002" "security" ($synthesis.advisory_only -eq $true -and $synthesis.grants_approval -eq $false) "advisory_only=true; grants_approval=false" "advisory_only=$($synthesis.advisory_only); grants_approval=$($synthesis.grants_approval)" "research output remains advisory and grants no approval"
Assert-TsfResearch "SEC-SYNTH-003" "security" ($synthesis.eligible_report_count -eq 3) "3 eligible reports" ([string]$synthesis.eligible_report_count) "duplicate, partial, rejected, wrong-project, and unexpected imports are excluded from eligibility"
$decisionItems = @($synthesis.keep_change_add_remove_delay | ForEach-Object { [string]$_.item })
Assert-TsfResearch "SEC-SYNTH-004" "security" ("expected-project safety controls" -notin $decisionItems) "wrong-project recommendation absent" ($decisionItems -join " | ") "wrong-project report does not influence synthesis"
Assert-TsfResearch "SEC-SYNTH-005" "security" ("expected-project safety controls" -notin $decisionItems -and @($synthesis.excluded_imports | Where-Object { $_.exclusion_reason -eq "UNEXPECTED_PROMPT_ID" }).Count -eq 1) "unexpected prompt excluded" ((@($synthesis.excluded_imports | ForEach-Object { $_.exclusion_reason }) -join " | ")) "unexpected prompt ID does not influence synthesis"
Assert-TsfResearch "SEC-SYNTH-006" "security" (@($synthesis.excluded_imports | Where-Object { $_.exclusion_reason -like "STATUS_DUPLICATE_REPORT" }).Count -eq 1) "duplicate exclusion recorded" ((@($synthesis.excluded_imports | ForEach-Object { $_.exclusion_reason }) -join " | ")) "duplicate report is excluded from synthesis"
Assert-TsfResearch "SEC-SYNTH-007" "security" (@($synthesis.excluded_imports | Where-Object { $_.exclusion_reason -in @("STATUS_INCOMPLETE_REPORT", "STATUS_UNSAFE_CONTENT_BLOCKED") }).Count -ge 2) "partial and malicious exclusions recorded" ((@($synthesis.excluded_imports | ForEach-Object { $_.exclusion_reason }) -join " | ")) "partial and rejected imports are excluded from synthesis"
Assert-TsfResearch "SEC-SYNTH-008" "security" (@($synthesis.keep_change_add_remove_delay | Where-Object { $_.report_hash -and $_.source_entries }).Count -eq $synthesis.keep_change_add_remove_delay.Count) "every decision attributed" ([string](@($synthesis.keep_change_add_remove_delay | Where-Object { $_.report_hash -and $_.source_entries }).Count)) "content-derived decisions include report and source attribution"

$incompleteOnlyOut = Join-Path $importOut "incomplete-only"
$incompleteOnly = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "missing-sections.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -ExpectedPromptId "architecture-supervisor-hierarchy" -OutDir $incompleteOnlyOut
$onePromptPlanPath = Join-Path $planOut "one-prompt-main.plan.json"
$null = Copy-TsfPlan -Source $plan -ProjectId "agent-of-agents-architecture-research-v1" -PromptCount 1 -Path $onePromptPlanPath
$incompleteSynthesis = & (Join-Path $repo "tools\New-TsfDeepResearchSynthesis.ps1") -ImportMetadataDir $incompleteOnlyOut -PlanPath $onePromptPlanPath -OutDir (Join-Path $synthesisOut "incomplete-only")
Assert-TsfResearch "SEC-SYNTH-009" "security" ($incompleteSynthesis.verdict -eq "YELLOW_SYNTHESIS_INSUFFICIENT_ELIGIBLE_REPORT_CONTENT" -and $incompleteSynthesis.eligible_report_count -eq 0) "YELLOW and zero eligible" "$($incompleteSynthesis.verdict); eligible=$($incompleteSynthesis.eligible_report_count)" "missing required report content prevents false GREEN"

$contentOutputs = @()
foreach ($variant in @("alpha", "beta")) {
    $projectId = "content-comparison-$variant"
    $variantPlanPath = Join-Path $planOut "$projectId.plan.json"
    $null = Copy-TsfPlan -Source $plan -ProjectId $projectId -PromptCount 1 -Path $variantPlanPath
    $variantImport = Join-Path $importOut $variant
    $variantReport = Join-Path $returns "content-$variant.synthetic.md"
    $variantResult = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath $variantReport -ExpectedProjectId $projectId -ExpectedPromptId "architecture-supervisor-hierarchy" -OutDir $variantImport
    Assert-TsfResearch "SEC-CONTENT-IMPORT-$variant" "security" ($variantResult.status -eq "IMPORTED_VALID") "IMPORTED_VALID" ([string]$variantResult.status) "content comparison fixture imports"
    $variantSynthesis = & (Join-Path $repo "tools\New-TsfDeepResearchSynthesis.ps1") -ImportMetadataDir $variantImport -PlanPath $variantPlanPath -OutDir (Join-Path $synthesisOut $variant)
    $contentOutputs += [pscustomobject]@{ variant = $variant; verdict = $variantSynthesis.verdict; decision = [string]$variantSynthesis.keep_change_add_remove_delay[0].decision; item = [string]$variantSynthesis.keep_change_add_remove_delay[0].item }
}
$alpha = $contentOutputs | Where-Object variant -eq "alpha"
$beta = $contentOutputs | Where-Object variant -eq "beta"
Assert-TsfResearch "SEC-SYNTH-010" "security" ($alpha.decision -ne $beta.decision -and $alpha.item -ne $beta.item) "meaningfully different decision and item" "alpha=$($alpha.decision) $($alpha.item); beta=$($beta.decision) $($beta.item)" "different report content produces different synthesis output"

$comparisonPlanPath = Join-Path $planOut "content-agreement-disagreement.plan.json"
$null = Copy-TsfPlan -Source $plan -ProjectId "content-agreement-disagreement" -PromptCount 2 -Path $comparisonPlanPath
$comparisonImport = Join-Path $importOut "agreement-disagreement"
$comparisonOne = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "agreement-disagreement-one.synthetic.md") -ExpectedProjectId "content-agreement-disagreement" -ExpectedPromptId "architecture-supervisor-hierarchy" -OutDir $comparisonImport
$comparisonTwo = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "agreement-disagreement-two.synthetic.md") -ExpectedProjectId "content-agreement-disagreement" -ExpectedPromptId "research-intake-import-export" -OutDir $comparisonImport
Assert-TsfResearch "SEC-CONTENT-IMPORT-comparison" "security" ($comparisonOne.status -eq "IMPORTED_VALID" -and $comparisonTwo.status -eq "IMPORTED_VALID") "both IMPORTED_VALID" "$($comparisonOne.status); $($comparisonTwo.status)" "agreement/disagreement fixtures import"
$comparisonSynthesis = & (Join-Path $repo "tools\New-TsfDeepResearchSynthesis.ps1") -ImportMetadataDir $comparisonImport -PlanPath $comparisonPlanPath -OutDir (Join-Path $synthesisOut "agreement-disagreement")
$agreement = @($comparisonSynthesis.agreements | Where-Object { $_.topic -eq "shared audit trail" -and $_.decision -eq "KEEP" })
$disagreement = @($comparisonSynthesis.disagreements | Where-Object { $_.topic -eq "console authority" -and $_.status -eq "UNRESOLVED_ADVISORY_DISAGREEMENT" })
Assert-TsfResearch "SEC-SYNTH-011" "security" ($agreement.Count -eq 1) "one content-derived agreement" ([string]$agreement.Count) "matching recommendation signals produce an attributed agreement"
Assert-TsfResearch "SEC-SYNTH-012" "security" ($disagreement.Count -eq 1) "one unresolved content-derived disagreement" ([string]$disagreement.Count) "conflicting recommendation signals preserve disagreement"

$consoleSample = Get-Content -Raw -LiteralPath (Join-Path $repo "tools\operator-console\readonly\research-inbox.sample.json") | ConvertFrom-Json
$consoleHtml = Get-Content -Raw -LiteralPath (Join-Path $repo "tools\operator-console\readonly\research-inbox.html")
Assert-TsfResearch "UI-001" "operator-console" ($consoleSample.presentation_mode -eq "READ_ONLY_PREVIEW" -and $consoleSample.data_mode -eq "FIXTURE_DATA") "READ_ONLY_PREVIEW and FIXTURE_DATA" "$($consoleSample.presentation_mode); $($consoleSample.data_mode)" "Operator Console research sample is truthfully labeled"
Assert-TsfResearch "UI-002" "operator-console" ($consoleHtml -match "READ_ONLY_PREVIEW" -and $consoleHtml -match "SCRIPT_BACKED_NOT_UI_WIRED") "truth labels present" ([string]($consoleHtml -match "READ_ONLY_PREVIEW")) "Operator Console preview discloses script/UI boundary"

Save-TsfResults
Write-Host "TSF research pipeline tests passed: $($script:results.Count) executed assertions."
Write-Host "Executed coverage: $ResultsPath"
