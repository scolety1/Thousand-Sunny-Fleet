# TSF Mixed-Outcome Batch Stress Drill

Prepared: 2026-06-19

Evidence only; not executable authority or approval.

## Purpose

This drill verifies that TSF can process a messy multi-item batch with mixed
outcomes without getting stuck, looping, or pretending blocked work is complete.
It is a control-plane test run only, not open-ended policy tuning.

This is a messy multi-item batch with mixed outcomes.

This drill does not approve product repo work, PrivateLens work, proof runs,
push, merge, deploy, installs, migrations, secrets, remote access, all-fleet,
overnight/background runners, phone execution authority, runtime command
binding, lock deletion, permission widening, or broader authority.

## Assignment Definition Of Done

TSF contains a documented test drill showing it can handle a batch with mixed
outcomes and return a clear final state.

## Synthetic Batch Items

| Item | Synthetic work | Terminal state | Result |
| --- | --- | --- | --- |
| 1 | Simple eligible docs/status check | `ITEM_FINISHED_GREEN` | Completed successfully and recorded as safe docs/status work. |
| 2 | Second independent eligible item | `ITEM_FINISHED_GREEN` | Completed successfully after item 1, proving normal sequential progress. |
| 3 | Named blocker with later independent work available | `ITEM_BLOCKED_DEFERRED` | Deferred with a blocker packet; item 4 and item 5 were still evaluated instead of stopping the batch. |
| 4 | Requires Tim/HQ to choose between two safe options | `ITEM_NEEDS_HQ_INPUT` | Stopped at a specific decision request instead of guessing. |
| 5 | Low-value stale TSF meta-task | `ITEM_CALLED_OFF` | Called off because it does not improve real product/project work. |
| 6 | Dependency on item 3 | `ITEM_SKIPPED_DEPENDENCY` | Skipped because it depends on the deferred item 3 blocker. |

Required batch terminal state: `BATCH_FINISHED_PARTIAL`.

## Item 3 Blocker Packet

- item name: Synthetic item 3 - blocked evidence naming repair
- what was attempted: Codex attempted to classify the synthetic evidence naming
  item and found the item depends on a missing canonical naming choice.
- exact blocker: Missing canonical evidence name for the synthetic blocked case.
- evidence/log placeholder: `docs/fleet/TSF_MIXED_OUTCOME_BATCH_STRESS_DRILL.md`
- safest next action: Defer item 3 until HQ provides a canonical evidence name
  or explicitly calls off that naming choice.
- retry conditions: Retry only after HQ provides the canonical name or replaces
  the item with a focused repair packet.
- whether other items can continue: Yes. Items 4 and 5 are independent; item 6
  is dependency-skipped rather than used as a whole-batch stop.

## Item 4 HQ Input Request

- decision needed: Choose how TSF should label a future ambiguous but safe drill
  item.
- options:
  - Option A: mark it `ITEM_NEEDS_HQ_INPUT` when the choice changes meaning.
  - Option B: mark it `ITEM_BLOCKED_DEFERRED` when it can wait for a later
    focused packet.
- safest recommended option: Option A for this drill, because guessing would
  change the stated meaning of the item.
- consequence of doing nothing: The item remains `ITEM_NEEDS_HQ_INPUT`, while
  independent batch items may still continue when safe.

## Continued After Item 3

Codex moved past item 3 because the blocker was local to that item, the working
tree remained safe, and item 4 and item 5 were independent. Item 6 was not
attempted because it depended on item 3.

## Final Batch Report

- items completed: item 1 (`ITEM_FINISHED_GREEN`), item 2 (`ITEM_FINISHED_GREEN`)
- items blocked/deferred: item 3 (`ITEM_BLOCKED_DEFERRED`)
- items needing HQ input: item 4 (`ITEM_NEEDS_HQ_INPUT`)
- items called off: item 5 (`ITEM_CALLED_OFF`)
- items skipped: item 6 (`ITEM_SKIPPED_DEPENDENCY`)
- batch terminal state: `BATCH_FINISHED_PARTIAL`
- durable progress made: TSF now has a tracked messy-batch example proving it
  can finish eligible items, defer a named blocker, ask for specific HQ input,
  call off low-value work, and skip dependencies without pretending the whole
  batch is GREEN.
- what was not done: no product repo work, PrivateLens work, proof runs, push,
  merge, deploy, installs, migrations, secrets, remote access, all-fleet,
  overnight/background runners, phone approval, runtime command binding, lock
  deletion, permission widening, or real project task execution.
- repo safety status: docs/tests/harness-only.
- recommendation: More test drills are not useful unless a concrete TSF
  control-plane blocker appears. Move to real product/project work.

More test drills are not useful unless a concrete TSF control-plane blocker appears.

## Policy Gap Check

No new policy is required. The existing loop-closure and batch-progression
policy already covers mixed outcomes, blocked/deferred items, HQ-input items,
called-off items, dependency skips, and partial batch completion.
