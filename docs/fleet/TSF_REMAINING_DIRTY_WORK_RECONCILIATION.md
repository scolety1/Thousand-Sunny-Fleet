# TSF Remaining Dirty Work Reconciliation

Prepared: 2026-07-01

Evidence only; not executable authority or approval.

This reconciliation classifies the remaining dirty TSF-local files after the
completed HQ adapter and tuning local commit stack. It does not stage, commit,
push, deploy, install, migrate, access secrets, run proof runs, run all-fleet
commands, touch product repos, mutate PrivateLens, restore files, delete files,
start background runners, or create future execution authority.

## Closed Reference Stack

Treat these commits as closed reference only:

- `d9ce812ecd22d888c2dd4fd4583d020ac11c93fd` - `docs: add TSF HQ adapter mode`
- `c2d9aa738fd7cfdf344fb6ae4419681b724f3d4f` - `docs: add TSF HQ decision bench`
- `b7bd28299027ef452380ec90a3f94b69c5f5b9c9` - `docs: add TSF HQ tuning runbook`
- `26d937f00ae52d3ca902466ebf8c9822d4010b07` - `docs: add TSF HQ tuning dry run`

The remaining dirty work should not be folded back into those checkpoints.

## Overall Classification

The remaining dirty files form one coherent TSF anti-loop policy batch.

The batch is not adapter/tuning work. It is a related but separate control-plane
policy lane that encodes blocker-resolution builder discipline, review-only
finish-line discipline, checkpoint batching, and regression coverage in the TSF
test harness.

Recommended checkpoint shape:

- one focused anti-loop policy checkpoint containing the four remaining dirty
  files, after a focused validation pass
- no adapter/tuning files included
- no push unless Tim later explicitly says to push

## Dirty File Classification

| Path | Status | Summary Of Change | Workstream | Belongs In One Coherent Checkpoint Batch | Risks If Included | Risks If Excluded | Recommended Next Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md` | modified | Adds blocker-resolution builder rule and review-only phase finish-line rule; references the new blocker-resolution policy; reinforces checkpoint batching, exclude-and-move-on, YELLOW acceptance, and no app/model/ranking scope. | TSF anti-loop policy work | yes | Low to medium: expands the no-treadmill policy and should be reviewed with the companion policy/test changes so the policy surface is coherent. | Medium: leaving it uncheckpointed keeps important anti-loop guidance outside versioned history and separates it from its regression coverage. | Include in a focused anti-loop policy checkpoint after validation. |
| `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md` | modified | Adds `unblockArtifact`, `phaseFinishLine`, and `mergePlan` prompt fields; adds builder/finish-line posture to exit summaries; adds next-move options for blocker-resolution builders and checkpoint batch merges. | TSF anti-loop policy work | yes | Low to medium: changes the prompt/checklist contract and should be reviewed with the new policy that explains the behavior. | Medium: policy would exist without the working checklist prompts that make Codex produce the needed fields. | Include in the same focused anti-loop policy checkpoint after validation. |
| `tests/run-fleet-tests.ps1` | modified | Adds `Test-HqTsfBlockerResolutionBuilderLanePolicy`; verifies the new policy, no-treadmill integration, checklist integration, artifact-producing lane requirements, blocked authority boundaries, and forbidden-authority wording; wires the test into the fleet test suite. | test harness work supporting TSF anti-loop policy | yes | Medium: broadens the fleet test harness and should be validated before checkpointing; line-ending warning notes LF may be replaced by CRLF when Git touches the file. | Medium to high: policy/checklist changes would lack regression coverage and future edits could silently weaken the guardrail. | Include in the same focused anti-loop policy checkpoint only after running a focused validation pass and, ideally, the relevant fleet test command if allowed. |
| `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md` | untracked | New evidence-only policy describing the observed blocker-documentation treadmill, wrong finish-line failure mode, checkpoint merge rule, exclude-and-move-on rule, lane declaration requirements, no blocker-only lane rule, parallel-lane rule, artifact preference, and final report addendum. | TSF anti-loop policy work | yes | Low to medium: new policy artifact is substantial and should be reviewed with its integrations and test coverage. | High: the modified no-treadmill policy and test harness reference this file, so excluding it would leave dangling policy/test expectations. | Include in the same focused anti-loop policy checkpoint after validation. |

## Recommended Batch Grouping

Batch name: TSF blocker-resolution anti-loop policy checkpoint.

Include together:

- `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md`
- `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md`
- `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md`
- `tests/run-fleet-tests.ps1`

Reason: these files implement one coherent policy lane. The new policy defines
the rule, the no-treadmill policy integrates it, the anti-loop checklist makes
future prompts and handoffs capture it, and the test harness protects the
expected phrases and authority boundaries.

Do not include:

- closed HQ adapter/tuning files
- product repo files
- archived project files
- generated status files unrelated to this policy lane

## Tim / Restore Assessment

No file currently needs Tim merely to discard or restore, because local diff
inspection is enough to classify them and they appear coherent.

Tim would be needed only if the desired next action is to discard this policy
batch, push it, broaden it into product repo work, run disallowed proof or
all-fleet work, or convert it into background/overnight automation.

## Focused Validation Need

This batch needs a focused validation pass before checkpointing.

Minimum recommended validation before a future checkpoint:

- `git diff --check -- docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md tests/run-fleet-tests.ps1`
- direct whitespace/path validation for `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md`, because untracked files are not covered by normal `git diff --check`
- a targeted check that the new policy file exists and that the modified test references only TSF-local docs
- if explicitly allowed in that future checkpoint lane, run the safe TSF fleet test script or the narrowest available policy test path

## Left-Alone Assessment

The completed adapter/tuning stack should be left alone. It remains cleanly
isolated from this anti-loop policy batch.

The remaining dirty files should not be restored, deleted, staged, or committed
inside this reconciliation lane. They should wait for a separate explicit
anti-loop policy checkpoint instruction.

## Guardrails Confirmed

- product repos untouched
- PrivateLens untouched
- archived projects not reactivated
- no push performed
- no deploy performed
- no install performed
- no migration performed
- no secrets/auth/payments accessed
- no proof run performed
- no all-fleet command performed
- no remote access used
- no background, overnight, or watcher process started

## Final Recommendation

Proceed later with one focused TSF anti-loop policy checkpoint if Tim wants this
batch preserved. The checkpoint should include all four remaining dirty files
and should run focused validation first.

Do not split these into adapter/tuning work. Do not checkpoint the test harness
without the policy file it verifies. Do not push unless Tim explicitly approves
after the checkpoint is created and validated.
