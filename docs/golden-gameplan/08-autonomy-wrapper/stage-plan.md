# Golden Gameplan Stage 8: Autonomy Wrapper

## Purpose

Stage 8 creates the first bounded "autopilot wrapper" around the earlier pieces.

Stages 1-7 give the fleet:

- stable launch behavior
- standard run evidence
- audit packages
- task packet ingestion
- ship state
- decisions
- product quality contracts

Stage 8 ties those together into one controlled cycle:

```text
inspect -> decide -> run/package/wait/park -> report
```

This is not full overnight autonomy yet. It is the safe wrapper that proves the fleet can take one bounded step without a human manually stitching every script together.

Stage 8 depends on Stages 1-7. If any required earlier contract is missing,
the wrapper should report the missing dependency instead of inventing a parallel
implementation.

## Why This Matters

The user wants to be able to say:

```text
Run the fleet.
Check if it got stuck.
Patch what is systemic.
Package what needs review.
Stop when taste is needed.
Do not burn limits forever.
```

Before overnight mode, the fleet needs a single command that can perform a bounded cycle and explain what happened.

## Stage 8 Outcome

At the end of Stage 8, the fleet should have:

- one wrapper command for a bounded autonomy cycle
- dry-run mode
- selected ship targeting
- safe decision execution for low-risk actions
- strict no-action behavior for blocked/unknown/high-risk states
- clear run budget limits
- final report output
- evidence that no endless loop is possible

## Non-Goals

Do not implement these in Stage 8:

- unattended overnight scheduling
- phone/mobile control
- automatic rate-limit resume
- automatic merge/push/deploy
- broad production mutations
- external agent orchestration beyond consuming already-approved packets

Those belong to later stages.

## Autonomy Cycle

The wrapper should eventually support:

```text
1. Load selected ships.
2. Refresh state.
3. Normalize evidence.
4. Compute decision.
5. Execute only approved bounded actions.
6. Write reports.
7. Stop.
```

## Approved Bounded Actions

Stage 8 may plan for these actions:

```text
NOOP
RUN_ONE_BATCH
MAKE_AUDIT_PACKAGE
IMPORT_APPROVED_PACKET
WRITE_REPAIR_TASK
WRITE_STATUS_REPORT
PARK_SHIP
REQUEST_TASTE_GATE
WAIT_FOR_RATE_RESET
BLOCK_WITH_REASON
```

The wrapper should never silently:

- run forever
- launch every ship
- delete user work
- kill active work
- merge, push, or deploy
- edit downstream products outside a selected run

`IMPORT_APPROVED_PACKET` means a packet that has already passed Stage 4 schema,
staleness, duplicate, and scope validation. It must not mean "trust an external
agent response and append it directly."

`RUN_ONE_BATCH` means one selected ship, one bounded batch, with clean scope,
budget, state, and decision checks. It must not mean "keep looping until the
site looks good."

## Product Quality Evidence Handoff

Stage 8 consumes the Stage 7 `productQuality` object as a product-facing vote,
not as a replacement for deterministic safety gates. The wrapper should inspect:

- `demoPromiseStatus`
- `firstScreenStatus`
- `informationHierarchyStatus`
- `simplicityGateStatus`
- `mobileStatus`
- `doneContractStatus`
- `tasteGateStatus`
- `screenshots`
- `reviewerNotes`
- `productQualityDecisionHint`

Decision handoff:

| Evidence condition | Stage 8 action preference |
|---|---|
| Product promise, first screen, hierarchy, or simplicity fails | `BLOCK` or write a bounded repair task. |
| `simplicityGateStatus` is `FAIL_OVERLOADED` | `BLOCK`; do not taste-gate or park an overloaded first screen. |
| Mobile fails on customer-facing lanes | Repair before `PARK`. |
| Done contract is not met but scoped work remains | `RUN_AGAIN` for one bounded batch. |
| Done contract is met and taste gate passes | `PARK`. |
| Taste gate says subjective review is needed | `USER_TASTE_GATE`. |
| `productQualityDecisionHint` is present | Treat it as the product-quality vote, then combine it with state, scope, budget, and safety rules. |

Example product-quality fragment lives in
`docs/templates/product-quality/PRODUCT_QUALITY_EVIDENCE.md`. Stage 8 should
read that contract before implementing runtime writer changes.

## Phase List

1. Wrapper Command Contract
2. Dry-Run Planner
3. Selected Ship Scope
4. Safe Action Executor
5. Budget and Loop Limits
6. Report and Evidence Output
7. Failure Containment
8. Stage 8 Integration Check

## Acceptance For Stage 8

Stage 8 is complete when:

- a bounded autonomy command is specified
- dry run can show intended actions without executing them
- selected ship scope is mandatory
- decisions map to safe bounded actions
- high-risk decisions block instead of acting
- loop limits make endless execution impossible
- final report explains what happened and what still needs the captain

## Hand-Off To Stage 9

Stage 9 will formalize the external agent workflow: creating audit packages, sending prompts, receiving task packets, and deciding when outside review is useful.
