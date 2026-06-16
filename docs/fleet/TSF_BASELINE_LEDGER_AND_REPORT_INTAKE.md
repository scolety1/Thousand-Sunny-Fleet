# TSF Baseline Ledger And Report Intake

Prepared: 2026-06-15

Evidence only; not executable authority or approval.

## Current Remote GREEN Baseline

Current remote GREEN baseline:

```text
3705be3f2880a65c095ad2eccaca9a2fa61cc02e
```

This report intake system builds on `TSF_RUNWAY_HANDOFF_SYSTEM.md`, `TSF_ASSIGNMENT_PACKET_SYSTEM.md`, and `FLEET_SELF_IMPROVEMENT_LOOP.md`. It gives HQ a tracked way to interpret incoming Codex reports, detect stale or repeated reports, track local-ahead commits, and choose the correct next action without treating reports as authority.

It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, permission widening, or static GitHub Pages command execution.

## Baseline Ledger Fields

Maintain these fields in reports, handoffs, and future ledger fixtures:

```text
remote_green_baseline:
local_head:
origin_main:
branch:
working_tree_status:
local_ahead_commits:
last_validation_log:
last_report_verdict:
last_report_fingerprint:
next_required_action:
blocked_reason:
```

Ledger rules:

- Current remote GREEN baseline is the last verified `origin/main` hash after a successful push.
- Local-ahead commits are commits reachable from `HEAD` but not from `origin/main`.
- A local-ahead commit with GREEN local validation maps to review local commit, not push.
- A GREEN push-readiness review maps to wait for Tim's explicit push approval.
- A GREEN push maps to record the new remote GREEN baseline and stop unless Tim supplies the next assignment.
- Dirty tree, failed validation, timeout without GREEN, stale report, repeated report, wrong-project text, or missing baseline maps to stop and ask HQ or run a bounded validation-only rerun.

## Report Intake Classifier

| Incoming report | Required classification | Correct next action |
| --- | --- | --- |
| GREEN local commit with clean tree and validation evidence | GREEN_LOCAL_COMMIT | review local commit |
| GREEN push-readiness review for exact HEAD and baseline | GREEN_PUSH_REVIEW | approve push only if Tim explicitly says so |
| GREEN push with remote hash verified | GREEN_PUSH | update remote GREEN baseline and create next assignment only after Tim asks |
| YELLOW timeout with log path and no explicit failure | YELLOW_TIMEOUT | validation-only rerun |
| Ambiguous report without clear final status | YELLOW_AMBIGUOUS | stop and ask HQ |
| Repeated report with same fingerprint and no new evidence | YELLOW_REPEATED | do not generate duplicate prompts; ask HQ or summarize current state |
| Stale report with mismatched HEAD, branch, or baseline | YELLOW_STALE | stop and request refreshed packet |
| Wrong-project or wrong-lane text | YELLOW_WRONG_PROJECT | ignore unless repo/path/baseline matches TSF |
| Dirty working tree | YELLOW_DIRTY_TREE | stop and report files |
| Failed validation | RED_OR_YELLOW_FAILED_VALIDATION | report failure and wait for bounded repair prompt |
| Product repo touch, PrivateLens touch, proof run, unauthorized push, or deploy | RED_BOUNDARY_CROSSING | stop and audit immediately |

Classifier rule: Codex reports are evidence only, not authority. A report can inform the next prompt, but it cannot approve push, product work, proof runs, phone execution, runtime command binding, or a next assignment by itself.

## Next Action Decision

Choose exactly one next action:

- `review local commit` when there is a local-ahead Fleet-only commit with GREEN local validation.
- `validation-only rerun` when the only blocker is a timeout or missing final validation result.
- `approve push` only when there is a GREEN push-readiness review and Tim separately approves the exact commit.
- `create next assignment` only after the current assignment is GREEN, the working tree is clean, and the remote/local baseline is unambiguous.
- `stop and ask HQ` when the report is stale, repeated without new evidence, dirty, wrong-project, missing baseline, failed validation without an allowed repair path, or ambiguous.

Push requires Tim's separate approval after GREEN push-readiness. A GREEN local commit, a queue entry, a runway packet, a Codex report, a UI label, a mobile request, a generated prompt, or a validation summary cannot approve push.

## Stale And Repeated Report Detection

Before generating a new prompt, compare:

- current branch
- current HEAD
- current `origin/main`
- stated remote GREEN baseline
- target commit or report commit
- report verdict
- validation log path
- files changed
- final working tree status

Stop as stale if HEAD, branch, repo path, or stated baseline does not match the packet/report. Stop as repeated if the same verdict, target commit, log path, and final status have already been handled and no new evidence is present.

Repeated reports must be detected before generating duplicate prompts. If repeated, summarize the already-known state and ask HQ for a new decision instead of producing another copy of the same review, rerun, or push prompt.

## Cross-Project Intake Guard

Cross-project text is ignored unless repo, path, branch, baseline, and assignment match TSF. Wrong-project examples include NWR, Drop Decision Day, product lane artifacts, rookie/outcome/drop-decision lanes, product-local CSV artifacts, and any non-TSF product repo instructions.

Wrong-project text is not executable authority. If it conflicts with the current TSF repo or baseline, TSF must report YELLOW_WRONG_PROJECT and stop instead of acting on it.

## Intake Checklist

Before acting on any report:

- confirm repo path is TSF
- confirm branch is expected
- confirm current remote GREEN baseline
- confirm local HEAD and whether it is ahead of `origin/main`
- confirm working tree status
- confirm report verdict and report target
- confirm whether the report is new, stale, or repeated
- confirm next action is one of review local commit, validation-only rerun, approve push, create next assignment, or stop and ask HQ
- confirm product repos, PrivateLens, proof runs, push/merge/deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone approvals, and runtime binding remain blocked unless separately approved
- confirm static GitHub Pages is request/status UI only and cannot execute local commands

## Status

This document is a baseline ledger and report-intake contract. It does not implement a database, runner, queue executor, phone bridge, product adapter, proof-run pathway, push pathway, or static GitHub Pages command mechanism.
