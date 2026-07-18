[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$AttachedRepository = 'C:\TSF_HOTFIX2',
    [string]$DetachedRepository = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
. (Join-Path $PSScriptRoot 'support\TsfFinalAcceptanceGitState.ps1')
$git = (Get-Command git.exe -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($DetachedRepository)) {
    $currentBranch = [string](@(& $git -C $repo branch --show-current) -join "`n")
    $DetachedRepository = if ([string]::IsNullOrWhiteSpace($currentBranch)) { $repo } else { 'C:\TSF_HOTFIX2_DEEP_PROOF2' }
}
$expectedDetachedHead = [string](@(& $git -C $DetachedRepository rev-parse HEAD) -join "`n").Trim()
$expectedDetachedTree = [string](@(& $git -C $DetachedRepository rev-parse 'HEAD^{tree}') -join "`n").Trim()
$assertions = 0
function Assert-Case([bool]$Passed, [string]$Message) {
    $script:assertions++
    if (!$Passed) { throw "FINAL_ACCEPTANCE_GIT_STATE_ASSERTION_FAILED:$Message" }
}

$nullLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $null -AllowEmpty
$emptyLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output '' -AllowEmpty
$spaceLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output @('  ', "`t") -AllowEmpty
$branchLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output 'hotfix/example'
$multiLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output @('branch-a', 'branch-b') -AllowEmpty
Assert-Case ($nullLine.valid -and $null -eq $nullLine.value) 'null branch output is explicit empty presentation'
Assert-Case ($emptyLine.valid -and $null -eq $emptyLine.value) 'empty branch output is accepted'
Assert-Case ($spaceLine.valid -and $null -eq $spaceLine.value) 'whitespace branch output is accepted'
Assert-Case ($branchLine.valid -and $branchLine.value -eq 'hotfix/example') 'single-line attached branch is retained exactly'
Assert-Case (!$multiLine.valid -and $multiLine.disposition -eq 'UNEXPECTED_MULTI_LINE_OUTPUT') 'unexpected multi-line output fails closed'

$attached = Get-TsfFinalAcceptanceGitState -RepositoryRoot $AttachedRepository -GitExecutable $git
$detached = Get-TsfFinalAcceptanceGitState -RepositoryRoot $DetachedRepository -GitExecutable $git
Assert-Case ($attached.classification -eq 'ATTACHED_BRANCH') 'attached checkout is classified as attached'
Assert-Case ($attached.branch -eq 'hotfix/tsf-response-contract-runtime-cleanliness-v1-20260718') 'attached checkout retains exact branch'
Assert-Case (!$attached.detached) 'attached checkout is not relabeled detached'
Assert-Case ($attached.branch_requirement_disposition -eq 'ATTACHED_BRANCH_REQUIREMENTS_RETAINED') 'attached requirements remain enforced'
Assert-Case ($detached.classification -eq 'DETACHED_COMMIT_PINNED') 'detached checkout is commit-pinned'
Assert-Case ($detached.detached -and $null -eq $detached.branch) 'detached checkout has no fabricated branch'
Assert-Case ($detached.head -eq $expectedDetachedHead) 'detached checkout captures exact commit'
Assert-Case ($detached.tree -eq $expectedDetachedTree) 'detached checkout captures exact tree'
Assert-Case ($detached.branch_requirement_disposition -eq 'DETACHED_READ_ONLY_ACCEPTANCE_PERMITTED_WRITES_REMAIN_DENIED') 'detached read-only policy remains explicit'
Assert-Case ($detached.branch -notin @('main','HEAD','DETACHED_HEAD')) 'no synthetic branch is created'
Assert-Case ($attached.git_state_evidence_sha256 -match '^[a-f0-9]{64}$' -and $detached.git_state_evidence_sha256 -match '^[a-f0-9]{64}$') 'Git-state evidence hashes are present'
Assert-Case ($attached.git_state_evidence_sha256 -ne $detached.git_state_evidence_sha256) 'state changes invalidate evidence'

$invalidRepo = Get-TsfFinalAcceptanceGitState -RepositoryRoot (Join-Path $repo '.codex-local\fixtures\missing-final-acceptance-repo') -GitExecutable $git
Assert-Case ($invalidRepo.classification -eq 'UNKNOWN_OR_INVALID_GIT_STATE') 'invalid repository fails closed'
Assert-Case (@($invalidRepo.commands|Where-Object{!$_.success}).Count -gt 0) 'invalid repository records failed commands'
Assert-Case (@($invalidRepo.commands|Where-Object{!$_.success -and $_.exit_code -ne 0 -and $_.stderr_sha256 -match '^[a-f0-9]{64}$'}).Count -gt 0) 'Git failure records exit and stderr hash'
Assert-Case (!$invalidRepo.detached) 'Git failure is not detached'

$missingGit = Get-TsfFinalAcceptanceGitState -RepositoryRoot $AttachedRepository -GitExecutable 'C:\TSF_MISSING\git.exe'
Assert-Case ($missingGit.classification -eq 'UNKNOWN_OR_INVALID_GIT_STATE') 'missing Git executable fails closed'
Assert-Case (@($missingGit.commands|Where-Object{$_.error_classification -eq 'GIT_PROCESS_LAUNCH_FAILURE' -and $_.exit_code -eq -1}).Count -eq 3) 'launch failures retain classification and exit'
Assert-Case (@($detached.commands|Where-Object{!$_.success}).Count -eq 0) 'detached Git commands succeed'
Assert-Case ($detached.canonical_policy_state.detached_head) 'canonical authority agrees with detached classification'

[pscustomobject][ordered]@{schema_version='tsf_final_acceptance_git_state_test_v1';status='PASS';assertions=$assertions;attached=$attached;detached=$detached;invalid_repository=$invalidRepo;missing_git=$missingGit}|ConvertTo-Json -Depth 20
