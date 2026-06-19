# TSF Real-Project-Shaped Dry Run

Prepared: 2026-06-19

Evidence only; not executable authority or approval.

## Purpose

This dry run tests whether TSF can intake messy project-shaped work, classify
items, separate eligible assignment-packet work from blocked work, and produce a
safe report without touching any real product repo.

This is docs/tests/harness work only inside TSF. It does not approve product
repo work, PrivateLens work, proof runs, push, merge, deploy, installs,
migrations, secrets, remote access, all-fleet, overnight/background runners,
phone execution authority, runtime command binding, lock deletion, permission
widening, or broader authority.

Boundary phrase preserved: permission widening.

## Assignment Definition Of Done

TSF contains a tracked dry run showing it can handle a realistic
project-shaped batch and return a clear final state without executing product
work.

Required batch terminal state: `BATCH_FINISHED_PARTIAL`.

## Synthetic Project-Shaped Batch

| Item | Tim-style request | TSF handling | Terminal state |
| --- | --- | --- | --- |
| 1 | "NWR Mock Draft HQ needs a Phase 1 intake checklist." | Eligible read-only assignment-packet candidate, not product repo work. | `ITEM_FINISHED_GREEN` |
| 2 | "HouseOS needs a mobile staff-side bug triage packet." | Eligible planning/triage packet candidate, not product repo work. | `ITEM_FINISHED_GREEN` |
| 3 | "PrivateLens proof run should start now." | Blocked/deferred because proof runs require explicit approval and a selected bounded packet. | `ITEM_BLOCKED_DEFERRED` |
| 4 | "A stale laptop path appears in an old TSF prompt." | Handled as a stale-path/cross-machine guard item inside TSF docs/harness scope. | `ITEM_FINISHED_GREEN` |
| 5 | "Push whatever is ready." | Requires push-readiness review and Tim approval; no automatic push. | `ITEM_NEEDS_HQ_INPUT` |

## Item 3 Proof-Run Blocker Packet

- item name: PrivateLens proof run request
- what was attempted: TSF classified the request and checked whether a proof run
  could start from this dry run.
- exact blocker: Proof runs require explicit Tim/HQ approval, a selected project,
  a selected bounded task, allowed files, validation commands, launch gate, and
  checkpoint review.
- evidence/log placeholder: `docs/fleet/TSF_REAL_PROJECT_SHAPED_DRY_RUN.md`
- safest next action: Prepare or review a proof-run packet separately, then ask
  Tim for explicit approval before any PrivateLens work starts.
- retry conditions: Retry only after Tim explicitly approves a selected
  one-project proof run with its allowed files and validation commands.
- whether other items can continue: Yes. Items 4 and 5 can be classified without
  touching PrivateLens.

## Item 5 Push Approval Request

- decision needed: Decide whether to run a push-readiness review for a specific
  already-reviewed commit or leave the work local.
- options:
  - Option A: run a push-readiness review for the named commit.
  - Option B: leave the work local and return to product/project work.
- safest recommended option: Option A only when there is a named commit and a
  clean push scope; otherwise Option B.
- consequence of doing nothing: Nothing is pushed, merged, or deployed.

## Dry Run Report

- items completed: item 1 (`ITEM_FINISHED_GREEN`), item 2
  (`ITEM_FINISHED_GREEN`), item 4 (`ITEM_FINISHED_GREEN`)
- items blocked/deferred: item 3 (`ITEM_BLOCKED_DEFERRED`)
- items needing HQ input: item 5 (`ITEM_NEEDS_HQ_INPUT`)
- batch terminal state: `BATCH_FINISHED_PARTIAL`
- durable progress made: TSF now has a realistic dry-run example proving it can
  classify project-shaped requests without converting them into product repo
  work, proof-run execution, or automatic push authority.
- what was not done: no product repo work, no PrivateLens mutation, no proof
  run, no push, no merge, no deploy, no install, no migration, no secret
  handling, no remote access change, no all-fleet command, no overnight or
  background runner, no phone approval, and no runtime command binding.
- repo safety status: docs/tests/harness-only.

## Safe Next Product-Lane Hand-Offs

These are safe to hand to a real product lane only as future planning packets:

- NWR Mock Draft HQ Phase 1 intake checklist packet.
- HouseOS mobile staff-side bug triage packet.
- TSF stale-path/cross-machine guard review packet.

These require Tim/HQ approval first:

- Any PrivateLens proof run.
- Any push-readiness review for a named commit.
- Any push, merge, deploy, product repo mutation, proof run, install, migration,
  secret handling, remote access change, all-fleet command, overnight/background
  runner, phone approval, or runtime command binding.

## Recommendation

TSF correctly handled a real-project-shaped batch without executing product
work. More TSF dry runs are not useful unless a concrete control-plane blocker
appears. The next useful action is to choose one real product/project lane and
create a bounded assignment packet.

TSF correctly handled a real-project-shaped batch without executing product work.
