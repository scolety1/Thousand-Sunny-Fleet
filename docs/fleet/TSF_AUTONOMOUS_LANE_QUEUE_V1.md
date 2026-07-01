# TSF Autonomous Lane Queue V1

Prepared: 2026-07-01

Evidence only; not executable authority or approval.

## Purpose

TSF Autonomous Lane Queue V1 gives Codex a repo-local queue of safe
control-plane builder lanes that can run under the published autonomy envelope
without asking Tim to choose ordinary strategy.

The queue is meant to reduce babysitting by answering:

- what safe TSF-local builder should run next
- what concrete artifact should unblock the next step
- what is done enough
- what should be excluded for now
- what validation is expected before a local checkpoint

This queue is not a runner, scheduler, daemon, overnight process, remote
workflow, product-repo plan, release plan, or blanket approval source.

## Authority Boundary

Codex can use this queue as routing evidence for safe TSF-local
docs/control-plane work only. A queued lane is eligible only when it stays
inside the TSF repo, uses local docs/status evidence, avoids restricted gates,
and can be validated with safe local checks.

Restricted gates still need exact Tim approval before execution:

- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- background, overnight, daemon, watcher, scheduled, or unattended runners
- product repo access or mutation
- PrivateLens access or mutation
- archived project reactivation
- external account changes
- spending
- credential/account changes
- history rewrite or remote release changes

If a lane needs any restricted gate, Codex must stop and produce one
consolidated approval packet instead of continuing.

## Selection Rules

When starting an autonomous TSF control-plane session:

1. Confirm branch, HEAD, local `origin/main`, ahead/behind, and
   `git status --short`.
2. If the repo is dirty, run one dirty-work reconciliation before new work.
3. Read `TSF_AUTONOMY_ENVELOPE_V1.md`, `TSF_HQ_ADAPTER_MODE.md`, and current
   fleet status.
4. Pick exactly one `READY` lane from this queue unless the current user prompt
   already names a safe lane.
5. Prefer lanes that create reusable validation, queue, checklist, prompt, or
   status-index artifacts.
6. Do not choose a lane whose output is only another blocker report.
7. Commit a lane only when validation passes and staged files are exact.
8. Stop when no useful safe builder remains or a true restricted gate appears.

## Lane Status Legend

- `READY`: safe to select if repo evidence still matches.
- `READY_AFTER_PREVIOUS`: useful only after another named lane is complete.
- `PARKED`: not needed until a new incident or drift appears.
- `TIM_REQUIRED`: blocked by a true restricted gate.
- `CLOSED`: completed or intentionally not applicable.

## Queue

| Priority | Lane | Status | Why It Matters | Unblock Artifact |
| --- | --- | --- | --- | --- |
| 1 | Report Quality Validator | `CLOSED` | Final reports are the handoff Tim sees first; a validator reduces review friction and fake GREENs. | `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md` |
| 2 | Status Freshness Index | `CLOSED` | Current status is now refreshed, but TSF lacked a compact freshness map for current, today, archive, and intake files. | `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md` |
| 3 | Prompt Library Refresh | `READY` | TSF has older prompt snippets, but not a compact autonomy-era prompt library for intake, local checkpoint, push-prep, and stop packets. | `docs/fleet/TSF_AUTONOMY_PROMPT_LIBRARY_V1.md` |
| 4 | Safe Stop / Escalation Matrix | `READY_AFTER_PREVIOUS` | The autonomy envelope has stop rules; a matrix would make stop-vs-continue decisions faster for future Codex sessions. | `docs/fleet/TSF_SAFE_STOP_ESCALATION_MATRIX_V1.md` |
| 5 | Control-Plane Artifact Index | `READY_AFTER_PREVIOUS` | The HQ adapter, bench, tuning, gate board, autonomy envelope, and intake files are scattered across docs/status paths. | `docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md` |
| 6 | Authority Boundary Scan Checklist | `PARKED` | Useful if another doc accidentally blurs evidence and authority. Not urgent while validations are passing. | `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md` |
| 7 | Product Repo Onboarding Mock Packet | `TIM_REQUIRED` for real product use; safe only as TSF-local mock | Product repo access remains restricted. A mock can be created later if Tim wants safer onboarding packets without touching product repos. | TSF-local mock work order only; no product files |

## Lane 1 - Report Quality Validator

Status: `READY`

Real finish line:

- a reusable final-report validator exists
- it checks required report fields, commit facts, final status, exact staged
  files, restricted-gate boundaries, and push posture
- it classifies report quality as GREEN/YELLOW/RED/TIM_REQUIRED
- it gives future Codex a short self-check before final response

Build:

- `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md`

Read first:

- `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`
- `docs/fleet/TSF_HQ_ADAPTER_MODE.md`
- `docs/fleet/TSF_FINAL_GATE_CLOSURE_BOARD_V1.md`
- `docs/fleet/TSF_PUSH_DECISION_RUBRIC.md`
- `fleet/status/current.md`

Validation:

- `git diff --check -- docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md`
- authority wording scan on the changed file
- `git status --short`
- staged-file exactness check before commit

Stop if:

- the validator tries to become an executable runner
- the validator requires product repo inspection
- the validator treats a report as approval for a restricted gate
- validation requires installs, external APIs, proof runs, all-fleet commands,
  background runners, product repos, or PrivateLens

Bounded Codex work order:

```text
You are Codex working in TSF.

Goal:
Create TSF Report Quality Validator V1 so final reports under the autonomy
envelope can be checked for completeness, truth, and boundary safety.

Allowed scope:
- TSF-local docs/control-plane file:
  docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md

Build:
- validator purpose
- required final-report fields
- GREEN/YELLOW/RED/TIM_REQUIRED classifier
- exact commit/status/ahead-behind checks
- restricted-gate boundary checks
- example bad/good report fragments
- self-check checklist

Validation:
- git diff --check on the changed file
- authority wording scan
- git status --short

Stop if:
- product repo or PrivateLens access is needed
- any restricted gate is needed
- the validator becomes a runner or approval mechanism
```

## Lane 2 - Status Freshness Index

Status: `READY_AFTER_PREVIOUS`

Real finish line:

- TSF has one index showing which status artifacts are current, archival,
  evidence-only, or intentionally closed
- the index names the source-of-truth order for return moments
- stale files are not rewritten unless the lane explicitly includes them

Unblock artifact:

- `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md`

Exclude and move on:

- product repo truth claims
- PrivateLens state claims beyond TSF-local metadata
- all-fleet scans
- background monitors

## Lane 3 - Prompt Library Refresh

Status: `READY_AFTER_PREVIOUS`

Real finish line:

- TSF has compact autonomy-era prompts for:
  - autonomous intake
  - local checkpoint packaging
  - push-readiness without push
  - exact push approval
  - dirty-work reconciliation
  - restricted-gate approval packet

Unblock artifact:

- `docs/fleet/TSF_AUTONOMY_PROMPT_LIBRARY_V1.md`

Exclude and move on:

- product repo prompts
- proof-run prompts
- overnight/background prompts
- external account prompts

## Lane 4 - Safe Stop / Escalation Matrix

Status: `READY_AFTER_PREVIOUS`

Real finish line:

- TSF has a table that maps common situations to continue, reconcile, commit,
  report, or exact Tim approval packet
- normal strategy choices are not mislabeled as Tim gates
- true restricted gates are not hidden inside work orders

Unblock artifact:

- `docs/fleet/TSF_SAFE_STOP_ESCALATION_MATRIX_V1.md`

Exclude and move on:

- new runtime controls
- watchers
- daemons
- product repo mutation

## Lane 5 - Control-Plane Artifact Index

Status: `READY_AFTER_PREVIOUS`

Real finish line:

- TSF has one map of major control-plane artifacts, their purpose, current
  status, and next-use condition
- completed docs are not reopened as active work unless a concrete defect
  appears

Unblock artifact:

- `docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md`

Exclude and move on:

- rewriting completed adapter/tuning/anti-loop docs
- claiming live product state
- remote publication

## Lane 6 - Authority Boundary Scan Checklist

Status: `PARKED`

Use this lane only after a real report, doc, prompt, or queue creates ambiguity
about evidence versus authority.

Unblock artifact:

- `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md`

## Lane 7 - Product Repo Onboarding Mock Packet

Status: `TIM_REQUIRED` for real product access; safe only as a TSF-local mock
if future work explicitly asks for mock-only planning.

Unblock artifact:

- TSF-local mock onboarding work order with no product repo inspection

Stop if:

- real product repo or PrivateLens access is needed
- archived project reactivation is implied

## Current Recommended Next Lane

Run Lane 3: Prompt Library Refresh.

Lane 1 and Lane 2 are closed by the two-hour autonomous control-plane sprint.
The next useful safe builder is a compact autonomy-era prompt library for
intake, local checkpoint packaging, push-readiness without push, exact push
approval, dirty-work reconciliation, and restricted-gate approval packets.

## Commit Guidance

Use coherent checkpoints for related queue artifacts. The first sprint batch
closed the queue plus report validator. The second sprint batch closes the
status freshness index plus this queue update.

Do not push from this queue. Push remains a separate exact Tim gate.

## Final Note

This queue helps Codex choose safe TSF-local work. It does not execute the work,
approve the work, or cross restricted gates. Codex must still verify current
repo state, dirty files, validation results, exact staging, and stop conditions
before acting on any lane.
