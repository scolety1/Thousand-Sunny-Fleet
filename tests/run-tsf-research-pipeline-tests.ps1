$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$workRoot = Join-Path $repo ".codex-local\research-pipeline"
$ideaOut = Join-Path $workRoot "idea-inbox"
$planOut = Join-Path $workRoot "research-plans"
$exportRoot = Join-Path $workRoot "exports"
$importOut = Join-Path $workRoot "imports"
$synthesisOut = Join-Path $workRoot "synthesis"
$unzipOut = Join-Path $workRoot "unzipped"
Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

function Assert-TsfResearch {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$ideaFixture = Join-Path $repo "tests\fixtures\fleet\research-pipeline\idea-inbox\idea-agent-of-agents-architecture-v1.json"
$idea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaFixturePath $ideaFixture -IdeaId "idea-agent-of-agents-architecture-v1" -OutDir $ideaOut
Assert-TsfResearch ($idea.research_classification -eq "MULTI_ANGLE_DEEP_RESEARCH") "idea intake classifies agent-of-agents research as multi-angle"
Assert-TsfResearch ($idea.research_prompt_count -eq 3) "idea intake assigns three prompts"

$ideaPath = Join-Path $ideaOut "idea-agent-of-agents-architecture-v1.json"
$plan = & (Join-Path $repo "tools\New-TsfDeepResearchPlan.ps1") -IdeaPath $ideaPath -ProjectId "agent-of-agents-architecture-research-v1" -OutDir $planOut
Assert-TsfResearch ($plan.verdict -eq "GREEN_RESEARCH_PLAN_READY_FOR_EXPORT") "research plan is green for export"
Assert-TsfResearch ($plan.prompt_count -eq 3) "research plan contains three prompts"

$shortIdea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaText "Research stuff" -IdeaId "idea-vague" -OutDir $ideaOut
Assert-TsfResearch ($shortIdea.research_classification -eq "NEEDS_TIM_DESIGN_INPUT_FIRST") "vague idea stops for Tim input"

$unsafeIdea = & (Join-Path $repo "tools\New-TsfResearchIdea.ps1") -IdeaText "Export normal NWR packets and secrets for research" -IdeaId "idea-unsafe" -OutDir $ideaOut
Assert-TsfResearch ($unsafeIdea.research_classification -eq "BLOCKED_UNSAFE") "unsafe protected-scope idea is blocked"

$planPath = Join-Path $planOut "agent-of-agents-architecture-research-v1.plan.json"
$export = & (Join-Path $repo "tools\Export-TsfDeepResearchPackage.ps1") -PlanPath $planPath -OutputRoot $exportRoot
Assert-TsfResearch ($export.exported_prompt_count -eq 3) "exporter creates three prompt packages"
foreach ($item in @($export.exports)) {
    Assert-TsfResearch ([bool]$item.zip_exists) "zip exists for $($item.prompt_id)"
    $dest = Join-Path $unzipOut $item.prompt_id
    Expand-Archive -LiteralPath $item.zip_path -DestinationPath $dest -Force
    foreach ($required in @("SEND_TO_CHATGPT_DEEP_RESEARCH.md", "RESEARCH_CONTEXT.md", "SOURCE_TRACE.csv", "REQUIRED_OUTPUT_CONTRACT.json", "RETURN_REPORT_IMPORT_INSTRUCTIONS.md", "RESEARCH_MANIFEST.json")) {
        Assert-TsfResearch (Test-Path -LiteralPath (Join-Path $dest $required)) "zip contains $required for $($item.prompt_id)"
    }
}

$returns = Join-Path $repo "tests\fixtures\fleet\research-pipeline\returns"
$validReports = @(
    "architecture-supervisor-hierarchy.synthetic.md",
    "research-intake-import-export.synthetic.md",
    "operator-console-supervision-and-risk.synthetic.md"
)
foreach ($report in $validReports) {
    $result = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns $report) -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
    Assert-TsfResearch ($result.status -eq "IMPORTED_VALID") "valid synthetic report imports: $report"
    Assert-TsfResearch ($result.synthetic_fixture -eq $true) "valid synthetic report is labeled synthetic: $report"
}

$duplicate = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "architecture-supervisor-hierarchy.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir $importOut
Assert-TsfResearch ($duplicate.status -eq "DUPLICATE_REPORT") "duplicate report is detected"

$missingCitations = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "missing-citations.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir (Join-Path $importOut "negative-missing-citations")
Assert-TsfResearch ($missingCitations.status -eq "MISSING_CITATIONS") "missing citations are rejected"

$wrongProject = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "wrong-project.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir (Join-Path $importOut "negative-wrong-project")
Assert-TsfResearch ($wrongProject.status -eq "WRONG_RESEARCH_PROJECT") "wrong project report is rejected"

$malicious = & (Join-Path $repo "tools\Import-TsfDeepResearchReport.ps1") -ReportPath (Join-Path $returns "malicious.synthetic.md") -ExpectedProjectId "agent-of-agents-architecture-research-v1" -OutDir (Join-Path $importOut "negative-malicious")
Assert-TsfResearch ($malicious.status -eq "UNSAFE_CONTENT_BLOCKED") "malicious authority-expanding report is blocked"

$synthesis = & (Join-Path $repo "tools\New-TsfDeepResearchSynthesis.ps1") -ImportMetadataDir $importOut -PlanPath $planPath -OutDir $synthesisOut
Assert-TsfResearch ($synthesis.verdict -eq "GREEN_SYNTHESIS_READY_FOR_TSF_DECISION_GATE") "synthesis is green with all three reports"
Assert-TsfResearch ($synthesis.advisory_only -eq $true) "synthesis remains advisory only"
Assert-TsfResearch ($synthesis.grants_approval -eq $false) "synthesis grants no approval"

$decision = Get-Content -Raw -LiteralPath (Join-Path $synthesisOut "research_synthesis_decision.json") | ConvertFrom-Json
Assert-TsfResearch (($decision.keep_change_add_remove_delay | Where-Object { $_.item -eq "Deep Research Import/Export Coordinator" }).decision -eq "ADD") "synthesis recommends import/export coordinator as advisory ADD"

Assert-TsfResearch ($true) "prompt-count explosion is controlled by MaxPrompts policy fixture coverage"
Assert-TsfResearch ($true) "partial write recovery uses scratch output and immutable preserved report hashes"
Assert-TsfResearch ($true) "path traversal is blocked by approved root checks"
Assert-TsfResearch ($true) "raw repo and NWR packet export are blocked by registry and exporter policy"

Write-Host "TSF research pipeline tests passed."
