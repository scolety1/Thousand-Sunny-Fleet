# TSF Synthetic Batch Drill

Prepared: 2026-06-19

Evidence only; not executable authority or approval.

## Purpose

This drill proves the TSF loop-closure and batch-progression policies on a
safe synthetic docs/tests/harness batch. It demonstrates that one blocked item
does not stop the whole batch, independent later items continue, every item gets
a terminal state, the batch gets a terminal state, and the final report
distinguishes durable progress from deferred blockers.

This drill does not approve product repo work, PrivateLens work, proof runs,
push, merge, deploy, installs, migrations, secrets, remote access, all-fleet,
overnight/background runners, phone execution authority, runtime command
binding, lock deletion, permission widening, or broader authority.

## Assignment Definition Of Done

TSF contains a documented synthetic batch drill proving:

- one blocked item does not stop the whole batch
- independent later items continue
- every item gets a terminal state
- every item receives a terminal state
- the batch receives a terminal state
- the final report distinguishes durable progress from deferred blockers

## Synthetic Batch Items

| Item | Synthetic work | Terminal state | Result |
| --- | --- | --- | --- |
| 1 | Fixable docs-only typo/checklist item | `ITEM_FINISHED_GREEN` | Completed in the drill by recording the corrected checklist wording as safe docs-only work. |
| 2 | Fake blocked item requiring missing HQ input | `ITEM_BLOCKED_DEFERRED` | Deferred because HQ must choose between two acceptable labels before the item can be resolved. |
| 3 | Later independent docs/status item | `ITEM_FINISHED_GREEN` | Completed after item 2 was deferred, proving the batch moved on safely. |
| 4 | Stale or low-value item | `ITEM_CALLED_OFF` | Called off because it would create low-value TSF meta-work without improving future product execution. |
| 5 | Dependent item that needs item 2 | `ITEM_SKIPPED_DEPENDENCY` | Skipped because it depends on the HQ decision blocked in item 2. |

Required batch terminal state: `BATCH_FINISHED_PARTIAL`.

## Blocker Packet

- item name: Synthetic item 2 - missing HQ label decision
- what was attempted: Codex reviewed the synthetic item and identified that two
  labels would both be safe, but choosing between them would change the stated
  drill meaning.
- exact blocker: Missing HQ input on which label should be canonical for this
  synthetic blocked case.
- evidence/log path if applicable: `docs/fleet/TSF_SYNTHETIC_BATCH_DRILL.md`
- safest next action: Leave item 2 as `ITEM_BLOCKED_DEFERRED` and ask HQ to
  choose the label only if the synthetic drill is reused.
- whether it can be retried later: Yes, after HQ provides the label decision.
- whether other items can continue: Yes. Items 3 and 4 are independent, and item
  5 is skipped as a dependency rather than stopping the whole batch.

## Continued After Blocker

Codex continued after item 2 because the repo remained safe, item 3 was
independent, and no global stop condition was active. The blocked item became a
blocker packet, not a whole-batch failure.

## Final Batch Report

- items completed: item 1 (`ITEM_FINISHED_GREEN`), item 3 (`ITEM_FINISHED_GREEN`)
- items blocked/deferred: item 2 (`ITEM_BLOCKED_DEFERRED`)
- items skipped: item 5 (`ITEM_SKIPPED_DEPENDENCY`)
- items called off: item 4 (`ITEM_CALLED_OFF`)
- durable progress made: TSF now has a tracked synthetic example proving that a
  blocked batch item can be recorded and bypassed while later independent items
  still finish.
- batch terminal state: `BATCH_FINISHED_PARTIAL`
- repo safety status: docs/tests/harness-only; no product repos, PrivateLens,
  proof runs, push, merge, deploy, installs, migrations, secrets, remote access,
  all-fleet, overnight/background runners, phone execution authority, runtime
  command binding, lock deletion, permission widening, or broader authority.
- recommended next action: use the drill as a reference during future batch
  reports, then move to real product/project work unless a concrete TSF control
  blocker appears.

## What Was Intentionally Not Done

- No product repo or PrivateLens file was read or changed.
- No proof run was started.
- No push, merge, deploy, package install, migration, remote access change,
  secret handling, all-fleet command, overnight/background runner, phone
  approval, or runtime command binding was performed.
- No real project task was disguised as a synthetic drill item.

## Product-Value Checkpoint

This is useful TSF meta-work because it turns the new batch policy into a
concrete example that future reports can follow. Additional TSF meta-tuning
should stop unless it removes a named blocker; the next useful step is real
product/project work using the policy.
