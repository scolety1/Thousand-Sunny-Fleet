# TSF Car-Ride Field Test Protocol

Prepared: 2026-06-17

Evidence only; not executable authority or approval.

## Baseline And Local Stack

Known official remote GREEN baseline at packet start:

```text
b03def2a72049cc904c42170fc7ffb7727f7edc8
```

Current local stack at setup time may include:

```text
aab2fc0a77a669aa57f4b7bcb8c8beb1e6fb88b8
```

The local-ahead push decision rubric commit was reviewed GREEN before this protocol was started. It remains local-ahead until Tim separately approves push. Tomorrow's reports must distinguish official remote baseline, local HEAD, and any local-ahead commits.

This protocol prepares a safe phone-monitored field test for TSF only. It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight or background runners, phone execution authority, runtime command binding, lock deletion, permission widening, or static GitHub Pages command execution.

## Field-Test Purpose

The car-ride field test checks whether TSF can be monitored from a phone under realistic travel conditions while preserving desktop safety gates.

The test should validate:

- report intake and GREEN/YELLOW/RED classification
- stale packet and stale report detection
- push-decision handling after GREEN review
- validation timeout and rerun handling
- compact phone-readable status reports
- idea intake as non-authoritative queue candidates
- safety stops for wrong-project text, ambiguous authority, or active-driving attention risk

The test collects improvement ideas without authorizing execution.

## Phone-Monitoring Rules

- Phone HQ is request/status/idea-intake only.
- Tim may paste Codex reports, ask HQ to classify GREEN/YELLOW/RED, and add ideas to a queue.
- Tim may not approve push, deploy, proof-run, runtime, remote-access, install, migration, all-fleet, overnight, or product actions from ambiguous phone UI labels or status text.
- Explicit phone text from Tim can request a prompt, request a review, or submit a queue candidate, but it does not broaden scope by itself.
- Static GitHub Pages remains a static request/status surface. It cannot execute local commands.
- Do not design prompts or protocols that require Tim to read, type, monitor, or approve while actively driving.
- Use passenger or rest-stop review only.

## Compact Phone Status Report

Codex should use this compact shape when a report is likely to be read on phone:

```text
Verdict: GREEN | YELLOW | RED
Repo/path/branch: <repo> | <path> | <branch>
Baseline/HEAD: remote=<hash>; local=<hash>; ahead=<none/list>
Files changed: <paths or none>
Checks run: <commands and result>
Boundaries preserved: product/PrivateLens/proof/push/deploy/install/migration/secret/remote/all-fleet/overnight/phone-runtime all blocked? <yes/no>
Blocker/next action: <review | validation-only rerun | approve-push decision | queue idea | stop>
Question for Tim: <exact question or none>
Driving safety: passenger/rest-stop review only; no active-driving attention required.
```

The report is evidence only. It cannot approve push, proof runs, product work, phone actions, runtime binding, remote access, deploys, installs, migrations, or all-fleet work.

## Mobile Idea Card

Ideas submitted from phone must use this compact card:

```text
Idea title:
Project/lane:
Problem it solves:
Desired outcome:
Risk/scope notes:
TSF-only or product-lane work:
Allowed next action: queue only / prompt draft / review-only / blocked pending desktop
```

Idea cards are non-authoritative queue candidates. They do not approve implementation, product repo access, proof runs, push, deploy, install, migration, secret work, remote access, all-fleet, overnight/background runners, phone execution authority, or runtime command binding.

If an idea is product-lane work, the default allowed next action is `blocked pending desktop` unless Tim later supplies an explicit bounded product-lane prompt in the correct repo and context.

## Stop Conditions

Stop YELLOW or RED if any request implies:

- product repo edits
- PrivateLens work
- proof run
- push, merge, or deploy
- install, migration, or secret handling
- remote access
- phone approval
- runtime command binding
- all-fleet
- overnight or background runner
- active-driving attention requirement
- static GitHub Pages executing local commands
- stale HEAD, baseline, repo, path, or branch
- wrong-project or wrong-lane mispaste
- repeated report with no new evidence

Do not repair these by guessing. Report the stop condition and ask HQ for the next bounded prompt.

## Tomorrow Test Scenarios

Use these as lightweight review drills. They are not approval to execute any blocked action.

| Scenario | Expected classification | Safe next action |
| --- | --- | --- |
| GREEN local commit report arrives | GREEN_LOCAL_COMMIT | Review local commit; do not push |
| GREEN push-readiness report arrives | GREEN_PUSH_REVIEW | Ask Tim whether to approve push for the exact commit |
| YELLOW timeout report arrives | YELLOW_TIMEOUT | Validation-only rerun with a new log path |
| Duplicate stale report arrives | YELLOW_REPEATED or YELLOW_STALE | Summarize known state; ask HQ |
| Wrong-project mispaste arrives | YELLOW_WRONG_PROJECT | Ignore wrong-lane content; stop |
| New product idea from phone | IDEA_PRODUCT_LANE | Queue only or blocked pending desktop |
| New TSF-only idea from phone | IDEA_TSF_ONLY | Queue candidate or prompt draft only |
| "What am I pushing?" from phone | PUSH_DECISION_HELP | Use push decision rubric; no push approval inferred |
| Next runway packet request from phone | RUNWAY_REQUEST | Draft bounded prompt only; preserve baseline and stop signs |

## Morning Readiness Checklist

Before tomorrow's field test:

- confirm current TSF repo path and branch
- confirm official remote GREEN baseline and local HEAD
- identify local-ahead commits separately from remote baseline
- confirm full Fleet tests passed for the latest local assignment before any local commit is treated GREEN
- confirm phone reports use the compact status shape
- confirm idea cards are queue candidates only
- confirm passenger/rest-stop review only
- confirm product repos, PrivateLens, proof runs, push, deploy, installs, migrations, secrets, remote access, all-fleet, overnight/background runners, phone execution authority, and runtime command binding remain blocked unless separately approved

## Status

This document is a phone-monitored field-test protocol and review aid. It does not implement a runner, queue executor, phone bridge, product adapter, proof-run pathway, push pathway, background process, remote-control surface, or static GitHub Pages command mechanism.
