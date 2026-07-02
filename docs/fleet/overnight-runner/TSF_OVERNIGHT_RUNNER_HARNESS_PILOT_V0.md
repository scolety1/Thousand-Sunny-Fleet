# TSF Overnight Runner Harness Pilot V0

## Purpose

This pilot defines the first controlled TSF overnight-runner harness. It tests
runner mechanics inside the Thousand Sunny Fleet repo only: lane selection,
decision logging, progress monitoring, stop conditions, artifact creation,
validation, local checkpointing, and final reporting.

This is not a product-repo runner, all-project system, external daemon, OS
scheduled task, deploy flow, proof run, push path, or account automation tool.

## Pilot Approval Scope

Tim approved only this controlled TSF-local harness pilot. The approval covers
foreground Codex work inside the TSF repo over docs/control-plane files and
generated runner logs.

All other restricted gates remain closed unless Tim gives exact future approval:

- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- product repo access or mutation
- PrivateLens access or mutation
- external account changes
- spending
- credential/account changes
- persistent background, daemon, watcher, scheduled, service, cron, or Windows
  Task Scheduler work

## What The Harness Tests

- loading TSF control-plane source documents before choosing work
- deriving candidate lane cards from TSF-local docs/status only
- selecting or skipping each candidate with a clear reason
- recording risk class, allowed scope, forbidden scope, artifact target,
  expected validation, stop-condition result, and final result
- producing bounded TSF-local artifacts
- validating changed files before any local commit
- stopping before push or any restricted gate

## Inputs

Read these before each harness run:

- `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`
- `docs/fleet/TSF_CONTROL_PLANE_OVERVIEW_V1.md`
- `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md`
- `docs/fleet/TSF_AUTONOMY_PROMPT_LIBRARY_V1.md`
- `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md`
- `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md`
- `docs/fleet/TSF_FINAL_GATE_CLOSURE_BOARD_V1.md`
- `fleet/status/current.md`
- `fleet/status/today.md`

## Candidate Card Model

Each candidate must record:

- candidate id
- candidate name
- source file
- selected or skipped
- reason
- risk class
- allowed scope
- forbidden scope
- artifact target
- validation expected
- stop condition checked
- final result

Use `docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_DECISION_LOG_SCHEMA_V0.md`
for the reusable field definitions.

## Pilot Algorithm

1. Confirm branch, local `HEAD`, local `origin/main`, ahead/behind, and
   `git status --short`.
2. Stop if the repo starts dirty unless the dirty files are TSF-local
   docs/control-plane files that can be safely reconciled.
3. Read the required TSF control-plane source documents.
4. Build 2 to 4 candidate cards from TSF-local docs/status only.
5. Reject product repo, PrivateLens, proof-run, all-fleet, deploy, install,
   migration, secret, external-account, push, and persistent-runner candidates.
6. Select only candidates that produce a concrete TSF-local artifact.
7. Prefer a closed/parked/TIM_REQUIRED skip over reopening completed lanes.
8. Create bounded docs/control-plane artifacts and generated runner logs only.
9. Run safe local validations on changed files.
10. Create a local commit only when scope is clean, staged files are exact,
    validation passes, and no restricted gate is involved.
11. Stop before push.

## V0 Pilot Candidate Set

| Candidate | Source | Decision | Reason | Artifact |
| --- | --- | --- | --- | --- |
| Overnight Runner Harness Design | User pilot prompt plus autonomy docs | `SELECTED` | It directly tests the approved TSF-local harness mechanics. | Harness docs, schema, stop conditions, and run log |
| Control Plane Overview Follow-up | `docs/fleet/TSF_CONTROL_PLANE_OVERVIEW_V1.md` | `SKIPPED_CLOSED` | The overview lane is already complete and current. | None |
| Authority Boundary Scan Checklist | `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` | `SKIPPED_PARKED` | No current evidence/authority ambiguity triggered the lane. | None |
| Product Repo Onboarding Mock Packet | `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` | `SKIPPED_TIM_REQUIRED` | Real product access is not approved; mock-only work was not the best v0 harness test. | None |

## Progress Monitoring

Progress monitoring in V0 means writing checkpoints into a TSF-local run log. It
does not mean starting a watcher, daemon, scheduled task, service, recurring
automation, remote monitor, or persistent overnight process.

Each run log should record:

- repo gate checked
- source docs loaded
- candidate cards built
- candidate selected/skipped
- artifacts produced/deferred
- validations run
- local commit decision
- final stop reason

## Stop Conditions

Use `docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_STOP_CONDITIONS_V0.md`
as the reusable stop-condition reference. The harness stops immediately if any
restricted gate appears without exact Tim approval, if validation fails, if the
worktree becomes ambiguous, if staging would include unintended files, or if the
candidate becomes research-only with no concrete artifact.

## Validation Expectations

Minimum validation for this pilot:

- `git status --short`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git rev-parse --verify origin/main` if locally available
- `git rev-list --left-right --count origin/main...HEAD` if locally available
- `git diff --check` on changed files
- authority wording scan on changed runner docs
- staged-file exactness check before commit
- full TSF suite only when already known safe and not proof-run/all-fleet scoped

## Final Report Template

The final report must include:

- verdict
- whether the harness pilot succeeded
- runner artifacts created/updated
- candidates considered
- candidates selected/skipped and why
- local commits created
- validations run and results
- current branch, `HEAD`, remote baseline, and ahead/behind
- current `git status --short`
- tuning signals discovered
- recommended next runner version
- whether a real read-only product-repo pilot is recommended
- true Tim gates remaining
- whether push is recommended
- confirmation that no push or restricted action occurred

## V0 Result

V0 is done enough when the harness design, decision-log schema, stop-condition
reference, and one dated run log exist; the run log covers 2 to 4 TSF-local
candidate cards; validations pass; and any local commit contains only the
intended TSF-local runner artifacts.

## Next Version

Recommended V0.1: add a machine-readable decision-log artifact or a lightweight
TSF-local checklist that can be filled by hand during future bounded runs.

A real read-only product-repo pilot is not recommended until Tim gives exact
product repo approval naming the repo, path, branch, allowed read-only commands,
stop conditions, and expiry.

## Final Note

The overnight-runner harness is control-plane evidence. It does not approve
future overnight/background execution, product repo access, PrivateLens access,
push, deploy, installs, migrations, secrets, proof runs, all-fleet commands, or
external account work.
