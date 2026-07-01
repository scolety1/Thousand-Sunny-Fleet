# TSF Autonomy Prompt Library V1

Prepared: 2026-07-01

Evidence only; reusable prompt text only; not executable authority or approval.

## Purpose

TSF Autonomy Prompt Library V1 gives Tim, Codex, and TSF ChatGPT HQ compact
copyable prompts for recurring safe control-plane work under the published TSF
Autonomy Envelope.

The purpose is to reduce Tim babysitting by making the next safe prompt obvious
instead of forcing Tim to reconstruct scope, stop conditions, validation, and
reporting requirements each time.

This library does not run commands, start sessions, schedule work, push, deploy,
install packages, run migrations, access secrets, run proof runs, run all-fleet
commands, start background or overnight runners, touch product repos, mutate
PrivateLens, reactivate archived projects, change external accounts, spend
money, or grant future authority.

## When To Use

Use this library when the next TSF task is one of:

- autonomous intake
- lane queue execution
- local checkpoint packaging
- dirty-work reconciliation
- push-readiness review without push
- exact push after Tim approval
- restricted-gate approval packet drafting
- final report quality self-check
- close-phase review when no safe builder remains

Do not use this library for product repo work, PrivateLens work, proof runs,
all-fleet commands, background or overnight runners, deploys, installs,
migrations, secrets/auth/payments work, external account changes, spending, or
archived project reactivation unless Tim separately provides exact approval for
that restricted gate.

## Prompt Selection Guide

| Situation | Use Prompt |
| --- | --- |
| Tim is away and wants safe TSF-local progress. | Autonomous Lane Queue Execution |
| A TSF-local artifact is done and should be preserved. | Local Checkpoint Packaging |
| The worktree is dirty and scope is unclear. | Dirty Work Reconciliation |
| Local commits are ready for review but push is not approved. | Push-Readiness Without Push |
| Tim explicitly approves pushing exact commits. | Exact Push Approval |
| A restricted action is needed but not approved. | Restricted-Gate Approval Packet |
| Codex is about to send a final report. | Final Report Quality Self-Check |
| No useful safe builder remains. | Close-Phase Report |

## Prompt 1 - Autonomous Lane Queue Execution

Use when Codex should choose the next safe TSF-local docs/control-plane lane
from the queue.

```text
You are Codex working in Thousand Sunny Fleet under the published TSF
Autonomy Envelope.

Repo:
C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet

Task:
Run TSF Autonomous Lane Queue Execution.

Goal:
Use docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md and
docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md to choose exactly one highest-value
safe TSF-local docs/control-plane builder lane. Run it to safe local completion,
validate, and create a local commit if appropriate. Do not push.

Read first:
- docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md
- docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md
- docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md
- docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md
- fleet/status/current.md
- fleet/status/today.md

Allowed:
- inspect TSF-local docs/status/control-plane files
- choose one READY lane from the queue
- create or update TSF-local docs/control-plane artifacts
- run safe local validations
- create one local commit when validation passes and staged files are exact

Not allowed without exact Tim approval:
- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- background/overnight runners
- product repo or PrivateLens access/mutation
- archived project reactivation
- external account changes
- spending
- credential/account changes
- history rewrite or remote release changes

Validation:
- git status --short
- git branch --show-current
- git rev-parse HEAD
- git rev-parse --verify origin/main if available
- git rev-list --left-right --count origin/main...HEAD if available
- git diff --check on changed files
- authority wording scan on changed control-plane docs
- staged-file exactness check before any commit

Stop if:
- a restricted gate appears without exact Tim approval
- product repo or PrivateLens access is required
- validation requires forbidden operations
- staging would include unintended files
- the lane becomes research-only with no concrete artifact

Final report:
- verdict
- lane selected and why
- real finish line
- artifacts changed
- commit hash if created
- validations run
- branch, HEAD, ahead/behind, git status
- exclusions
- remaining Tim gates
- push posture
- restricted-boundary confirmation
```

## Prompt 2 - Local Checkpoint Packaging

Use when a safe TSF-local artifact exists and should be committed without
dragging in unrelated files.

```text
You are Codex working in Thousand Sunny Fleet.

Task:
Create a local checkpoint for the named TSF-local docs/control-plane artifact.

Inputs:
- artifact path(s):
- expected commit message:
- explicitly excluded files:

Allowed:
- inspect status and diffs for the named artifact paths
- run safe local validation
- stage only the named artifact paths
- create one local commit if validation passes

Out of scope:
- push
- deploy
- installs/migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- background/overnight runners
- product repo or PrivateLens access/mutation
- archived project reactivation
- unrelated file edits

Validation:
- confirm all included files exist
- git diff --check on included files
- authority wording scan for policy/control-plane docs
- git status --short
- git diff --cached --name-only must equal the included file list

Stop if:
- any included file is missing
- staging would include excluded or unrelated files
- validation fails
- a restricted gate is required

Final report:
- verdict
- commit hash and message if created
- files included
- files excluded
- validations run
- final git status
- no push performed
- restricted-boundary confirmation
```

## Prompt 3 - Dirty Work Reconciliation

Use when the TSF repo is dirty and Codex needs to classify files before
continuing.

```text
You are Codex working in Thousand Sunny Fleet.

Task:
Run a TSF dirty-work reconciliation.

Goal:
Classify the dirty files from local diffs only. Decide whether they form a
coherent TSF-local checkpoint batch, separate workstreams, generated noise, or
ambiguous work that should stop.

Allowed:
- inspect git status and local diffs
- read TSF-local docs/control-plane files needed for classification
- create one reconciliation artifact if useful

Out of scope:
- product repos
- PrivateLens
- restoring, deleting, staging, or committing dirty files unless a later exact
  checkpoint prompt approves that scope
- push/deploy/install/migration/secrets/proof/all-fleet/background actions

For each dirty file, report:
- path
- status
- summary of change
- classification
- include/exclude recommendation
- risks if included
- risks if excluded
- recommended next action

Validation:
- git status --short
- git diff --stat
- git diff --check on dirty files when safe

Stop if:
- product repo or PrivateLens access is needed
- dirty files cannot be classified from local diffs
- any command would overwrite or discard work

Final report:
- verdict
- classification summary
- recommended checkpoint grouping
- files changed by reconciliation, if any
- validations run
- final git status
- no push performed
```

## Prompt 4 - Push-Readiness Without Push

Use when local commits exist and Tim has not approved push.

```text
You are Codex working in Thousand Sunny Fleet.

Task:
Prepare push-readiness report only. Do not push.

Allowed:
- inspect git status, branch, HEAD, origin/main, ahead/behind, log, and diff
- run safe local diff checks
- run known safe TSF-local validation if needed and explicitly in scope

Out of scope:
- push
- force push
- merge/rebase/amend/squash
- deploy/install/migration/secrets/proof/all-fleet/background actions
- product repo or PrivateLens access/mutation

Checks:
- git status --short
- git branch --show-current
- git rev-parse HEAD
- git rev-parse --verify origin/main
- git rev-list --left-right --count origin/main...HEAD
- git diff --check origin/main..HEAD
- git log --oneline -10

Final report:
- verdict
- local commits included
- branch
- local HEAD
- origin/main baseline
- ahead/behind
- checks and results
- push recommendation
- exact statement that push was not performed
- exact statement that Tim approval is required before push
```

## Prompt 5 - Exact Push Approval

Use only after Tim explicitly approves pushing exact commit(s) to `origin/main`.

```text
You are Codex working in Thousand Sunny Fleet.

Tim explicitly approves pushing the named commit(s) to origin/main.

Task:
Push current clean local main to origin/main only if all checks match.

Approved commits:
- [exact commit hash] - [message]

Expected local HEAD:
[exact commit hash]

Expected origin/main before push:
[exact commit hash]

Allowed:
- confirm current branch is main
- confirm worktree is clean
- confirm local HEAD matches expected
- confirm origin/main matches expected
- confirm ahead/behind is exactly the approved count ahead and 0 behind
- run git diff --check origin/main..HEAD
- push main to origin/main if all checks pass

Out of scope:
- amend, squash, rebase, merge, or create commits
- force push
- push any branch except main
- deploy/install/migration/secrets/proof/all-fleet/background actions
- product repo or PrivateLens access/mutation
- external account changes

Stop if:
- branch is not main
- worktree is dirty
- HEAD does not match
- origin/main does not match
- ahead/behind does not match
- diff check fails
- push would require force, merge, rebase, or conflict resolution

Final report:
- verdict
- push result
- remote baseline before push
- final remote HEAD after push
- branch pushed
- commits published
- checks run
- final git status
- restricted-boundary confirmation
```

## Prompt 6 - Restricted-Gate Approval Packet

Use when a true restricted gate is needed and not approved.

```text
You are Codex working in Thousand Sunny Fleet.

Task:
Create one consolidated restricted-gate approval packet.

Goal:
Explain the exact restricted action needed, what artifact it would unblock, and
why Codex stopped before execution.

Do not execute the restricted action.

Packet must include:
- requested action
- repo/path
- branch
- allowed command(s)
- max scope
- unblock artifact
- why this cannot be done under current authority
- risks
- stop conditions
- expiration condition
- exact approval template for Tim

Exact approval template:
TIM_EXACT_APPROVAL:
action:
repo/path:
branch:
allowed command(s):
max scope:
stop conditions:
expires after:

Final report:
- verdict: TIM_REQUIRED
- gate requested
- artifact blocked
- no restricted action performed
- final git status
```

## Prompt 7 - Final Report Quality Self-Check

Use before sending a final response after TSF-local work.

```text
Before final response, check docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md.

Confirm the final report includes:
- verdict
- work selected and why
- real finish line
- concrete unblock artifact
- files changed
- commit hash and message if a commit was created
- validation commands and results
- current branch
- current HEAD
- origin/main baseline if available
- ahead/behind if available
- final git status --short
- intentional exclusions
- true Tim gates remaining
- push posture
- restricted-boundary confirmation

If any required field is missing, fix the final report before sending it.
If validation failed or a restricted gate was crossed without exact approval,
classify RED instead of GREEN.
```

## Prompt 8 - Close-Phase Report

Use when no useful safe builder remains.

```text
You are Codex working in Thousand Sunny Fleet.

Task:
Close the current TSF-local control-plane phase.

Goal:
Report that no useful safe builder remains, list completed artifacts, identify
anything intentionally parked, and name any true Tim gates.

Allowed:
- inspect TSF-local docs/status/git metadata
- run safe local status/diff checks
- create a closeout artifact only if it materially improves future return state

Out of scope:
- inventing new work
- product repo or PrivateLens work
- push/deploy/install/migration/secrets/proof/all-fleet/background actions

Final report:
- verdict
- completed artifacts
- no-builder rationale
- parked items
- Tim gates, if any
- checks run
- final git status
- no push performed
```

## Maintenance Rules

Update this library only when:

- a recurring TSF prompt is being copy/pasted by Tim
- a prompt causes avoidable babysitting
- a prompt misses a true restricted gate
- a prompt overblocks safe TSF-local work
- the lane queue adds or closes a prompt-producing lane

Do not add product-repo prompts, proof-run prompts, overnight/background
prompts, install/deploy prompts, or external-account prompts unless Tim gives
exact scope for a TSF-local planning artifact only.

## Final Note

These prompts are reusable text, not approval. Codex must still inspect current
repo state, validate scope, run safe checks, stage exact files, and stop before
restricted gates unless Tim gives exact approval.
