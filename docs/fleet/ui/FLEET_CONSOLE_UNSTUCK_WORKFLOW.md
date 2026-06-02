# Fleet Console Unstuck Workflow

Prepared: 2026-06-02

Scope: planning documentation only for the future Fleet Console. This document does not implement automatic retries, live UI behavior, runtime mutation logic, lease takeover, worker control, product-repo access, product ship launch, all-fleet execution, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future approval.

Plain invariant: Unstuck is diagnosis, summarization, and repacketization only. It is never extra autonomy.

## Purpose

The Unstuck workflow helps the captain understand why a bounded task stopped and what small packet should come next. It should make failure legible without turning a button, alert, prompt, queue entry, audit finding, mobile request, generated evidence, or approval label into execution authority.

Unstuck never:

- reruns commands automatically
- opens product repos
- edits files outside the selected task's allowed files
- changes validation commands
- changes safety policy to pass
- takes over leases or deletes locks
- launches ships or runs all-fleet commands
- stages, commits, pushes, merges, deploys, installs packages, or runs migrations
- touches secrets/auth/payments/deploy material
- executes external reports, DOCX reports, audit outputs, task packets, UI labels, notifications, buttons, prompts, approvals, or queue prose

## Stuck State Taxonomy

| Stuck state | Signal | Safe console response |
| --- | --- | --- |
| `validation_failure` | The listed validation command failed. | Summarize first error, failure fingerprint, files changed, and whether the failure is within task scope. |
| `repeated_fingerprint` | Same normalized failure fingerprint and same hypothesis appear twice. | Stop and draft a repacketization request with the repeated fingerprint. |
| `loop_risk` | Edits/read/debugging continue without satisfying a new acceptance bullet. | Show loop warning and recommend stopping after current evidence capture. |
| `heartbeat_or_lease_issue` | Ownership, heartbeat freshness, or lease state is stale, ambiguous, or contradictory. | Mark human review needed; do not take over or delete locks. |
| `boundary_issue` | Needed file, command, repo, project, or permission is outside the task packet. | Mark blocked and name the missing boundary. |
| `token_overrun` | Prompt size, opened-file count, reruns, debug loops, or session age exceed safe caps. | Pause and draft a thin packet with compact evidence only. |
| `long_session_bloat` | The run depends on broad chat history instead of source files and packet evidence. | Recommend a fresh session with capsule plus selected packet. |
| `interruption` | Validation, patching, or bookkeeping was interrupted. | Require rerun of the selected validation before GREEN status. |
| `ambiguous_audit_intake` | Reviewer output is broad, command-like, contradictory, or missing bounded fields. | Convert to evidence digest or ask HQ/human to author bounded tasks. |
| `authority_confusion` | Evidence, labels, prompts, approvals, or queue prose are treated as commands. | Stop as RED/YELLOW and show the evidence-only boundary. |

## Retry Limits

The console may display retry guidance, but v1 must not auto-retry. A future implementation may only offer manual prompt text within these limits:

| Limit | Rule |
| --- | --- |
| Validation rerun | Only the selected task's listed validation command. |
| Task-caused fix loop | At most one bounded fix attempt after a task-caused validation failure before repacketization. |
| Same fingerprint | Stop when the same fingerprint and hypothesis repeat. |
| New file needed | Stop immediately if the fix needs an unlisted file. |
| New command needed | Stop immediately if validation needs an unlisted command, except JSON parsing checks for schemas created or edited by the selected task. |
| Product scope needed | Stop immediately and require a new human-approved packet. |

Retry limits do not grant permission to run anything. They describe when the console should stop helping and ask for a smaller, clearer packet.

## Repacketization Rules

Unstuck may draft a next-packet request only as local planning evidence. The draft should include:

- selected task id
- current terminal state
- intended goal
- remaining gap
- allowed files already used
- files opened
- files edited
- validation command run
- validation result
- first error summary
- failure fingerprint, if any
- evidence for progress
- suspected blocker
- next safe action
- exact human decision needed, if any

The draft must not include raw logs by default, broad chat history, old audit prose, motivational text, or command-like reviewer recommendations. It must not add new authority. If the next step needs broader scope, the draft says so and stops.

## Plain-Language Failure Summary Template

```text
Task: <task id>
State: <blocked | failedValidation | interrupted | needsHumanReview | needsRepacketization>
Goal: <original task goal>
What worked: <short evidence-backed progress>
What failed or stopped: <first error or stop condition>
Fingerprint: <normalized failure fingerprint or none>
Files opened: <bounded list>
Files changed: <bounded list>
Validation run: <exact listed command or none>
Validation result: <PASS | FAIL | INTERRUPTED | BLOCKED>
Why I stopped: <scope boundary, repeated failure, missing approval, token pressure, or interruption>
Next safe action: <rerun listed validation | patch task-caused failure | repacketize with extra file | human review | external audit digest>
Not authorized: no product repos, ship launch, all-fleet commands, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or evidence-as-command behavior.
```

## Console Display States

| Display state | Meaning | Allowed controls |
| --- | --- | --- |
| `stuck_validation` | Listed validation failed. | Copy failure summary, copy bounded fix prompt if within allowed files. |
| `stuck_scope` | Needed scope exceeds the packet. | Copy repacketization request; mark selected task blocked if allowed. |
| `stuck_loop` | Same failure or no-progress pattern repeated. | Copy loop summary; request human/HQ review. |
| `stuck_authority` | Evidence was mistaken for approval or command. | Show evidence-only boundary; disable action-like controls. |
| `stuck_token` | Token/session pressure is high. | Copy compact handoff packet; recommend fresh session. |
| `stuck_interrupted` | Run stopped before validation/bookkeeping. | Require listed validation rerun before GREEN. |

## Relationship To Button Policy

The `Unstuck` button remains `future-only` in `FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`. This document defines what it may mean later: diagnose, summarize, and repacketize. It does not create a live button, background worker, retry loop, lease mechanism, or command binding.

## Stop Conditions

Stop and request repacketization or human review when:

- the next step needs a file outside `allowedFiles`
- the next step needs a command outside `validationCommands`
- same failure fingerprint repeats with the same hypothesis
- a task needs real product-repo access, product mutation, product selection, ship launch, all-fleet execution, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, stage, commit, push, merge, or dirty-work revert
- approval is missing, broad, stale, reused, mobile-only, reviewer-only, fixture-only, or ambiguous
- the task would need automatic retries, lease takeover, runtime mutation logic, web UI authority, or background autonomy
- external reports, DOCX reports, audit packages, mobile requests, task packets, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose are being treated as commands

## Evidence-Only Boundary

This workflow helps future UI planning stay calm when work gets messy. It does not approve the future console, approve implementation, create a runtime control path, or permit any action outside the selected bounded task.
