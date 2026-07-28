[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$script:assertions=0
function Assert-Static([bool]$Condition,[string]$Message){$script:assertions++;if(!$Condition){throw "ASSERTION_FAILED:$Message"}}

$psFiles=@(
    'tools\TsfSemanticIntegrity.ps1',
    'tools\Invoke-TsfMissionLifecycle.ps1',
    'tools\hq-dispatch\v1\Invoke-TsfHqDispatchRoutePreview.ps1',
    'tools\hq-dispatch\v1\New-TsfHqDispatchGovernedMission.ps1',
    'tests\Test-TsfSemanticOutcomeCalibrationV1.ps1',
    'tests\Test-TsfGeneralResultIntentIntegrityV1.ps1',
    'tests\Test-TsfGeneralResultKernelVerifierV1.ps1',
    'tests\Test-TsfStructuredFulfillmentPolicyV1.ps1',
    'tests\Test-TsfRecoveryFixtureContractsV1.ps1',
    'tests\Test-TsfStructuredFulfillmentPacketV1.ps1',
    'tests\run-tsf-structured-fulfillment-real-proofs-v1.ps1',
    'tests\Test-TsfStructuredFulfillmentStaticIntegrityV1.ps1',
    'tests\run-tsf-structured-fulfillment-targeted-soak-v4.ps1',
    'tests\run-tsf-structured-fulfillment-targeted-soak-v5.ps1'
)
foreach($relative in $psFiles){
    $path=Join-Path $repo $relative
    Assert-Static (Test-Path -LiteralPath $path -PathType Leaf) "PowerShell source exists: $relative"
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null
    Assert-Static (@($errors).Count-eq0) "PowerShell source parses: $relative"
}

$nodeFiles=@(
    'tools\hq-dispatch\v1\mission-relay.mjs',
    'tools\hq-dispatch\v1\server.mjs',
    'tools\hq-dispatch\v1\public\app.js',
    'tests\fixtures\fleet\durable-contract\fake-codex-app-server.mjs',
    'tests\test-tsf-hq-dispatch-request-result-relay-v1.mjs',
    'tests\test-tsf-hq-dispatch-exact-response-contract-v1.mjs',
    'tests\test-tsf-hq-dispatch-demo-v1.mjs',
    'tests\test-tsf-hq-dispatch-intent-authorization-v1.mjs',
    'tests\test-tsf-hq-dispatch-real-reliability-v1.mjs',
    'tests\test-tsf-hq-dispatch-tim-relay-http-v1.mjs'
)
foreach($relative in $nodeFiles){
    & node --check (Join-Path $repo $relative)
    Assert-Static ($LASTEXITCODE-eq0) "Node source parses: $relative"
}

foreach($relative in @(
    'fleet\control\task-completion-contract.schema.v2.json',
    'fleet\control\hq-dispatch\hq-dispatch-route-preview-response.schema.v1.json',
    'fleet\control\general-result-v2.schema.v1.json',
    'fleet\control\result-envelope.schema.v1.json',
    'fleet\control\policy-manifest.v1.json'
)){
    Get-Content -Raw -LiteralPath (Join-Path $repo $relative)|ConvertFrom-Json|Out-Null
    Assert-Static $true "JSON parses: $relative"
}

$semantic=Get-Content -Raw -LiteralPath (Join-Path $repo 'tools\TsfSemanticIntegrity.ps1')
$generalResultSchema=Get-Content -Raw -LiteralPath (Join-Path $repo 'fleet\control\general-result-v2.schema.v1.json')
$ui=Get-Content -Raw -LiteralPath (Join-Path $repo 'tools\hq-dispatch\v1\public\app.js')
$relay=Get-Content -Raw -LiteralPath (Join-Path $repo 'tools\hq-dispatch\v1\mission-relay.mjs')
Assert-Static ([regex]::Matches($semantic,'function Get-TsfStructuredClaimContradictionDisposition').Count-eq1) 'Compatibility-only prose classifier is defined once.'
Assert-Static ([regex]::Matches($semantic,'Get-TsfStructuredClaimContradictionDisposition\s+-').Count-eq0) 'No verifier calls a whole-answer prose classifier.'
Assert-Static (!$semantic.Contains('LLM_SEMANTIC_VERIFIER')) 'No LLM semantic verifier exists.'
Assert-Static ($semantic.Contains('GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE')) 'Canonical generic non-admission reason is implemented.'
Assert-Static ($generalResultSchema.Contains('"STRUCTURAL_TEXT_ONLY_V2"')) 'The closed general-result schema accepts the canonical structural-only compatibility mode.'
Assert-Static ($ui.Contains('GENERIC_TEXT_RECEIVED_FULFILLMENT_UNVERIFIED')) 'UI structural-only state is implemented.'
Assert-Static ($relay.Contains('RESULT_CONTRACT_CONFIRMATION_REQUIRED_OR_CHANGED')) 'Submission confirmation is revalidated.'
Assert-Static ($relay.Contains('taskCompletionContract: sourceMission.task_completion_contract ?? null')) 'Recovery preserves the canonical source result contract.'
Assert-Static ($relay.Contains('async retryInterrupted({ item, interruption = null, sessionGeneration = "" })')) 'Recovery accepts no caller-supplied result contract.'
& git -C $repo diff --check
Assert-Static ($LASTEXITCODE-eq0) 'git diff check passes.'

"TSF_STRUCTURED_FULFILLMENT_STATIC_INTEGRITY_PASS assertions=$script:assertions"
