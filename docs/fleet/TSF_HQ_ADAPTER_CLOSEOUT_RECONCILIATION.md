# TSF HQ Adapter Closeout Reconciliation

Prepared: 2026-07-01

Evidence only; not executable authority or approval.

## Purpose

This reconciliation separates the finished `TSF_HQ_ADAPTER_MODE.md` artifact
from other currently dirty TSF-local control-plane changes. It is a closeout
classification only. It does not stage, commit, push, deploy, install, migrate,
access secrets, run proof runs, run all-fleet commands, touch product repos,
reactivate archived projects, start background runners, or grant future
authority.

## Adapter Done-Enough Verdict

`docs/fleet/TSF_HQ_ADAPTER_MODE.md` is done enough for a TSF-local adapter-mode
artifact.

Focused validation confirmed:

- the file exists
- required HQ response headings exist
- the canonical JSON decision schema appears exactly once
- no wording pattern was found that grants authority to push, deploy, install,
  migrate, access secrets, run proof runs, run all-fleet commands, or touch
  product repos

No concrete defect was found that requires editing the adapter document in this
closeout pass.

## Dirty File Classification

| Path | Status | Adapter-Owned | Appears Pre-Existing Or Unrelated | Include In Adapter Checkpoint | Exclude From Adapter Checkpoint | Risks If Included | Risks If Excluded | Recommended Next Action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/fleet/TSF_HQ_ADAPTER_MODE.md` | untracked | yes | no; created as the primary HQ adapter artifact | yes | no | Low: new evidence-only operating-mode doc must stay non-authoritative and validated. | High: adapter mode would not be captured, leaving HQ routing guidance outside the checkpoint. | Include in an adapter-only checkpoint after final checks. |
| `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md` | modified | no | yes; changes are earlier blocker-resolution and review-only finish-line policy wiring | no | yes | Medium: including it blends prior policy work into the adapter checkpoint and makes scope harder to review. | Low to medium: adapter remains standalone, but no-treadmill policy wiring remains uncheckpointed until a separate policy checkpoint. | Exclude from adapter-only checkpoint; handle in separate blocker-resolution policy checkpoint. |
| `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md` | modified | no | yes; changes are earlier unblock-artifact, phase-finish-line, merge-plan, and builder-posture checklist wiring | no | yes | Medium: including it expands the adapter checkpoint into broader anti-loop prompt checklist work. | Low to medium: adapter remains complete, but checklist reinforcement remains uncheckpointed. | Exclude from adapter-only checkpoint; handle with the blocker-resolution policy/checklist checkpoint. |
| `tests/run-fleet-tests.ps1` | modified | no | yes; diff adds regression coverage for the blocker-resolution builder lane policy, not the HQ adapter artifact | no | yes | Medium to high: including tests introduces a broader validation scope unrelated to the adapter-only artifact and may imply policy/test coupling that this closeout did not rework. | Medium: the separate blocker-resolution policy remains without its regression test checkpoint until handled separately. | Exclude from adapter-only checkpoint; include later with the blocker-resolution policy checkpoint after full suite validation. |
| `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md` | untracked | no | yes; created before the HQ adapter artifact as a separate but related policy against blocker-documentation loops | no | yes | Medium: including it would combine two operating-mode artifacts and muddy review ownership. | Low to medium: HQ adapter is standalone, but the blocker-resolution policy remains uncheckpointed. | Exclude from adapter-only checkpoint; checkpoint separately with its policy wiring and tests. |

## Recommended Adapter Checkpoint

Include:

- `docs/fleet/TSF_HQ_ADAPTER_MODE.md`
- `docs/fleet/TSF_HQ_ADAPTER_CLOSEOUT_RECONCILIATION.md`

Exclude from the adapter-only checkpoint:

- `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md`
- `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md`
- `tests/run-fleet-tests.ps1`
- `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md`

Reason: the adapter artifact is complete and usable on its own. The other dirty
files are related TSF control-plane guardrail work from the blocker-resolution
lane and should be reviewed as a separate policy/test checkpoint.

## Validation Notes

Focused adapter validation was run before writing this reconciliation artifact.
It confirmed required headings, exactly one canonical JSON decision schema, and
no forbidden authority grant pattern.

Final closeout should still report:

- `git diff --check`
- `git status --short`

## Tim Needed

Tim is not needed for the adapter artifact itself.

Tim is only needed later if a checkpoint requires push, deploy, installs,
migrations, secrets/auth/payments, remote access, proof runs, all-fleet
commands, background/overnight runners, archived project reactivation, product
repo mutation/access, spending, external account changes, or product direction.

## Final Note

This reconciliation is evidence only. It recommends checkpoint scope but does
not stage, commit, push, merge, deploy, or grant authority.
