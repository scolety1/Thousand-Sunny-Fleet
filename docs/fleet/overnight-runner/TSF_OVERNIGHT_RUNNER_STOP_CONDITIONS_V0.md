# TSF Overnight Runner Stop Conditions V0

## Purpose

This document gives the controlled TSF overnight-runner harness deterministic
stop rules. It helps Codex keep moving on safe TSF-local docs/control-plane work
while stopping before restricted gates.

This is not a grant of product repo access, PrivateLens access, push authority,
deployment authority, install authority, migration authority, secret access,
proof-run authority, all-fleet command authority, external-account authority, or
persistent background-runner authority.

## Continue Conditions

Codex may continue inside the active harness pilot when all of these are true:

- the repo is the Thousand Sunny Fleet repo
- the work is TSF-local docs/control-plane or generated runner-log work
- no product repo or PrivateLens access is needed
- no push, deploy, install, migration, secret/auth/payment, proof-run,
  all-fleet, external-account, spending, or credential/account action is needed
- no persistent background, daemon, watcher, scheduled, service, cron, or
  Windows Task Scheduler work is created
- the worktree is clean or dirty files are clearly classifiable TSF-local docs
- the candidate produces a concrete artifact
- validation can run with existing local tools

## Stop Matrix

| Condition | Decision | Required artifact | Final-report requirement |
| --- | --- | --- | --- |
| Product repo access or mutation is needed | `TIM_REQUIRED` | Exact product repo approval packet | Name repo/path, allowed scope, stop conditions, and expiry. |
| PrivateLens access or mutation is needed | `TIM_REQUIRED` | Exact PrivateLens approval packet | State no PrivateLens work happened. |
| Push is needed | `TIM_REQUIRED` | Push approval packet | State push was not performed. |
| Deploy/install/migration/secrets/auth/payments are needed | `TIM_REQUIRED` | Exact restricted-gate approval packet | State the restricted action was not performed. |
| Proof run or all-fleet command is needed | `TIM_REQUIRED` | Exact proof/all-fleet approval packet | State the command was not run. |
| External account, spending, or credential/account change is needed | `TIM_REQUIRED` | Exact account approval packet | State no account change occurred. |
| Persistent background, daemon, watcher, scheduled, service, cron, or Task Scheduler work is needed | `TIM_REQUIRED` | Runner approval packet | State no persistent process was created. |
| Validation fails | `STOP_AND_REPORT` | Failure report or repair work order | Include failing command and safest next action. |
| Dirty files are ambiguous | `STOP_AND_REPORT` | Dirty-work reconciliation | Do not overwrite, restore, stage, or commit ambiguous files. |
| Staging would include unintended files | `STOP_AND_REPORT` | Staging correction note | Do not commit. |
| Candidate is research-only with no artifact | `STOP_AND_REPORT` | Redirect to builder or closeout note | Do not create another blocker-only packet. |
| More than three local commits would be needed in this pilot | `STOP_AND_REPORT` | Batch closeout | Stop at the approved commit cap. |
| No useful safe builder remains | `CLOSE_PHASE` | Final run log | Say the phase is closed. |

## Good Stop Behavior

- Skip a product repo candidate and record `TIM_REQUIRED` instead of inspecting
  the repo.
- Skip a parked authority-boundary lane when no real ambiguity exists.
- Close a completed lane instead of re-proving it.
- Stop after validation failure and report the failing command.

## Overblocking To Avoid

- Asking Tim to choose between normal TSF-local docs/control-plane candidates.
- Treating a YELLOW review-only artifact as a Tim gate when it is safe and
  incomplete by design.
- Creating another blocker report when the next safe artifact can be built.
- Reopening closed lanes without a concrete defect.

## Final Rule

The harness should build safe local artifacts and logs until a true restricted
gate, unsafe ambiguity, validation failure, or no-work-remains condition appears.
It must never turn a run log, draft, queue item, or status file into approval for
restricted action.
