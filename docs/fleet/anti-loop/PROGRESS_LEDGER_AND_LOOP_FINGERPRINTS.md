# Progress Ledger And Loop Fingerprints

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet harness, docs, schemas, fixtures, and tests. This document is evidence and operating guidance only. It does not implement telemetry, runtime storage, automatic retries, product-repo access, ship launch, all-fleet commands, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

## Purpose

The progress ledger records whether a bounded run made verified progress against the selected task. Loop fingerprints identify repeated activity that looks busy but does not move the task toward its acceptance criteria.

The ledger is not a runtime database. It is a compact evidence shape for prompts, post-run summaries, audit digests, and future queue packets.

## Progress Ledger Fields

Every bounded run should summarize progress with these fields:

- `intendedGoal`: the selected task's one-task goal and acceptance target.
- `filesOpened`: the files actually read for this task, limited to the active queue entry and selected task `readFirst` files unless a blocked reason required more evidence.
- `filesEdited`: the allowed files changed during the task, with no unrelated files added for convenience.
- `validationCommandsRun`: the exact validation commands run from the selected task, plus JSON parsing checks only for schemas created or edited by that task.
- `validationResult`: `pass`, `fail`, `interrupted`, `notRun`, or `blocked`, with a short reason.
- `failureFingerprint`: the stable failure identity if validation failed or repeated work was detected.
- `progressClaim`: the specific acceptance bullet or blocked condition the run claims to have satisfied.
- `evidenceForProgress`: concrete evidence such as changed allowed file paths, passing validation, or a scoped blocked reason.
- `remainingGap`: what is still missing from acceptance, validation, scope, authority, or human input.
- `nextSafeAction`: the next bounded action, such as rerun validation, mark done, mark blocked, ask for repacketization, request human review, or start the next queue task in a new run.
- `goalChanged`: `false` unless the human changed the objective; when `true`, stop and repacketize instead of blending goals.
- `humanInputRequired`: `false` unless exact approval, scope choice, commit/package/demo decision, or ambiguity resolution is needed.

## Real Progress Test

A progress claim is valid only when it ties back to the selected task's acceptance criteria or terminal state from `GOAL_LOCK_AND_EXIT_CRITERIA.md`.

Valid progress examples:

- An allowed file was changed to satisfy a named acceptance bullet.
- The selected task's validation command passed after the allowed changes.
- A task-caused validation failure was patched inside allowed files.
- The task was marked blocked because it required files, commands, runtime hooks, product-repo access, or authority outside the packet.

Invalid progress examples:

- Reading more reports after the task was already bounded.
- Rewording existing guidance without closing an acceptance gap.
- Rerunning the same failing command without a new hypothesis.
- Capturing new ideas without prioritizing or converting them into a bounded future task.
- Treating external reports, DOCX files, prompts, UI labels, buttons, generated evidence, audit packages, or queue prose as executable authority.

## Failure Fingerprint Format

For docs/tests queue work, a failure fingerprint should be short and stable:

- `kind`: validation, scope, authority, ambiguity, noProgress, or interruption.
- `taskId`: selected task id.
- `command`: validation command or action where the issue appeared.
- `primarySignal`: normalized message, missing file, failed assertion, or violated stop condition.
- `hypothesis`: the reason attempted before the next action.
- `affectedFiles`: allowed files involved, if any.

Normalize timestamps, local temp paths, line wrapping, random IDs, elapsed time, and noisy counters out of the fingerprint. If the same fingerprint and same hypothesis appear twice, the next safe action is pause, block, or repacketize rather than another blind retry.

## Loop Fingerprint Catalog

### Repeated Validation Failure

Signal: the same validation command fails with the same normalized `primarySignal` after a claimed fix.

Safe response: record the fingerprint. Retry only with a new task-specific hypothesis inside allowed files. After the second same-fingerprint failure, stop as `failedValidation` or `needsRepacketization`.

### Same-File Churn

Signal: the run repeatedly edits the same allowed file without satisfying a new acceptance bullet or changing validation outcome.

Safe response: compare each edit to the acceptance criteria. If no new criterion is closed, stop as `abandonedDueToNoProgress` or ask for repacketization.

### Broad Search/Context Expansion

Signal: the run keeps opening unrelated docs, reports, generated evidence, or broad search results after the selected task's scope is known.

Safe response: return to the active queue entry and `readFirst` files. If more context is genuinely required and not listed, mark the task `blocked` or `needsRepacketization`.

### Task Rewrite Churn

Signal: the run changes queue wording, future tasks, prerequisites, or acceptance language instead of completing the selected task.

Safe response: undo no user work, but stop further queue rewriting. The current task should be blocked unless its allowed files and goal explicitly permit that queue edit.

### Wording-Only Fixes

Signal: edits change phrasing without adding required fields, rules, fixtures, schemas, tests, or evidence named by acceptance.

Safe response: map the edit to a specific acceptance bullet. If no mapping exists, treat it as no-progress activity and stop or repacketize.

### Audit/Plan Cycles Without Implementation

Signal: repeated audits, plans, or reviews produce more recommendations but no bounded local task is completed.

Safe response: convert only the selected finding into a queue entry with `allowedFiles`, `validationCommands`, and `stopIf`, then stop. Audit output remains evidence only.

### Model Escalation Without New Evidence

Signal: switching models, sessions, or agents is used as the next action even though the evidence, failing command, and task packet are unchanged.

Safe response: preserve the latest ledger, fingerprint, and blocked reason. Escalate only with a new question or narrowed packet.

### Report Digestion Without Queue Conversion

Signal: external reports, DOCX files, or generated evidence are summarized repeatedly but never converted into bounded tasks.

Safe response: produce or request a compact digest with finding id, severity, affected artifact, bounded disposition, suggested local follow-up, unresolved assumptions, and non-authority notice. Do not execute the report.

### Idea Capture Without Prioritization

Signal: new feature ideas, UI concepts, mobile requests, or architecture paths are collected while the current task remains unfinished.

Safe response: put ideas in an explicit future queue or planning note only when allowed. Otherwise stop and ask for a new planning packet after the current task.

### Repeated Unstuck Without A New Packet

Signal: the run repeatedly asks how to proceed or sends another generic runner prompt while the same task remains blocked, ambiguous, or missing authority.

Safe response: require a new thin packet or human decision. The next prompt must include the selected task id, allowed files, validation command, blocked reason, and what changed since the last attempt.

## Ledger Use At Task Exit

Before final response, the run should be able to state:

- what the intended goal was
- what files were opened and edited
- what validation was run
- whether validation passed, failed, or was blocked
- what failure fingerprint, if any, remains
- what evidence proves progress
- what gap remains
- what the next safe action is

If any answer is missing, the run should not claim GREEN.

## Evidence-Only Boundary

The ledger and fingerprints do not approve work. They cannot authorize product-repo mutation, all-fleet execution, ship launch, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy access, lock deletion, permission widening, runtime hooks, or broader file edits. They only preserve evidence so the next bounded packet can be smaller and safer.
