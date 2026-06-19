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
