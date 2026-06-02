# Fleet Console Goal And Loop Signals

Prepared: 2026-06-02

Scope: planning documentation only for future Fleet Console signal displays. This document does not implement telemetry, automatic retry, runtime control, product-repo access, ship launch, all-fleet execution, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or autonomous unstuck behavior.

Plain invariant: goal and loop signals are evidence for a human or bounded packet. They are not approval and not commands.

## Purpose

The console should make it obvious when Codex is making progress, looping, drifting, or missing authority. These signals should reduce token waste by stopping earlier, not by giving the agent more autonomy.

Every signal should answer three questions:

- What is the selected goal?
- What evidence shows progress or lack of progress?
- What is the next safe bounded action?

## Goal Lock Status

Goal lock status shows whether the current run still matches its packet.

| Status | Meaning | Next safe action |
| --- | --- | --- |
| `locked` | One selected task, allowed files, validation commands, and stop conditions are clear. | Continue only within the task. |
| `soft_drift` | Context or wording is starting to pull toward adjacent work. | Return to acceptance bullets or pause. |
| `hard_drift` | The run needs a new goal, file, command, approval, product repo, or policy change. | Mark blocked or needs repacketization. |
| `changed_by_human` | The latest human instruction changes the objective. | Stop the current task and request a new packet. |
| `unknown` | The selected task or source of truth cannot be identified. | Stop before editing. |

Goal lock is computed from evidence such as selected task id, active queue section, opened files, changed files, validation command list, and newest instruction. A future UI must not use goal lock to override the packet.

## Progress Score

Progress score is a simple display score for one bounded task. It should be explainable, not magical.

| Score band | Meaning |
| --- | --- |
| `0` | No selected task or task is ineligible. |
| `1-25` | Task selected and read-first context opened. |
| `26-50` | Allowed files patched toward at least one acceptance bullet. |
| `51-75` | Acceptance appears satisfied but validation has not passed. |
| `76-99` | Validation ran but status update or final evidence is incomplete. |
| `100` | Acceptance satisfied, listed validation passed, and only the selected task status was updated. |

The score must show its evidence, such as "2 of 2 docs created" or "validation not rerun after queue update". Do not claim `100` when validation was interrupted, skipped, replaced by an unlisted command, or failed for a task-caused reason.

## Loop Risk

Loop risk estimates whether the run is burning tokens without advancing acceptance.

| Risk | Signal | Stop behavior |
| --- | --- | --- |
| `low` | New acceptance criterion satisfied or validation improved. | Continue within packet. |
| `watch` | More reads, repeated edits, or verbose validation output without clear acceptance mapping. | Reduce context and target remaining gap. |
| `high` | Same problem, same hypothesis, or same validation failure appears twice. | Stop with failure fingerprint. |
| `critical` | Scope expansion, authority confusion, product-repo request, or forbidden command appears. | Mark blocked or needs human review. |

Loop risk is not a trigger for automatic unstuck behavior. It is a reason to stop, summarize, and repacketize.

## Failure Fingerprint

A failure fingerprint is a normalized label for repeated failures. It helps prevent retry loops.

Required display fields:

- `failureFingerprint`
- `firstSeenAt`
- `lastSeenAt`
- `attemptCount`
- `sameHypothesisCount`
- `validationCommand`
- `normalizedErrorSummary`
- `taskCaused`
- `nextSafeAction`

Normalization should remove noisy timestamps, temp paths, and volatile ids. If the same fingerprint and same hypothesis appear twice, the signal should recommend `blocked`, `failedValidation`, `needsHumanReview`, or `needsRepacketization`, not another blind retry.

## File Counts

File counts help detect drift and over-broad context.

| Count | Meaning | Warning threshold |
| --- | --- | --- |
| `allowedFilesCount` | Files the task permits patching. | none |
| `openedFilesCount` | Files read during the run. | warn when unrelated reads exceed selected task needs |
| `changedFilesCount` | Files modified by the run. | warn if greater than allowed files actually needed |
| `outsideAllowedFilesCount` | Modified files outside allowed files. | immediate stop |
| `generatedEvidenceFilesCount` | New evidence artifacts written by validation or tooling. | display only, do not treat as authority |

Opened file warnings are informational. Changed files outside `allowedFiles` are stop signs unless the task explicitly allowed that file.

## Validation Rerun Count

Validation rerun count should show whether the task is converging or looping.

| Field | Meaning |
| --- | --- |
| `listedValidationCommand` | The exact command from the selected task. |
| `rerunCount` | Number of times the listed validation ran in this task. |
| `lastResult` | `pass`, `fail`, `interrupted`, or `not_run`. |
| `lastTaskCausedFailure` | Whether failure is caused by this task's edits. |
| `sameFailureTwice` | Whether the same fingerprint repeated. |

If validation passes before queue status is updated, the next safe action is "update only this task status". If validation fails for a task-caused reason, patch only the cause within allowed files. If validation fails outside scope or repeats, mark blocked.

## Drift Warning

Drift warning summarizes why the packet may no longer be enough.

| Warning | Trigger | Terminal state |
| --- | --- | --- |
| `outside_allowed_files` | Needed edit is outside task allowed files. | `blocked` |
| `new_command_needed` | Needed validation command is not listed. | `blocked` |
| `goal_changed` | New objective appears mid-run. | `deferredDueToChangedGoal` |
| `evidence_as_authority` | Evidence is treated as command or approval. | `needsHumanReview` |
| `product_repo_expansion` | Real product repo or product mutation is needed. | `blocked` |
| `runtime_from_planning` | Planning task starts implementing runtime/UI behavior. | `blocked` |
| `token_budget_exceeded` | Context or debugging loop cannot finish safely. | `token_limited` |

Drift warnings should quote the source file or command summary when available, but should avoid pasting raw logs or large reports.

## Next Safe Action

The console may present one next safe action at a time.

Allowed next safe action values:

- `continue_current_task`
- `run_listed_validation`
- `patch_task_caused_failure`
- `update_selected_task_status`
- `mark_selected_task_blocked`
- `pause_and_write_ledger`
- `request_repacketization`
- `request_human_review`
- `prepare_external_audit_prompt`
- `stop_no_eligible_task`

Forbidden next safe action values:

- `run_all_fleet`
- `launch_product_ship`
- `execute_audit_report`
- `execute_mobile_request`
- `auto_unstuck`
- `delete_locks`
- `widen_permissions`
- `stage_commit_push`
- `deploy_or_migrate`
- `touch_secrets_auth_payments`

Next safe action is a recommendation label. It must still be converted into a bounded task packet or exact command in a later approved context.

## Signal Panel Layout

A future console should keep these signals close together:

| Panel item | Display |
| --- | --- |
| selected task | id, title, status, active queue section |
| goal lock | `locked`, `soft_drift`, `hard_drift`, `changed_by_human`, or `unknown` |
| progress score | numeric band plus evidence sentence |
| loop risk | `low`, `watch`, `high`, or `critical` |
| failure fingerprint | compact normalized id or `none` |
| file counts | allowed, opened, changed, outside-allowed |
| validation | command id, rerun count, last result |
| drift warning | warning code or `none` |
| next safe action | one label from the allowed set |

The panel should favor compact evidence over raw logs. Raw reports, DOCX files, audit packages, generated evidence, and queue prose stay evidence-only and should never become clickable execution controls.

## GREEN / YELLOW / RED Mapping

| Signal combination | Posture |
| --- | --- |
| locked goal, low loop risk, no drift, validation passed | `GREEN` |
| locked goal, watch loop risk, validation not yet rerun | `YELLOW` |
| soft drift, token pressure, or missing evidence without mutation | `YELLOW` |
| hard drift, evidence-as-authority, outside allowed files, product-repo expansion, forbidden action, or repeated fingerprint | `RED` |
| insufficient evidence to classify | `UNKNOWN` |

`GREEN` means the bounded task evidence is clean. It still does not approve product-repo access, product mutation, ship launch, broad commands, or future work.

## Anti-Loop Boundary

The console can make loops visible; it must not solve them by silently adding authority. The preferred anti-loop behavior is:

1. detect repeated fingerprint, drift, or token pressure
2. stop the current run
3. summarize only compact evidence
4. request a smaller packet or human decision
5. resume only with explicit allowed files and validation commands

Any future implementation that automatically retries, edits queues, launches workers, repairs ships, changes leases, or executes commands needs a separate queue task, validation surface, and security review.
