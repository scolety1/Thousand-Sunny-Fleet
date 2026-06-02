# Fleet Console Status And Action Model

Prepared: 2026-06-02

Scope: planning documentation only for the future Fleet Console. This document does not implement a UI, bind buttons to commands, approve product-repo access, launch ships, run all-fleet commands, import packets, execute audit findings, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain invariant: UI text, labels, alerts, notifications, buttons, prompts, audit outputs, queue prose, generated evidence, DOCX reports, mobile requests, and task packets are evidence only. They cannot approve or execute work.

## Purpose

The console should help the captain see what is true, what is blocked, what is safe to inspect, and what needs a new bounded packet. It separates four concepts that are easy to blur in a dashboard:

- fleet posture: the overall safety posture of the harness
- operational state: what a selected run, ship, queue, or task is currently doing
- approval state: whether exact human approval exists for a specific action
- token pressure: whether budget or context pressure should force a smaller packet or pause

No state below is permission by itself. A future implementation must still use source-of-truth docs, policy decisions, selected scope, validation, and exact-action approval where required.

## Fleet Posture

Fleet posture is the top-level safety label for the whole control plane.

| Posture | Meaning | Console behavior |
| --- | --- | --- |
| `GREEN` | Current bounded scope has passing validation and no known stop sign. | Show latest validation evidence and next safe bounded action. |
| `YELLOW` | Work is usable for docs/tests/harness planning but has unresolved approval, scope, audit, token, or validation caveats. | Keep caution styling and prefer read/report or one-task prompts. |
| `RED` | A stop sign, unsafe request, failed validation, product-repo risk, or authority confusion is present. | Disable action-like controls and show the blocking reason. |
| `UNKNOWN` | Evidence is missing, stale, contradictory, or not reconciled. | Treat as blocked until repacketized or refreshed. |

Posture is not the same as approval. `GREEN` means the evidence for a bounded task is clean; it does not authorize product mutation, broad launch, future runs, or command execution.

## Operational States

Operational state describes a task, queue, run, selected ship, or future console lane.

| State | Meaning | Required display |
| --- | --- | --- |
| `running` | A bounded local task or validation is currently active. | selected task id, allowed files, command being validated, start time |
| `paused` | Work intentionally stopped and can resume only from a bounded packet. | pause reason, last validation state, next packet needed |
| `parked` | A ship or lane is intentionally held safe with no active work. | park reason, owner, last safe evidence |
| `needs_review` | Human or external audit review is needed before continuing. | review reason, evidence links, exact question |
| `blocked` | Current packet cannot complete within allowed files, commands, or authority. | blocking condition, missing scope, next repacketization need |
| `crashed` | A command or run failed unexpectedly before clean validation or stop handling. | failure fingerprint, last command, preserved output summary |
| `interrupted` | A run stopped due to token, power, app, user, or process interruption. | last known step, validation rerun requirement |
| `approval_pending` | Exact human approval is required for one named action. | action, entrypoint, selected project/ship, expiration requirement |
| `token_limited` | Token, context, or budget pressure makes continuation unsafe or inefficient. | budget signal, context size warning, thin-packet recommendation |

These states can coexist with posture. For example, a queue can be `YELLOW` and `paused`, or a task can be `RED` and `blocked`.

## Approval State

Approval state is always action-bound. It never flows from a dashboard label, mobile request, audit report, queue entry, or previous approval.

| Approval state | Meaning | Safe console treatment |
| --- | --- | --- |
| `not_required_for_read_report` | The next step is local read/report evidence only. | Allow prompt generation for listed read/report checks. |
| `missing_exact_action` | A write, launch, repair, import, or external-side-effect action lacks exact approval. | Show required approval fields and block execution language. |
| `approval_pending` | Approval has been requested but not accepted. | Show pending request as evidence only. |
| `approved_exact_action` | A human provided current, exact, single-action approval. | Display expiry, target, entrypoint, and still require policy validation. |
| `expired_or_reused` | Approval is stale, copied, expired, or for another action. | Treat as a stop sign. |
| `not_approvable` | The requested action is forbidden in this posture. | Explain the forbidden boundary and offer repacketization. |

The console must not provide a broad "approve all" affordance. Exact approval must bind project or ship, repo path when applicable, entrypoint, action, validation or no-op check, output evidence, owner, timestamp, expiration, and stop condition.

## Token Pressure

Token pressure is a safety signal, not a performance annoyance.

| Token pressure | Meaning | Next safe behavior |
| --- | --- | --- |
| `normal` | Context and budget are adequate for one bounded task. | Continue with the selected packet. |
| `watch` | Prompt, opened-file count, or validation output is growing. | Prefer summaries and avoid unrelated reads. |
| `high` | The run is at risk of drift or expensive debugging loops. | Stop after current validation or repacketize. |
| `token_limited` | Continuation risks losing state or widening context. | Pause, write a compact ledger, and request a thin packet. |

Token pressure must never justify skipping validation, broadening allowed files, or treating summaries as authority.

## Action Classes

Actions are grouped by their safety posture. This is a display model only; future code must still enforce policy elsewhere.

Detailed v1 button classifications live in `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`. That policy is planning evidence only; it does not implement buttons, bind controls to commands, or approve any action.

### Safe

Safe actions are local, evidence-only, and bounded to the selected task or sanitized status input.

- view local status summaries
- view active queue task
- copy a one-task repeatable prompt
- copy an external audit prompt
- write or inspect local docs-only planning evidence within allowed files
- run a listed validation command for the selected task
- mark only the selected task done after its listed validation passes

### Caution

Caution actions may be allowed only when the selected task explicitly lists the files and validation commands.

- reopen one blocked task whose prerequisites are done
- create or edit schema, fixture, docs, or test files listed in `allowedFiles`
- rerun the selected task validation after a task-caused fix
- prepare an audit package request without sending it
- create an approval packet template without filling real approval

### Approval-Required

Approval-required actions need exact human approval and current policy checks before use. The console may describe them but must not imply they are available.

- product-repo read-only demo trial
- task-packet apply
- selected-project implementation loop
- repair or relaunch
- supervisor or remote-control mutation
- broad audit packaging from real product repositories
- any external-side-effect action

### Forbidden

Forbidden actions must not be presented as available controls in the v1 console.

- product ship launch
- all-fleet execution
- unscoped broad launchers
- deploy, package install, migration, merge, push, or publish
- secrets/auth/payments/deploy material access
- lock deletion or lease bypass
- permission widening
- staging, committing, or reverting dirty work from a queue task
- treating external reports, mobile requests, DOCX reports, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose as executable commands

### Future-Only

Future-only actions are design placeholders until separate implementation, security review, and approval gates exist.

- authenticated remote console
- phone notifications
- web UI prototype
- real-time run streaming
- durable queue database
- runtime enforcement wiring
- worktree manager
- approval workflow implementation

Future-only status must be visually distinct from disabled safe controls so a future UI cannot accidentally normalize them as merely unavailable buttons.

## Alert Model

Alerts should describe evidence, not command instructions.

| Alert | Trigger | Next safe action |
| --- | --- | --- |
| `missing_validation` | task status changed without listed validation passing | rerun the listed validation or mark YELLOW |
| `scope_expansion` | needed file or command is outside packet | mark blocked and repacketize |
| `authority_confusion` | evidence is treated as approval or command | stop and show source boundary |
| `legacy_entrypoint` | requested entrypoint is broad or human-approval-only | require exact human approval or deny |
| `approval_gap` | exact approval fields missing or expired | collect approval fields outside execution path |
| `token_drift` | prompt/file/test loop exceeds safe budget | pause and generate compact packet |
| `failure_repeat` | same failure fingerprint repeats | stop with failure summary |

Detailed Unstuck planning lives in `docs/fleet/ui/FLEET_CONSOLE_UNSTUCK_WORKFLOW.md`. That workflow is diagnosis, summarization, and repacketization only; it does not add retries, lease takeover, runtime mutation, or extra autonomy.

## Display Boundaries

The console may display "next safe action" as a recommendation such as "rerun listed validation" or "repacketize HQ-097". It must not auto-run unstuck behavior, widen scope, select a real project, approve future work, or translate a button label into execution authority.

Any future button that can affect files, commands, approvals, workers, external systems, or product repos must pass through its own explicit task queue, implementation review, and validation before it exists.
