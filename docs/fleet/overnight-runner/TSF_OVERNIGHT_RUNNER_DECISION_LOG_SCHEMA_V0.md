# TSF Overnight Runner Decision Log Schema V0

## Purpose

This schema defines the minimum information a TSF overnight-runner pilot log
must capture. It is a documentation schema, not an executable runner, scheduler,
daemon, watcher, service, proof run, all-fleet command, push path, or product
repo workflow.

## Run Header Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `runId` | yes | Stable id for the pilot run. |
| `date` | yes | Local date of the run. |
| `mode` | yes | Expected value for V0: `controlled_tsf_local_foreground_pilot`. |
| `repo` | yes | TSF repo path only. |
| `branch` | yes | Current branch at run start. |
| `head` | yes | Local `HEAD` at run start. |
| `originMain` | yes | Local `origin/main` at run start if available. |
| `aheadBehind` | yes | Local ahead/behind count against `origin/main` if available. |
| `worktreeStart` | yes | `clean` or a classified dirty state. |
| `approvalScope` | yes | Exact approval scope used for the run. |
| `restrictedGates` | yes | Gates that remain closed without exact approval. |

## Candidate Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `candidateId` | yes | Stable candidate id within the run. |
| `name` | yes | Human-readable candidate name. |
| `sourceFile` | yes | TSF-local source that produced the candidate. |
| `decision` | yes | Selected/skipped/deferred state. |
| `reason` | yes | Why the decision was made. |
| `riskClass` | yes | Risk classification. |
| `allowedScope` | yes | What the runner may do for this candidate. |
| `forbiddenScope` | yes | What the runner must not do for this candidate. |
| `artifactTarget` | yes | Concrete artifact target, or `none` for skipped candidates. |
| `validationExpected` | yes | Validation required before commit or closeout. |
| `stopConditionChecked` | yes | Stop condition that was checked. |
| `finalResult` | yes | Produced/deferred/skipped result. |

## Decision Values

- `SELECTED`
- `SKIPPED_CLOSED`
- `SKIPPED_PARKED`
- `SKIPPED_TIM_REQUIRED`
- `SKIPPED_UNSAFE`
- `DEFERRED`

## Risk Classes

- `TSF_LOCAL_GREEN`: safe TSF-local docs/control-plane work.
- `TSF_LOCAL_YELLOW`: safe but incomplete or needs explicit closeout notes.
- `TIM_REQUIRED`: blocked by a true authority gate.
- `RED_UNSAFE`: unsafe or out of scope for the active approval.

## Required Restricted-Gate Statement

Every run log must state that it does not approve:

- product repo access or mutation
- PrivateLens access or mutation
- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- external account changes
- spending
- credential/account changes
- persistent background, daemon, watcher, scheduled, service, cron, or Windows
  Task Scheduler work

## Example Candidate

```text
candidateId: OVR-001
name: Overnight Runner Harness Design
sourceFile: docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md
decision: SELECTED
reason: Builds the approved TSF-local harness artifact.
riskClass: TSF_LOCAL_GREEN
allowedScope: TSF docs/control-plane docs and generated run log.
forbiddenScope: Product repos, PrivateLens, push, deploy, installs, migrations,
  secrets, proof runs, all-fleet commands, external accounts, persistent
  background processes.
artifactTarget: docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_HARNESS_PILOT_V0.md
validationExpected: git diff --check on changed files; authority wording scan.
stopConditionChecked: No restricted gate required.
finalResult: Produced.
```

## Non-Authority Rule

The decision log is evidence. It can explain why a candidate was selected,
skipped, or deferred, but it cannot approve restricted work.
