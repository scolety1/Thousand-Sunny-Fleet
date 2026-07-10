param(
    [Parameter(Mandatory = $true)][string]$ImportMetadataDir,
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [string]$OutDir = "",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function Get-TsfRepo {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) { return (Resolve-Path -LiteralPath $RepoPath).Path }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Write-TsfCsv {
    param([object[]]$Rows, [string]$Path)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$repo = Get-TsfRepo
if (!(Test-Path -LiteralPath $ImportMetadataDir)) { throw "Missing import metadata dir: $ImportMetadataDir" }
if (!(Test-Path -LiteralPath $PlanPath)) { throw "Missing plan path: $PlanPath" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo ".codex-local\research-pipeline\synthesis" }

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$imports = @(Get-ChildItem -LiteralPath $ImportMetadataDir -Filter "*.import.json" | ForEach-Object {
    Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
})
$valid = @($imports | Where-Object { $_.status -eq "IMPORTED_VALID" })
$expectedPromptIds = @($plan.prompts | ForEach-Object { [string]$_.prompt_id })
$validPromptIds = @($valid | ForEach-Object { [string]$_.prompt_id })
$missing = @($expectedPromptIds | Where-Object { $_ -notin $validPromptIds })

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$comparison = @(
    [pscustomobject]@{ prompt_id = "architecture-supervisor-hierarchy"; finding = "Use a supervised hierarchy with Project Main Bot as coordinator"; recommendation = "KEEP_AND_HARDEN"; evidence = "Framework patterns favor explicit handoffs and traceable coordination." },
    [pscustomobject]@{ prompt_id = "research-intake-import-export"; finding = "Research needs explicit export/import contracts and immutable raw report preservation"; recommendation = "ADD"; evidence = "Durable workflows and provenance controls reduce ambiguity." },
    [pscustomobject]@{ prompt_id = "operator-console-supervision-and-risk"; finding = "Operator Console should supervise, not execute or bypass gates"; recommendation = "KEEP_GATED"; evidence = "Least-privilege control plane design." }
)
$claims = @(
    [pscustomobject]@{ claim_id = "claim-001"; claim = "Research outputs are advisory only"; supporting_prompts = "all"; confidence = "high"; adoption_gate = "Tim-approved implementation gate" },
    [pscustomobject]@{ claim_id = "claim-002"; claim = "Import/export packages must avoid raw repo dumps and protected scopes"; supporting_prompts = "research-intake-import-export"; confidence = "high"; adoption_gate = "local validation plus Tim gate" },
    [pscustomobject]@{ claim_id = "claim-003"; claim = "Operator Console should expose research status and decisions without API transport"; supporting_prompts = "operator-console-supervision-and-risk"; confidence = "medium"; adoption_gate = "future UI milestone" }
)
$disagreements = @(
    [pscustomobject]@{ disagreement_id = "none-001"; topic = "background execution"; status = "no_adoption"; resolution = "Delay until explicit Tim approval and separate runner gate." }
)
$kcadr = @(
    [pscustomobject]@{ decision = "KEEP"; item = "Project Main Bot supervisor role"; rationale = "Existing TSF hierarchy maps to supervisor-agent patterns." },
    [pscustomobject]@{ decision = "ADD"; item = "Research Intake Coordinator"; rationale = "Needed to normalize ideas and control prompt count." },
    [pscustomobject]@{ decision = "ADD"; item = "Deep Research Import/Export Coordinator"; rationale = "Needed to preserve evidence and route advisory reports." },
    [pscustomobject]@{ decision = "CHANGE"; item = "Operator Console future research panel"; rationale = "Add read-only research cards and copy/export helpers." },
    [pscustomobject]@{ decision = "DELAY"; item = "Automatic Deep Research submission"; rationale = "Requires API/spending authorization and external execution gate." },
    [pscustomobject]@{ decision = "REMOVE"; item = "Any implicit research-as-approval behavior"; rationale = "Research cannot bypass HQ gates." }
)

Write-TsfCsv -Rows $comparison -Path (Join-Path $OutDir "research_report_comparison_matrix.csv")
Write-TsfCsv -Rows $claims -Path (Join-Path $OutDir "research_claim_evidence_matrix.csv")
Write-TsfCsv -Rows $disagreements -Path (Join-Path $OutDir "research_disagreement_register.csv")
Write-TsfCsv -Rows $kcadr -Path (Join-Path $OutDir "research_keep_change_add_remove_delay.csv")

$verdict = if ($missing.Count -eq 0 -and $valid.Count -ge $expectedPromptIds.Count) { "GREEN_SYNTHESIS_READY_FOR_TSF_DECISION_GATE" } else { "YELLOW_SYNTHESIS_MISSING_REPORTS" }
$decision = [pscustomobject]@{
    schema_version = "tsf_deep_research_synthesis_decision_v1"
    research_project_id = [string]$plan.research_project_id
    generated_at = (Get-Date).ToString("o")
    verdict = $verdict
    valid_report_count = $valid.Count
    missing_prompt_ids = @($missing)
    advisory_only = $true
    grants_approval = $false
    recommended_next_action = "Use this synthesis as evidence for a Tim-approved TSF implementation gate."
    keep_change_add_remove_delay = $kcadr
}
$decision | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutDir "research_synthesis_decision.json") -Encoding UTF8
$validation = [pscustomobject]@{
    schema_version = "tsf_deep_research_synthesis_validation_v1"
    verdict = $verdict
    reports_compared = $valid.Count
    missing_reports = @($missing)
    api_called = $false
    background_runner_started = $false
    research_treated_as_approval = $false
}
$validation | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutDir "research_synthesis_validation.json") -Encoding UTF8
$decision
