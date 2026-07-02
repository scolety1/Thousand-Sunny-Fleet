# TSF Overnight Runner Decision Log Template V0.1

## Purpose

This template gives future TSF overnight-runner sessions a reusable,
machine-readable decision-log/checklist shape. It makes runner sessions easier
to audit, tune, compare, and safely expand while preserving the TSF autonomy
envelope.

This template is TSF-local control-plane documentation. It does not start a
runner, schedule work, inspect product repos, mutate PrivateLens, push, deploy,
install packages, run migrations, touch secrets, run proof runs, run all-fleet
commands, change external accounts, spend money, or create persistent
background/overnight/daemon/watcher/scheduled processes.

## When To Use This Template

Use this template when Codex runs a bounded TSF-local runner-style session and
needs to record:

- which candidate lanes were considered
- why each candidate was selected, skipped, deferred, blocked, or marked
  `TIM_REQUIRED`
- which artifacts were produced or intentionally not produced
- which stop conditions and authority gates were checked
- which validations ran before local commit or closeout
- what tuning signal should feed the next runner version

Do not use this template to authorize restricted work. Generated logs,
checklists, queue items, status files, or examples are evidence only.

## Required Run Metadata

Every runner log must include:

| Field | Required | Notes |
| --- | --- | --- |
| `runId` | yes | Stable run id, for example `overnight-runner-v0-1-YYYY-MM-DD`. |
| `date` | yes | Local date of the run. |
| `repo` | yes | TSF repo path only unless Tim gives exact future approval for another repo. |
| `branch` | yes | Current branch at run start. |
| `startHead` | yes | Local `HEAD` at run start. |
| `originMainBaseline` | yes | Local `origin/main` baseline at run start if available. |
| `aheadBehind` | yes | Local ahead/behind against `origin/main` if available. |
| `runnerMode` | yes | Example: `controlled_tsf_local_foreground_pilot`. |
| `approvedScope` | yes | Exact scope approved for this run. |
| `forbiddenScope` | yes | Restricted actions and repos excluded from this run. |
| `worktreeStart` | yes | `clean`, or a classified TSF-local dirty state. |

## Required Candidate Decision Fields

Every candidate entry must include:

| Field | Required | Notes |
| --- | --- | --- |
| `candidateId` | yes | Stable id within the run. |
| `candidateName` | yes | Human-readable lane or project-card name. |
| `sourceArtifact` | yes | TSF-local source file or status packet that produced the candidate. |
| `decision` | yes | `SELECTED`, `SKIPPED`, `DEFERRED`, `BLOCKED`, or `TIM_REQUIRED`. |
| `decisionSubtype` | no | Examples: `SKIPPED_CLOSED`, `SKIPPED_PARKED`, `BLOCKED_UNSAFE`. |
| `reason` | yes | Short explanation grounded in source evidence. |
| `allowedScope` | yes | What Codex may do for this candidate. |
| `forbiddenScope` | yes | What Codex must not do for this candidate. |
| `artifactTarget` | yes | Concrete artifact target, or `none` for skipped/deferred entries. |
| `validationExpected` | yes | Checks required before commit or closeout. |
| `stopConditionChecked` | yes | Stop condition or gate checked for this candidate. |
| `result` | yes | Produced, skipped, deferred, stopped, or Tim-required result. |
| `tuningSignal` | yes | What this decision teaches the next runner version. |

## Stop-Condition Checklist

Before selecting any candidate, mark each item `CLEAR`, `TRIGGERED`, or
`NOT_APPLICABLE`:

- product repo access or mutation required
- PrivateLens access or mutation required
- push required
- deploy/install/migration/secrets/auth/payments required
- proof run or all-fleet command required
- external account, spending, or credential/account change required
- persistent background, daemon, watcher, scheduled, service, cron, or Windows
  Task Scheduler work required
- archived project reactivation required
- dirty worktree ambiguity
- validation failure
- staging would include unintended files
- candidate is research-only with no concrete artifact
- more local commits than the active approval permits
- no useful safe builder remains

If any restricted item is `TRIGGERED` without exact Tim approval, stop and
produce one consolidated approval packet.

## Authority-Gate Checklist

A runner log must explicitly confirm:

- TSF-local docs/control-plane scope only, unless exact future approval says
  otherwise
- generated logs and templates are evidence only, not authority
- product-repo pilots remain `TIM_REQUIRED` unless Tim names repo/path, branch,
  allowed commands, max scope, stop conditions, and expiry
- PrivateLens remains `TIM_REQUIRED` unless exact PrivateLens scope is approved
- push remains `TIM_REQUIRED` unless Tim approves the exact commit/branch push
- persistent background/overnight runners remain `TIM_REQUIRED` unless exact
  runner scope is approved
- deploy, installs, migrations, secrets/auth/payments, proof runs, all-fleet
  commands, external accounts, spending, and credential/account changes remain
  closed without exact approval

## Validation Checklist

Minimum validations:

- `git status --short`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git rev-parse --verify origin/main` if locally available
- `git rev-list --left-right --count origin/main...HEAD` if locally available
- `git diff --check` on changed files
- parse structured JSON logs/templates if any were created
- authority wording scan on changed docs/control-plane files
- confirm staged files are exact before local commit
- run the full TSF suite only when known safe and not proof-run/all-fleet scoped

## Final Report Checklist

The final report must include:

- verdict: `GREEN`, `YELLOW`, `RED`, or `TIM_REQUIRED`
- lane selected and why
- real finish line
- artifacts created or updated
- candidates selected/skipped/deferred/blocked/TIM_REQUIRED and why
- validations run and results
- local commits created, if any
- current branch and `HEAD`
- local `origin/main` baseline and ahead/behind
- final `git status --short`
- tuning signals discovered
- recommended next runner phase
- whether a real read-only product-repo pilot is recommended yet
- true Tim gates remaining
- push posture
- explicit confirmation that no push occurred unless exactly approved
- explicit confirmation that no restricted action occurred

## Example Entries

### Selected Safe TSF-Local Docs Lane

```text
candidateId: OVR-101
candidateName: Decision Log Template V0.1
sourceArtifact: docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_HARNESS_PILOT_V0.md
decision: SELECTED
reason: V0 recommended a machine-readable decision-log/checklist layer.
allowedScope: TSF-local docs/control-plane template and JSON skeleton.
forbiddenScope: Product repos, PrivateLens, push, deploy, installs, migrations,
  secrets, proof runs, all-fleet commands, external accounts, persistent
  background runners.
artifactTarget: docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_DECISION_LOG_TEMPLATE_V0_1.md
validationExpected: diff check, JSON parse, authority wording scan, TSF suite if safe.
stopConditionChecked: no restricted gate required.
result: produced.
tuningSignal: future runs can compare candidate decisions using stable fields.
```

### Skipped Already-Closed Lane

```text
candidateId: OVR-102
candidateName: Control Plane Overview Refresh
sourceArtifact: docs/fleet/TSF_CONTROL_PLANE_OVERVIEW_V1.md
decision: SKIPPED
decisionSubtype: SKIPPED_CLOSED
reason: Overview is current and no defect was found.
allowedScope: Read as evidence.
forbiddenScope: Reopen completed lane without a concrete defect.
artifactTarget: none.
validationExpected: none.
stopConditionChecked: closed lane should not be re-proved.
result: skipped.
tuningSignal: closed lanes should remain closed until evidence changes.
```

### Deferred Ambiguous Lane

```text
candidateId: OVR-103
candidateName: Authority Boundary Scan
sourceArtifact: docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md
decision: DEFERRED
decisionSubtype: PARKED_NO_TRIGGER
reason: No current evidence/authority ambiguity appeared.
allowedScope: Record defer reason.
forbiddenScope: Create policy churn without a real ambiguity.
artifactTarget: none.
validationExpected: none.
stopConditionChecked: no concrete trigger.
result: deferred.
tuningSignal: parked lanes need a trigger, not curiosity.
```

### TIM_REQUIRED Product-Repo Pilot

```text
candidateId: OVR-104
candidateName: Read-Only Product Repo Pilot
sourceArtifact: fleet/status/draft-queue/lane-7-product-access-approval.md
decision: TIM_REQUIRED
reason: Product repo access requires exact Tim approval.
allowedScope: Produce an approval packet only.
forbiddenScope: Inspecting, testing, editing, staging, committing, or mutating
  any product repo.
artifactTarget: approval packet only.
validationExpected: authority wording scan.
stopConditionChecked: product repo access gate.
result: stopped before product repo access.
tuningSignal: product pilots need exact repo/path/scope approval before any read.
```

### BLOCKED_UNSAFE Persistent Background Runner

```text
candidateId: OVR-105
candidateName: Persistent Overnight Daemon
sourceArtifact: user request or generated queue item
decision: BLOCKED
decisionSubtype: BLOCKED_UNSAFE
reason: Persistent background runners are outside scope without exact approval.
allowedScope: Explain stop and produce approval packet if useful.
forbiddenScope: Creating services, watchers, schedulers, cron jobs, Task
  Scheduler entries, or unattended daemons.
artifactTarget: stop report or approval packet.
validationExpected: none until exact approval exists.
stopConditionChecked: persistent runner gate.
result: blocked unsafe.
tuningSignal: runner docs must distinguish foreground pilots from persistent automation.
```

## How This Feeds Future Tuning

Future runner dry runs can compare candidate entries across sessions and score:

- verdict correctness
- true Tim-gate detection
- overblocking versus unsafe underblocking
- artifact concreteness
- stop-condition accuracy
- validation completeness
- whether product-repo pilots stayed `TIM_REQUIRED`
- whether persistent runner requests stayed stopped without exact approval

If repeated failures appear, patch the harness prompt, stop-condition reference,
or this template. Do not expand runtime authority through a template change.

## Final Note

This template is audit scaffolding. It helps TSF prepare safer future runner
sessions, but it does not authorize product-repo pilots, PrivateLens access,
push, deploy, installs, migrations, secrets, proof runs, all-fleet commands,
external accounts, spending, credential changes, archived reactivation, or
persistent background/overnight runners.
