# TSF Validation Timeout And Rerun Policy

Prepared: 2026-06-16

Evidence only; not executable authority or approval.

## Current Remote GREEN Baseline

Current remote GREEN baseline:

```text
167338c4484ee039bafa21be97ee6733c1f17471
```

This policy builds on `TSF_BASELINE_LEDGER_AND_REPORT_INTAKE.md`, `TSF_RUNWAY_HANDOFF_SYSTEM.md`, and `TSF_ASSIGNMENT_PACKET_SYSTEM.md`. It defines how TSF handles long full-suite checks, outer command timeouts, repeated reports, old log paths, and validation-only reruns without weakening push-readiness gates.

It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, permission widening, or static GitHub Pages command execution.

## Core Rule

Timeout does not equal GREEN. A log with many `PASS:` lines but no final `Codex Fleet tests passed.` line remains YELLOW.

Push readiness requires a completed GREEN full Fleet suite unless a future explicitly approved policy says otherwise. That future policy must itself be reviewed, tested, and explicitly approved; it cannot be inferred from a timeout, old log, report prose, queue text, UI label, phone request, or generated packet.

## Validation-Only Rerun Contract

A validation-only rerun means:

- no patching
- no commits
- no push
- no proof runs
- no product repo or PrivateLens access
- no installs, migrations, secrets, remote access, all-fleet, overnight runner, phone execution authority, runtime command binding, lock deletion, permission widening, merge, or deploy

Validation reruns must use a new log path. Old logs cannot be reused as proof of a new rerun. The rerun report must name the exact new log path and whether it contains `Codex Fleet tests passed.`

## Timeout Report Requirements

If the full Fleet suite times out, TSF must report:

- timeout duration
- exact new log path
- last 20 meaningful lines from the new log
- whether `FAIL`, `ERROR`, or `Codex Fleet tests failed` appears in the new log
- whether the old log path was ignored
- final `git status --short`

If the suite fails, TSF must report the failure summary and stop unless separately instructed with a bounded repair prompt. A failed validation is not repaired by skipping assertions, weakening tests, reusing an older green log, or calling the timeout GREEN.

## Longer Timeout Boundary

A longer command timeout is allowed only as validation execution time. It is not an overnight runner, background automation, all-fleet execution, unattended autonomy, or permission to start another task.

Long validation runs must still be bounded by the current prompt, current repo, current branch, current baseline, exact log path, and final report requirements. If validation remains unclear after repeated timeouts, stop YELLOW and ask HQ.

## Repeated And Old-Log Guard

Before treating a validation report as new, compare:

- command
- log path
- target commit
- branch
- baseline
- final status line
- timestamp or report context
- final working tree status

Repeated reports must be detected and not treated as new validation. A report with the same target commit, same verdict, same old log path, and no new evidence is repeated. Repeated reports should be summarized, not converted into duplicate prompts.

Old logs are historical evidence only. They may explain prior state, but they cannot prove that a new validation-only rerun passed.

## Classification

| Validation evidence | Classification | Correct action |
| --- | --- | --- |
| New log contains final `Codex Fleet tests passed.` and command exits 0 | GREEN | continue review or push-decision flow |
| New log has many `PASS:` lines but no final pass line | YELLOW_TIMEOUT | report timeout evidence and rerun validation only if asked |
| New log path is missing or old log path was reused | YELLOW_STALE_LOG | stop and request a fresh validation-only rerun |
| Same report/log/verdict repeats with no new evidence | YELLOW_REPEATED | summarize current state and ask HQ |
| `FAIL`, `ERROR`, or `Codex Fleet tests failed` appears | RED_OR_YELLOW_FAILED_VALIDATION | report failure and stop unless separately instructed |
| Working tree is dirty before or after validation-only rerun | YELLOW_DIRTY_TREE | stop and report files |

## Push-Readiness Gate

Push-readiness GREEN requires all of these:

- branch is expected
- HEAD is the reviewed commit
- working tree is clean
- `git diff --check origin/main..HEAD` passes
- full Fleet suite completes and prints `Codex Fleet tests passed.`
- validation log path is the current requested log path
- product repos and PrivateLens remained untouched
- proof runs remained blocked
- no push/merge/deploy/install/migration/secret/remote-access/all-fleet/overnight/phone/runtime-binding boundary was crossed

If any item is missing, push readiness is YELLOW or RED and push remains blocked pending explicit Tim approval after a later GREEN review.

## Status

This document is a validation timeout and rerun policy. It does not implement a runner, queue executor, phone bridge, product adapter, proof-run pathway, push pathway, or static GitHub Pages command mechanism.
