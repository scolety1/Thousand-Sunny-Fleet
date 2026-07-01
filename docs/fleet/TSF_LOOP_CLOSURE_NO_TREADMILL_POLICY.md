# TSF Loop Closure No-Treadmill Policy

Prepared: 2026-06-19

Evidence only; not executable authority or approval.

## Purpose

TSF loops should feel like progress toward an end goal, not an endless stream of
similar next prompts. Every Codex loop must either finish the assignment's
Definition of Done, stop and request specific help, or call off the assignment
with a clear reason.

In short: finish the assignment's Definition of Done, request help, or stop.

This policy is docs/tests/harness-only. It does not approve product repo work,
PrivateLens work, proof runs, push, merge, deploy, installs, migrations,
secrets, remote access, all-fleet, overnight/background runners, phone
execution authority, runtime command binding, lock deletion, permission
widening, or broader authority.

Boundary keywords preserved: phone execution authority; permission widening.

## Loop Terminal States

Every TSF/Codex loop must end as exactly one of these states:

- `FINISHED_GREEN`: assignment Definition of Done completed and validation passed.
- `PUSH_DECISION_READY`: reviewed GREEN and waiting only for Tim's push approval.
- `VALIDATION_RERUN_REQUIRED`: content clean but full validation incomplete or timed out.
- `FOCUSED_REPAIR_REQUIRED`: known blocker identified and bounded repair needed.
- `NEEDS_HQ_INPUT`: Codex cannot safely choose without Tim/HQ decision.
- `CALLED_OFF`: assignment is unsafe, stale, not worth continuing, or no longer aligned with the goal.
- `RED_BLOCKED`: hard blocker or safety violation risk.

Reports must name the terminal state. A report that ends with only "continue",
"next bounded task", "rerun", or "more polish" is incomplete unless it also
names one of the terminal states above and explains why that next action directly
advances the original assignment or resolves a named blocker.

## Batch Progression Rule

When Tim gives multiple errors/tasks, the goal is to process the whole eligible
list, not to get stuck on the first blocker. A blocked item should become
evidence for a focused follow-up while Codex moves to the next safe independent
item.

When Tim gives multiple errors/tasks, the goal is to process the whole eligible list.

One item blocker must not stop the whole batch unless it creates a global
blocker.

One item blocker must not stop the whole batch unless it creates a global blocker.

## Per-Item Terminal States

Each batch item must end as exactly one of these states:

- `ITEM_FINISHED_GREEN`: item was completed and relevant validation passed.
- `ITEM_BLOCKED_DEFERRED`: item has a known blocker and should be retried later only with new information or a focused repair packet.
- `ITEM_NEEDS_HQ_INPUT`: item cannot safely proceed without Tim/HQ choosing a path.
- `ITEM_SKIPPED_DEPENDENCY`: item depends on another blocked/deferred item.
- `ITEM_CALLED_OFF`: item is no longer useful, stale, unsafe, or not aligned with the batch goal.
- `ITEM_RED_BLOCKED`: item has a hard blocker or safety violation risk.

## Batch Terminal States

Each batch must end as exactly one of these states:

- `BATCH_FINISHED_GREEN`: every eligible item finished GREEN.
- `BATCH_FINISHED_PARTIAL`: at least one item finished and at least one item was blocked, skipped, called off, or deferred without creating a global stop.
- `BATCH_NEEDS_HQ_INPUT`: Tim/HQ input is required before choosing a safe batch path.
- `BATCH_RED_BLOCKED`: a hard blocker or safety risk stops the whole batch.
- `BATCH_CALLED_OFF`: the batch is stale, unsafe, no longer useful, or not worth continuing.

## Move-On Rule

If one item is blocked but the repo remains safe and later items are independent,
Codex must record the blocker and move to the next eligible item. The next item
must still respect allowed files, validation commands, stop conditions, and
safety boundaries.

The loop should not convert one item failure into a whole-batch failure unless a
global stop condition is active.

## Global Stop Rule

Codex stops the whole batch only if:

- the working tree cannot be kept safe
- continuing risks product repo, PrivateLens, proof, deploy, runtime, phone, secret, remote-access, all-fleet, or overnight boundary crossing
- the blocked item is a dependency for all remaining items
- validation infrastructure is broken
- Tim/HQ input is required to choose a safe path
- the batch goal is stale or not worth continuing

## No Treadmill Rule For Batch Items

Codex must not repeatedly rerun the same blocked item without new information.
After repeated failure on one item, mark it blocked/deferred and continue if
safe. Repeated item failure should produce `ITEM_BLOCKED_DEFERRED`,
`ITEM_NEEDS_HQ_INPUT`, `ITEM_CALLED_OFF`, or `ITEM_RED_BLOCKED`, not another
generic rerun.

After repeated failure on one item, mark it blocked/deferred and continue if safe.

## Blocker Packet Rule

For every blocked/deferred item, Codex must record:

- item name
- what was attempted
- exact blocker
- evidence/log path if applicable
- safest next action
- whether it can be retried later
- whether other items can continue

## Blocker-Resolution Builder Rule

Every blocker lane must name the concrete artifact that would unblock the next builder.
If the blocker can be attacked directly, the next lane should build the unblock artifact instead of writing another packet that only restates the same blocker.

No blocker-only lane is allowed unless the blocker requires a Tim/HQ decision,
crosses a safety boundary, or the lane is producing a policy matrix, validator,
or exact decision packet that directly enables a builder.

HQ should ask after every lane: "Can the next lane build, or are we just documenting?"
If the answer is "just documenting," stop and redirect unless the
documentation is the unblock artifact.

A YELLOW packet may be safe to merge, but it is not durable progress unless it removes a blocker or narrows the next build.

See `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md`.

## Review-Only Phase Finish-Line Rule

Review-only phases must declare the useful finish line before adding more lanes.
The wrong finish line can turn a bounded source/data phase into endless proof
work. The phase is done enough when the agreed artifact, field map, missingness
behavior, validation summary, source mappings, guardrails, and blocked/excluded
scope are documented.

Merge only at checkpoints. Batch evidence packets that feed one builder instead
of creating merge churn after every small lane.

Prefer exclude and move on over investigate forever. YELLOW is acceptable when it means safe, review-only, incomplete by design.

No more lanes unless they produce one of: dataset, schema, validator, field map, sidecar, or merge-ready policy artifact.

No app wiring, model logic, or rankings belong in a review-only source/data
phase unless Tim explicitly approves that scope.

## Final Batch Report Rule

Every batch report must include:

- items completed
- items blocked/deferred
- items skipped
- items called off
- durable progress made
- whether repo is clean
- whether product repos/PrivateLens/proof boundaries stayed untouched
- recommended next action

## Batch Example

If Tim gives 5 errors:

- Try error 1.
- If fixed, mark `ITEM_FINISHED_GREEN`.
- Try error 2.
- If blocked, mark `ITEM_BLOCKED_DEFERRED`.
- Move to error 3 if independent and safe.
- Continue until all 5 are processed or a global stop condition appears.
- Final batch may be `BATCH_FINISHED_PARTIAL`, which is acceptable progress.

Final batch may be BATCH_FINISHED_PARTIAL, which is acceptable progress.

## No Treadmill Rule

Codex must not keep recommending generic "continue", "next bounded task", or
"rerun" prompts unless the next action directly advances the original assignment
or resolves a named blocker.

Acceptable next actions name the original assignment, the blocker or Definition
of Done item they advance, the allowed files, the validation command, and the
expected terminal state. Vague queue-filling is not progress.

## Finish-Or-Stop Rule

If the assignment's Definition of Done is reachable within allowed scope, Codex
should finish it. If it is not reachable, Codex must stop and say exactly what is
missing: missing authority, missing file access, missing validation, missing HQ
decision, missing product-value proof, or a safety boundary.

The default is not "keep going". The default is finish the assignment, request specific help, or call it off.

## Repeated Failure Rule

After repeated timeout, failure, or review loops, Codex must switch from generic
reruns to focused diagnosis or call off the assignment. Repeated validation failures should not produce endless validation prompts.

If the same timeout, failure, missing context, validation ambiguity, or review finding appears twice without new evidence, the next terminal state should be
`FOCUSED_REPAIR_REQUIRED`, `NEEDS_HQ_INPUT`, `CALLED_OFF`, or `RED_BLOCKED`, not
another generic rerun.

## Help Request Rule

When Codex needs Tim/HQ, the request must be specific:

- what decision is needed
- what options exist
- safest recommended option
- consequence of doing nothing

If Codex cannot ask a specific question, it should continue local diagnosis only
when that diagnosis is within allowed scope and likely to resolve a named
blocker. Otherwise use `NEEDS_HQ_INPUT` or `CALLED_OFF`.

## Call-Off Rule

Codex may recommend calling off an assignment when:

- the work is no longer useful
- it is becoming meta-work without product value
- it requires blocked permissions
- it repeatedly fails for unclear reasons
- it risks crossing product/proof/runtime boundaries
- the original end goal is already satisfied

`CALLED_OFF` is a valid outcome. It is better than continuing a low-value loop
just because another small policy or checklist could be written.

## Progress Proof Rule

Each final report must explain what is now possible that was not possible
before, or say: "no durable progress was made."

Examples:

- "Now TSF can classify loop exits into seven terminal states."
- "Now HQ can decide between a focused repair and calling off the assignment."
- "No durable progress was made; validation repeated the same failure."

## Product-Value Checkpoint

For TSF meta-work, reports must say whether the work improves actual future
product work or is only control-plane cleanup. If the value is low, Codex should
recommend stopping TSF tuning and moving to a real product lane.

Useful TSF meta-work reduces future confusion, shortens a real product workflow,
prevents a known safety risk, improves handoff quality, or removes a blocker to
safe product work. If it does none of those, choose `CALLED_OFF` or
`NEEDS_HQ_INPUT` instead of creating more TSF cleanup.

## Report Contract

Every loop report should include:

- terminal state
- assignment Definition of Done status
- named blocker or missing item, if any
- validation result
- what is now possible that was not possible before, or "no durable progress was made"
- whether this improves future product work or is only control-plane cleanup
- specific Tim/HQ question, if needed
- safest recommended option
- consequence of doing nothing
- next action only if it directly advances the original assignment or resolves a named blocker

## Examples

```text
Terminal state: FINISHED_GREEN
Progress proof: Now TSF can enforce loop terminal states in reports.
Product-value checkpoint: Control-plane cleanup with medium product value because it prevents wasted remote loops before real product work.
Next action: Review for push readiness.
```

```text
Terminal state: CALLED_OFF
Progress proof: no durable progress was made.
Product-value checkpoint: Low value; this is becoming meta-work without product value.
Next action: Stop TSF tuning and move to a real product lane after Tim chooses one.
```
