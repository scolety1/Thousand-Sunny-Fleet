[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AuthorizationPromptPath,
    [Parameter(Mandatory)]
    [string]$PilotEvidenceRoot,
    [Parameter(Mandatory)]
    [string]$AcceptanceEvidenceRoot,
    [string]$OutputRoot = 'C:\TSF_REVIEW\tsf_v1_synthetic_iteration_authority_v2_20260729\correction-02'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$packetBase = [IO.Path]::GetFullPath('C:\TSF_REVIEW\tsf_v1_synthetic_iteration_authority_v2_20260729')
$expectedOutput = [IO.Path]::GetFullPath((Join-Path $packetBase 'correction-02'))
$outputFull = [IO.Path]::GetFullPath($OutputRoot)
if (![string]::Equals($outputFull, $expectedOutput, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'TSF_SYNTHETIC_V2_REVIEW_PACKET_ROOT_CHANGED'
}
if (Test-Path -LiteralPath $outputFull) {
    throw 'TSF_SYNTHETIC_V2_REVIEW_PACKET_ALREADY_EXISTS'
}
$promptFull = [IO.Path]::GetFullPath($AuthorizationPromptPath)
if (!(Test-Path -LiteralPath $promptFull -PathType Leaf)) {
    throw 'TSF_SYNTHETIC_V2_AUTHORIZATION_PROMPT_ABSENT'
}
$evidenceFull = [IO.Path]::GetFullPath($PilotEvidenceRoot)
$resultPath = Join-Path $evidenceFull 'RESULTS.json'
$manifestPath = Join-Path $evidenceFull 'MANIFEST.json'
if (!(Test-Path -LiteralPath $resultPath -PathType Leaf) -or !(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'TSF_SYNTHETIC_V2_PILOT_EVIDENCE_INCOMPLETE'
}

$authorityPath = Join-Path $repoRoot 'fleet\control\hq-dispatch\hq-dispatch-synthetic-iteration-authority.v2.json'
$authority = Get-Content -LiteralPath $authorityPath -Raw -Encoding UTF8 | ConvertFrom-Json
$results = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($results.schema_version -ne 'TSF_SYNTHETIC_ITERATION_PILOT_RESULT_V2' -or
    @($results.results).Count -ne 3 -or
    @($results.results | Where-Object { $_.admission_disposition -eq 'ADMITTED' }).Count -ne 3 -or
    [int]$results.task_commit_count -ne 3 -or
    [int]$results.remote_count -ne 0 -or
    [bool]$results.push_performed -or
    [string]$results.authority_sha256 -cne '1721d6f9ac4380c22b8bad2d753432978d55f35f2f2cbcb1c9c9cce362471222') {
    throw 'TSF_SYNTHETIC_V2_PILOT_RESULT_NOT_PACKET_READY'
}
if ($manifest.summary.verdict -ne 'GREEN') {
    throw 'TSF_SYNTHETIC_V2_EVIDENCE_MANIFEST_NOT_GREEN'
}
$candidate = $results.tsf_candidate
if ($null -eq $candidate -or
    [string]$candidate.head -notmatch '^[a-f0-9]{40}$' -or
    [string]$candidate.tree -notmatch '^[a-f0-9]{40}$' -or
    [string]$candidate.parent -cne 'a3ee2b27e102c81f0c61c14fe522e6f40f5e6656' -or
    [string]$candidate.subject -cne 'feat: add governed synthetic coding iterations' -or
    ![bool]$candidate.detached -or ![bool]$candidate.clean) {
    throw 'TSF_SYNTHETIC_V2_EXACT_CANDIDATE_IDENTITY_INVALID'
}
$acceptanceFull = [IO.Path]::GetFullPath($AcceptanceEvidenceRoot)
$acceptanceSummaryPath = Join-Path $acceptanceFull 'acceptance-summary.json'
$acceptanceIndexPath = Join-Path $acceptanceFull 'evidence-index.csv'
if (!(Test-Path -LiteralPath $acceptanceSummaryPath -PathType Leaf) -or !(Test-Path -LiteralPath $acceptanceIndexPath -PathType Leaf)) {
    throw 'TSF_SYNTHETIC_V2_ACCEPTANCE_EVIDENCE_INCOMPLETE'
}
$acceptance = Get-Content -LiteralPath $acceptanceSummaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($acceptance.status -cne 'PASS' -or [int]$acceptance.execution.checks -ne 36 -or
    [int]$acceptance.execution.failed_checks -ne 0 -or ![bool]$acceptance.execution.real_app_server_proof_ran -or
    [string]$acceptance.repository.head -cne [string]$candidate.head -or
    [string]$acceptance.repository.tree -cne [string]$candidate.tree -or
    ![bool]$acceptance.repository.detached -or
    [string]$acceptance.repository.git_state_classification -cne 'DETACHED_COMMIT_PINNED' -or
    [string]$acceptance.final_cleanup.owner_disposition -cne 'ABSENT' -or
    [int]$acceptance.final_cleanup.listener_count -ne 0 -or
    [int]$acceptance.final_cleanup.owned_child_count -ne 0 -or
    @($acceptance.final_cleanup.tracked_status).Count -ne 0 -or
    [bool]$acceptance.authority_boundary.arbitrary_command_authority_added -or
    [bool]$acceptance.authority_boundary.arbitrary_repository_authority_added -or
    [bool]$acceptance.authority_boundary.production_deployment_authority_added -or
    [bool]$acceptance.authority_boundary.push_or_merge_authority_added -or
    [bool]$acceptance.authority_boundary.automatic_approval_added -or
    [bool]$acceptance.authority_boundary.background_or_persistent_execution_added -or
    [bool]$acceptance.authority_boundary.plugin_execution_added -or
    [bool]$acceptance.authority_boundary.credential_discovery_added -or
    [bool]$acceptance.authority_boundary.second_canonical_system_added) {
    throw 'TSF_SYNTHETIC_V2_ACCEPTANCE_NOT_EXACT_CANDIDATE_GREEN'
}

$interruptedAcceptanceRoot = 'C:\TSF_SYNTHETIC_AUTH_V2\.codex-local\evidence\synthetic-v2-candidate-binding-working-acceptance-01'
$workingAcceptanceRoot = 'C:\TSF_SYNTHETIC_AUTH_V2\.codex-local\evidence\synthetic-v2-candidate-binding-working-acceptance-02'
$workingAcceptanceSummaryPath = Join-Path $workingAcceptanceRoot 'acceptance-summary.json'
$workingWrapperFinalPath = 'C:\TSF_SYNTHETIC_AUTH_V2\.codex-local\evidence\synthetic-v2-candidate-binding-working-acceptance-02-wrapper\wrapper-final.json'
$workingReconciliationPath = 'C:\TSF_SYNTHETIC_AUTH_V2\.codex-local\evidence\synthetic-v2-candidate-binding-working-acceptance-02-post-run-reconciliation-02\POST_RUN_RECONCILIATION.json'
if (
    (Test-Path -LiteralPath (Join-Path $interruptedAcceptanceRoot 'acceptance-summary.json')) -or
    !(Test-Path -LiteralPath $workingAcceptanceSummaryPath -PathType Leaf) -or
    !(Test-Path -LiteralPath $workingWrapperFinalPath -PathType Leaf) -or
    !(Test-Path -LiteralPath $workingReconciliationPath -PathType Leaf)
) {
    throw 'TSF_SYNTHETIC_V2_POST_CRASH_ACCEPTANCE_EVIDENCE_INVALID'
}
$workingAcceptance = Get-Content -LiteralPath $workingAcceptanceSummaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$workingWrapper = Get-Content -LiteralPath $workingWrapperFinalPath -Raw -Encoding UTF8 | ConvertFrom-Json
$workingReconciliation = Get-Content -LiteralPath $workingReconciliationPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (
    $workingAcceptance.status -cne 'PASS' -or
    [int]$workingAcceptance.execution.checks -ne 37 -or
    [int]$workingAcceptance.execution.assertion_or_criterion_count -ne 1275 -or
    [int]$workingAcceptance.execution.failed_checks -ne 0 -or
    [int]$workingWrapper.true_numeric_exit -ne 0 -or
    ![bool]$workingReconciliation.pass
) {
    throw 'TSF_SYNTHETIC_V2_WORKING_ACCEPTANCE_NOT_GREEN'
}

$utf8 = [Text.UTF8Encoding]::new($false)
[IO.Directory]::CreateDirectory($outputFull) | Out-Null
function Write-Utf8([string]$Name, [string]$Content) {
    $path = Join-Path $outputFull $Name
    if (Test-Path -LiteralPath $path) { throw "PACKET_FILE_ALREADY_EXISTS: $Name" }
    [IO.File]::WriteAllText($path, $Content, $utf8)
}
function Write-Json([string]$Name, [object]$Value) {
    Write-Utf8 $Name (($Value | ConvertTo-Json -Depth 100) + "`n")
}

$readFirst = @'
# Read This First

This correction-02 packet is the authoritative exact-candidate candidate-set
binding and recovery-safety packet for the closed TSF V1 Synthetic Iteration
Authority V2 pilot dated 2026-07-29.

Correction-01 is preserved and is not publication-authoritative. Correction-02
supersedes it only for candidate-binding and recovery safety. This correction
is bound to the detached, clean candidate recorded in
`EXACT_CANDIDATE.json`, `RESULTS.json`, and the full acceptance artifacts.

It authorizes only the exact disposable repository, thirteen files, three task
templates, three Builder attempts per task, three accepted local task commits,
one active writer, and thirteen shell-free command templates recorded here.
It grants no general automatic approval, product, push, merge, production, or
deployment authority.

This packet supersedes nothing in the V1 single-file readiness packet. The V1
packet and its hashes remain unchanged.

Verify `HASHES.sha256` before relying on any file.
'@
Write-Utf8 'READ_THIS_FIRST.md' ($readFirst.TrimStart() + "`n")

$taskRows = @($results.results | ForEach-Object {
    "- $($_.task_id): baseline $($_.baseline_commit), iterations $($_.iteration_count), commit $($_.commit), admission $($_.admission_disposition)"
}) -join "`n"
$readiness = @"
# Authoritative Synthetic Iteration Readiness V2

Program: ``$($authority.program_id)``

Action: ``$($authority.action_id)``

Repository: ``$($authority.repository.root)``

Branch: ``$($authority.repository.branch)``

Expiry: ``$($authority.expires_at)``

## Closed authority

- exact files: $(@($authority.repository.allowed_paths).Count)
- exact command templates: $(@($authority.command_templates).Count)
- tasks: $(@($authority.tasks).Count)
- maximum Builder runs per task: $($authority.limits.maximum_builder_iterations_per_task)
- maximum accepted task commits: $($authority.limits.maximum_accepted_task_commits)
- maximum active write missions: $($authority.limits.maximum_active_write_missions)
- fixture remotes: $($results.remote_count)
- synthetic push performed: $($results.push_performed)

## Commit ladder

$taskRows

Task 2 preserved and rejected its first acceptance attempt before its second
bounded correction. Task 1 exercised interruption after the exact approved
replacement and resumed under a distinct recovery run without auto-testing or
auto-admission.

## Boundaries

The V2 authority is test-only. It does not replace or weaken the V1 single-file
packet. It prohibits synthetic network, remote Git, package installation,
plugins, credentials, product repositories, deployment, services, scheduled
tasks, daemons, remote listeners, and persistent processes.

Evidence manifest SHA-256:
``$((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant())``

Exact TSF candidate:
``$($candidate.head)`` / ``$($candidate.tree)``

Full acceptance summary SHA-256:
``$((Get-FileHash -LiteralPath $acceptanceSummaryPath -Algorithm SHA256).Hash.ToLowerInvariant())``

Full acceptance evidence-index SHA-256:
``$((Get-FileHash -LiteralPath $acceptanceIndexPath -Algorithm SHA256).Hash.ToLowerInvariant())``
"@
Write-Utf8 'AUTHORITATIVE_SYNTHETIC_ITERATION_READINESS_V2.md' ($readiness.TrimStart() + "`n")
Copy-Item -LiteralPath $promptFull -Destination (Join-Path $outputFull 'EXACT_PILOT_AUTHORIZATION_PROMPT.txt')
Write-Json 'THREE_TASK_CONTRACTS.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_three_task_contracts_v2'
    program_id = $authority.program_id
    repository = $authority.repository
    limits = $authority.limits
    tasks = @($authority.tasks)
})
Write-Json 'ALLOWED_PATHS.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_allowed_paths_v2'
    repository_root = $authority.repository.root
    branch = $authority.repository.branch
    paths = @($authority.repository.allowed_paths)
})
Write-Json 'ALLOWED_COMMANDS.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_allowed_commands_v2'
    working_directory = $authority.repository.root
    shell = $false
    templates = @($authority.command_templates)
})
$preauthorizations = Get-ChildItem -LiteralPath (Join-Path $evidenceFull 'tasks') -Recurse -Filter 'preauthorization.json' |
    Sort-Object FullName |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
if (@($preauthorizations).Count -ne 3) { throw 'TSF_SYNTHETIC_V2_PREAUTHORIZATION_EVIDENCE_COUNT_INVALID' }
Write-Json 'PREAUTHORIZATION_TEMPLATES.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_preauthorization_templates_v2'
    templates = @($preauthorizations)
})
$candidateSets = Get-ChildItem -LiteralPath (Join-Path $evidenceFull 'tasks') -Recurse -Filter 'approved-candidate-set.json' |
    Sort-Object FullName |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
if (@($candidateSets).Count -ne 5) { throw 'TSF_SYNTHETIC_V2_CANDIDATE_SET_EVIDENCE_COUNT_INVALID' }
Write-Json 'CANDIDATE_SET_BINDINGS.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_candidate_set_bindings_v2'
    canonical_authority_sha256 = $results.authority_sha256
    sets = @($candidateSets)
})
$recoverySecurity = @"
# Recovery Security Results

- canonical authority SHA-256: ``$($results.authority_sha256)``
- pilot manifest SHA-256: ``$((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant())``
- Task 1 interruption recovered in a fresh process: yes
- persisted candidate authority reloaded canonically: yes
- candidate membership task/path/iteration scoped: yes
- replacement bytes verified before and after write: yes
- bytes rechecked before and after test commands: yes
- staged and committed blob bytes matched the approved candidate: yes
- canonical verifier received candidate-set, writeset, byte, staged-blob, and committed-blob evidence: yes
- canonical admission independently rechecked the committed blob: yes
- correction-01 publication authority: no
- correction-02 scope: candidate-binding and recovery safety
"@
Write-Utf8 'RECOVERY_SECURITY_RESULTS.md' ($recoverySecurity.TrimStart() + "`n")
$postCrashRecovery = @"
# Post-Crash Acceptance Recovery

The preserved working-tree acceptance root
``$interruptedAcceptanceRoot`` is incomplete external-interruption evidence.
It has no ``acceptance-summary.json`` and no numeric wrapper exit. It contains a
durable targeted-soak ``final-doctor`` exit 4 caused by the intentionally dirty
candidate worktree, then ends abruptly during M3 canonical regression. It is
not GREEN and has not been rewritten.

The completed working-tree acceptance root is:
``$workingAcceptanceRoot``.

- numeric exit: $($workingWrapper.true_numeric_exit)
- checks: $($workingAcceptance.execution.checks)
- criteria/assertions: $($workingAcceptance.execution.assertion_or_criterion_count)
- failed checks: $($workingAcceptance.execution.failed_checks)
- status: $($workingAcceptance.status)
- summary SHA-256: $((Get-FileHash -LiteralPath $workingAcceptanceSummaryPath -Algorithm SHA256).Hash.ToLowerInvariant())
- final owner disposition: $($workingAcceptance.final_cleanup.owner_disposition)
- final listener count: $($workingAcceptance.final_cleanup.listener_count)
- final owned-child count: $($workingAcceptance.final_cleanup.owned_child_count)

The original wrapper receipt truthfully retains a cleanup false flag caused by
a read-only polling observer whose command line named the evidence path. The
observer ended naturally. The append-only reconciliation at
``$workingReconciliationPath`` passed with SHA-256
``$((Get-FileHash -LiteralPath $workingReconciliationPath -Algorithm SHA256).Hash.ToLowerInvariant())``.

The detached exact-candidate acceptance included elsewhere in this packet is a
separate clean-candidate run and does not inherit the working-tree verdict.
"@
Write-Utf8 'POST_CRASH_ACCEPTANCE_RECOVERY.md' ($postCrashRecovery.TrimStart() + "`n")
Copy-Item -LiteralPath $resultPath -Destination (Join-Path $outputFull 'RESULTS.json')
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputFull 'PILOT_MANIFEST.json')
Copy-Item -LiteralPath $acceptanceSummaryPath -Destination (Join-Path $outputFull 'ACCEPTANCE_SUMMARY.json')
Copy-Item -LiteralPath $acceptanceIndexPath -Destination (Join-Path $outputFull 'ACCEPTANCE_EVIDENCE_INDEX.csv')
Write-Json 'EXACT_CANDIDATE.json' ([pscustomobject][ordered]@{
    schema_version = 'tsf_synthetic_iteration_exact_candidate_v2'
    repository_root = $candidate.repository_root
    git_top_level = $candidate.git_top_level
    head = $candidate.head
    tree = $candidate.tree
    parent = $candidate.parent
    subject = $candidate.subject
    detached = $candidate.detached
    clean = $candidate.clean
    authority_sha256 = $results.authority_sha256
    pilot_manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    acceptance_summary_sha256 = (Get-FileHash -LiteralPath $acceptanceSummaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    acceptance_evidence_index_sha256 = (Get-FileHash -LiteralPath $acceptanceIndexPath -Algorithm SHA256).Hash.ToLowerInvariant()
})

$hashPath = Join-Path $outputFull 'HASHES.sha256'
$hashLines = Get-ChildItem -LiteralPath $outputFull -File |
    Where-Object { $_.Name -ne 'HASHES.sha256' } |
    Sort-Object Name |
    ForEach-Object { '{0} *{1}' -f ((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()), $_.Name }
[IO.File]::WriteAllText($hashPath, (($hashLines -join "`n") + "`n"), $utf8)

$verificationErrors = [Collections.Generic.List[string]]::new()
foreach ($line in Get-Content -LiteralPath $hashPath) {
    if ($line -notmatch '^(?<hash>[a-f0-9]{64}) \*(?<name>.+)$') {
        $verificationErrors.Add("Malformed hash line: $line") | Out-Null
        continue
    }
    $file = Join-Path $outputFull $Matches.name
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
        $verificationErrors.Add("Missing file: $($Matches.name)") | Out-Null
        continue
    }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Matches.hash) { $verificationErrors.Add("Hash mismatch: $($Matches.name)") | Out-Null }
}
if ($verificationErrors.Count) {
    throw "TSF_SYNTHETIC_V2_REVIEW_PACKET_SELF_CHECK_FAILED: $($verificationErrors -join '; ')"
}

[pscustomobject][ordered]@{
    verdict = 'GREEN'
    packet_root = $outputFull
    file_count = @(Get-ChildItem -LiteralPath $outputFull -File).Count
    hashes_sha256 = (Get-FileHash -LiteralPath $hashPath -Algorithm SHA256).Hash.ToLowerInvariant()
    pilot_manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    candidate_head = $candidate.head
    candidate_tree = $candidate.tree
    acceptance_summary_sha256 = (Get-FileHash -LiteralPath $acceptanceSummaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    acceptance_evidence_index_sha256 = (Get-FileHash -LiteralPath $acceptanceIndexPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
