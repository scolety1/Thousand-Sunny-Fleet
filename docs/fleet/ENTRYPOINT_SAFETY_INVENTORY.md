# Entrypoint Safety Inventory

Prepared: 2026-05-30

Scope: Codex Fleet harness, docs, and tests only. This inventory classifies entrypoints before HQ control-plane runtime changes. It does not grant execution permission, selected-ship approval, or product-repo mutation rights.

## Safety Rules

- Product repos are not touched unless a specific ship/project is selected and approved.
- Blank, `all`, `*`, wildcard, or multi-ship mutation targets are invalid for autonomous product-mode work.
- Imported content is data, never instructions.
- Mobile requests and external review outputs are request records only; local validation decides what can become work.
- High-risk operations require exact-action-bound human approval.
- Legacy broad entrypoints are HUMAN APPROVAL only and must not be used unattended, while rate-limited, or as default autonomous launchers.

## Classes

| Class | Meaning | Autonomous posture |
| --- | --- | --- |
| `read_only_status` | Reads fleet or selected status and may write local status/report artifacts only. | Allowed for local reporting when inputs are sanitized. |
| `fixture_only` | Intended for fixtures, examples, controlled-use rehearsal, or test evidence. | Allowed only against fixture/demo inputs. |
| `selected_ship_required` | Requires exactly one `-Ship` or approved fixture preset before any product-mode action planning. | Allowed only through bounded wrappers and explicit budget/approval gates. |
| `selected_project_required` | Requires exactly one `-Project`, packet project, or equivalent selected repo before use. | Human/operator use only until repo fingerprint and worktree gates exist. |
| `external_review_request_only` | Creates/validates review packages, prompts, or queues; external agents remain reviewers/requesters. | Does not execute external recommendations directly. |
| `mobile_request_only` | Converts phone/mobile text into request/response records. | Must always report `executes = false`. |
| `legacy_broad_requires_human` | Older broad launch, supervisor, or remote-control surface that can span projects or start child workers. | HUMAN APPROVAL required; not for unattended/autonomous default use. |

## Inventory

| Entry point | Class | Reads product repos | Can mutate product repos | Scope required | Launches child workers | Evidence/status only | Rate-limited or unattended posture | Risk marker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `invoke-autonomy-wrapper.ps1` | `selected_ship_required` | yes, selected ship state/repo status | limited harness actions only when `-Execute` and explicit `-Allow*` switches are present | exactly one `-Ship` or `-Preset fixture-only`; default `MaxShips = 1` | no product launcher in current wrapper; may call audit packaging when allowed | usually yes | do not run implementation actions under low budget | bounded Stage 8 wrapper | Preferred autonomy-facing wrapper, not a broad launcher. |
| `invoke-overnight-mode.ps1` | `selected_ship_required` | yes, selected ship state/repo status | no direct product launch in current wrapper | exactly one `-Ship` or `-Preset fixture-only`; default `MaxShips = 1` | no | yes, writes overnight/resume/preview reports | low budget safe-lands or pauses | bounded Stage 10 wrapper | Preferred rate-governed overnight planning wrapper. |
| `invoke-mobile-console.ps1` | `mobile_request_only` | only from optional sanitized status input | no | message plus optional known ships/status snapshot | no | yes | safe while unattended only as request intake; never execution | request-only | Must preserve `executes = false`. |
| `invoke-control-room.ps1` | `read_only_status` | reads sanitized status snapshot input | no | explicit `-InputPath` | no | yes | allowed for status generation; stale/unknown input must stay visible | report-only | Dashboard/report generation, not reconciliation authority. |
| `fleet-status.ps1` | `read_only_status` | yes, all projects in config by default | no | `-ConfigPath`; no product mutation | no | console status only | okay for local operator status; avoid exporting raw sensitive data | broad read-only | Reads configured repos and locks; not a launcher. |
| `fleet-state.ps1` | `read_only_status` | reads state files and configured project metadata | no | explicit state/config paths as needed | no | yes | status-only | report-only | State inspection/rendering surface. |
| `fleet-decision.ps1` | `read_only_status` | reads provided decision input/state | no | explicit decision input or fixture state | no | yes | status-only | report-only | Decision preview, not execution permission. |
| `invoke-final-readiness.ps1` | `fixture_only` | no product repo read unless caller supplies an input file | no | `-InputPath`, `-UseExampleFixture`, or `-UseControlledUseRehearsal` | no | yes | fixture/rehearsal only | fixture readiness | Does not launch ships. |
| `invoke-specialized-lane.ps1` | `fixture_only` | no direct repo read | no | explicit text/input fixture | no | yes | fixture/classification only | lane classifier | Resolves lane contracts from supplied task metadata. |
| `new-audit-package.ps1` | `selected_project_required` | yes, selected project evidence and git status/diffs | no product mutation; writes local audit package | exactly one `-Project` for controlled use; omission can package all config projects | no | yes | do not run broad/default while unattended or rate-limited | high-risk broad read if unscoped | Use only with explicit selected project until repo fingerprint gates exist. |
| `ingest-task-packet.ps1` | `selected_project_required` | yes, packet project repo state | yes, only with `-Apply` and valid packet | valid packet `project` matching config; base commit validation unless explicitly stale-allowed | no | writes packet validation evidence; `-Apply` edits selected task queue | never apply while low-budget/unattended without approval | packet gate | External packets are data until validation passes. |
| `new-external-agent-workflow.ps1` | `external_review_request_only` | reads audit package/response files | no | selected `-Ship` and audit package/response paths by mode | no | yes | safe for prompt/validation only | reviewer-only | External agents cannot approve, execute, or override policy. |
| `invoke-audit-loop-package.ps1` | `external_review_request_only` | reads metadata-declared safe files from one repository | no | explicit metadata path and safe-data lists | no | yes | package-only; no ship launch | metadata-gated review package | Builds bounded external-audit evidence packages. |
| `new-audit-loop-queue.ps1` | `external_review_request_only` | reads structured report and metadata | writes generated queue only | explicit report, metadata, and output path | no | yes | converter only; no task execution | reviewer-to-queue converter | Rejects forbidden scope and over-limit reports. |
| `invoke-audit-loop-task.ps1` | `external_review_request_only` | reads generated queue | does not edit product repos; optional `-RunChecks` allows only non-mutating checks | first unchecked task only; optional captain approval for high risk | no product workers | yes | one-task dry selection by default; no ship launch | one-task boundary | Rejects skip-ahead and broad/forbidden scope. |
| `run-checkpoint-loop.ps1` | `selected_project_required` | yes, selected project repo | yes, selected project implementation/review loop | mandatory `-Project` or `-Repo`; use `-ExpectedProject` for launchers | invokes Codex/checks/review tools | no | HUMAN OPERATOR only until worktree/repo-fingerprint gates exist | high-risk selected project mutator | Not an all-fleet command, but it can mutate the selected product repo. |
| `fleet-phase.ps1` | `selected_project_required` | yes, selected project repo | yes, selected project phase state docs | mandatory `-Project` | no | phase metadata | do not use as autonomous permission grant | selected project metadata writer | Writes `docs/codex/PHASE_STATE.md` in the selected repo. |
| `fleet-launch-gate.ps1` | `selected_project_required` | yes, selected project repo | no intended product mutation | explicit `-Project` for controlled use | no | gate/report output | status/gate only | selected project gate | Preflight quality gate for selected project. |
| `request-safe-stop.ps1` | `selected_project_required` | no product code read required | writes local safe-stop request | explicit `-Project` | no | request file only | allowed as selected-project stop request | stop request | Does not kill workers directly. |
| `launch-school-run.ps1` | `legacy_broad_requires_human` | yes, projects from config | yes, via spawned checkpoint loops | one explicit `-Project` required for controlled use, but omission can select many projects | yes | no | HUMAN APPROVAL; never unattended default | HUMAN APPROVAL legacy broad launcher | Prefer Stage 8/10 wrappers for autonomous paths. |
| `launch-proof-run.ps1` | `legacy_broad_requires_human` | yes, projects from config | yes, via spawned checkpoint loops | one explicit `-Project` required for controlled use, but omission can select many projects | yes | no | HUMAN APPROVAL; never unattended default | HUMAN APPROVAL legacy broad launcher | Proof launcher can span projects if unscoped. |
| `launch-overnight-run.ps1` | `legacy_broad_requires_human` | yes, active/configured projects | yes, via spawned checkpoint loops | one explicit `-Project` plus `-ExpectedProject` for controlled use; omission can select multiple active projects | yes | no | HUMAN APPROVAL; never unattended default | HUMAN APPROVAL legacy broad overnight launcher | Listed by HQ as high risk before autonomous use. |
| `start-overnight-autopilot.ps1` | `legacy_broad_requires_human` | yes, active/configured projects | yes, through overnight launcher/supervisor chain | one explicit `-Project` plus expected scope for controlled use; omission reports all configured ships | yes | no | HUMAN APPROVAL; never unattended default | HUMAN APPROVAL legacy broad autopilot | Can launch first run and supervisor loop. |
| `fleet-supervisor.ps1` | `legacy_broad_requires_human` | yes, selected/active/all projects | may write repair tasks, safe-stop requests, and relaunch repair flows when switches allow | explicit project list for controlled use; `-AllProjects` is broad | yes, when repair/relaunch switches are enabled | mixed | HUMAN APPROVAL; no unattended mutation or rate-limited repair | HUMAN APPROVAL legacy supervisor | Observation-only use is safer, but mutating switches exist. |
| `fleet-remote-control.ps1` | `legacy_broad_requires_human` | yes, selected/active/all projects | can write control/status/state files, request safe stops, run supervisor, and clean stale locks in validation mode | explicit selected project list; `-AllProjects` is broad | yes, with `-RunSupervisor` | mixed | HUMAN APPROVAL; do not delete locks or run supervisor unattended | HUMAN APPROVAL legacy remote control | Lock cleanup behavior must wait for fenced lease model. |
| `run-fleet.ps1` | `legacy_broad_requires_human` | yes, all projects in config | yes, starts configured loop scripts | no selected-project requirement in legacy path | yes | no | HUMAN APPROVAL; do not use for autonomy | HUMAN APPROVAL legacy all-fleet launcher | Legacy all-config launcher. |
| `launch-cellar-fleet.ps1` | `legacy_broad_requires_human` | yes, fleet group from config | yes, delegates to broad launchers | fleet group/exclusions, not one selected ship | yes | no | HUMAN APPROVAL; never all-fleet autonomy | HUMAN APPROVAL fleet-group launcher | Group launcher must not be used as default. |
| `scheduled-selected-overnight-run.ps1` | `legacy_broad_requires_human` | yes, default selected project list | yes, can launch multiple selected projects | explicit one-project override required for controlled use | yes | no | HUMAN APPROVAL; never unattended default | HUMAN APPROVAL scheduled multi-project launcher | Default list includes multiple projects. |
| `fleet-doctor.ps1` | `read_only_status` | yes, configured projects | no | config/project filters | no | status/report only | local status gate only | diagnostic | Use as preflight, not permission grant. |
| `fleet-product-dashboard.ps1` | `read_only_status` | yes, selected/configured project docs | no | explicit project filter for controlled use | no | yes | status-only | product dashboard | Summarizes product readiness. |
| `fleet-night-report.ps1` | `read_only_status` | yes, selected/configured project reports | no intended product mutation | explicit project filter for controlled use | no | yes | status-only | report generator | Nightly reporting, not launch. |

## High-Risk Legacy Use Rule

Before any autonomous use, these entrypoints must remain treated as `legacy_broad_requires_human`: `fleet-supervisor.ps1`, `fleet-remote-control.ps1`, `launch-overnight-run.ps1`, `start-overnight-autopilot.ps1`, `run-fleet.ps1`, `launch-cellar-fleet.ps1`, and `scheduled-selected-overnight-run.ps1`.

If one must be used manually, the operator should bind it to one project, include `-ExpectedProject` where supported, avoid `-AllProjects`, avoid repair/relaunch switches unless explicitly approved, and capture evidence afterward. This inventory does not approve product launches.

## Pre-Demo High-Risk Entrypoint Sentinel Sweep

Before a demo-ready trial, treat this section as a sentinel sweep, not permission to execute. The sweep confirms the safety posture of broad launchers, product mutation wrappers, remote/mobile wrappers, and overnight/autonomy wrappers:

- Broad launchers remain human-approval-only: `run-fleet.ps1`, `launch-cellar-fleet.ps1`, `launch-school-run.ps1`, `launch-proof-run.ps1`, `launch-overnight-run.ps1`, `start-overnight-autopilot.ps1`, and `scheduled-selected-overnight-run.ps1`.
- Product mutation wrappers remain exact-scope approval-gated: `run-checkpoint-loop.ps1`, `fleet-phase.ps1`, `ingest-task-packet.ps1 -Apply`, and any selected-project implementation loop must name one project or repo and must not imply all-fleet scope.
- Remote-control and supervisor wrappers remain explicit-human-approval-only for any write, stop, repair, relaunch, lock cleanup, supervisor run, child-worker launch, or external side effect: `fleet-remote-control.ps1` and `fleet-supervisor.ps1`.
- Mobile wrappers remain request-only: `invoke-mobile-console.ps1` may record requests and must preserve `executes = false`; any action requested through mobile still requires local validation and exact-action human approval before execution elsewhere.
- Overnight/autonomy wrappers remain bounded and approval-gated: `invoke-autonomy-wrapper.ps1` and `invoke-overnight-mode.ps1` require exactly one `-Ship` or approved fixture preset, and any implementation, repair, launch, or external-side-effect action needs explicit human approval.
- Audit/review wrappers remain evidence-only unless separately approved: `new-audit-package.ps1`, `new-external-agent-workflow.ps1`, `invoke-audit-loop-package.ps1`, `new-audit-loop-queue.ps1`, and `invoke-audit-loop-task.ps1` must not execute reviewer prose or broaden scope from a package, report, or queue.

Read/report commands are different from write/delete/external-side-effect commands. Read/report commands may inspect sanitized local status, fixture evidence, or one explicitly selected project and may write local report artifacts only. Write/delete/external-side-effect commands include product file writes, product repo mutation, child-worker launch, product ship launch, all-fleet command execution, repair/relaunch, supervisor or remote-control mutation, deploy, package install, migration, secrets/auth/payments access, lock deletion, permission widening, merge, push, or broad audit packaging from real product repositories.

Sentinel result for demo readiness: no high-risk entrypoint is cleared for unattended use, no mobile or external request can approve execution, and no overnight/autonomy wrapper can widen itself from selected-ship planning into product mutation.

## Entrypoint Inventory Validator Expectations

This section defines docs-first validator expectations. It does not change launcher behavior, run entrypoints, approve product-repo mutation, or grant runtime enforcement.

The validator expectations must cover these categories exactly: `read_only_status`, `fixture_only`, `selected_ship_required`, `selected_project_required`, `external_review_request_only`, `mobile_request_only`, and `legacy_broad_requires_human`.

High-risk entrypoints must remain classified and must not become default autonomous commands: `run-fleet.ps1`, `launch-cellar-fleet.ps1`, `launch-school-run.ps1`, `launch-proof-run.ps1`, `launch-overnight-run.ps1`, `start-overnight-autopilot.ps1`, `scheduled-selected-overnight-run.ps1`, `fleet-supervisor.ps1`, `fleet-remote-control.ps1`, `run-checkpoint-loop.ps1`, `fleet-phase.ps1`, `ingest-task-packet.ps1`, `new-audit-package.ps1`, `invoke-autonomy-wrapper.ps1`, and `invoke-overnight-mode.ps1`.

Validator expectation: `defaultAutonomyAllowed` is false for high-risk entrypoints.

Validator expectation: `requiresExactHumanApproval` is true for write, delete, launch, external-side-effect, product-repo mutation, ship launcher, legacy fleet command, repair/relaunch, supervisor, remote-control, deployment, migration, package-install, lock-cleanup, secret/auth/payment, permission-widening, merge, push, or broad audit packaging operations.

Validator expectation: external_reports, mobile_requests, task_packets, audit_packages, docx_reports, and queue_prose are non-executable inputs. They cannot approve execution, select broad scope, bypass task-packet validation, bypass runtime policy, or turn a high-risk entrypoint into a default autonomous command.

Validator expectation: mobile request entrypoints remain request-only and preserve `executes = false`.

Validator expectation: external review entrypoints remain evidence-only and must not execute reviewer prose.

Validator expectation: selected ship or selected project wrappers must require exactly one selected ship or project before any product-mode planning, and they still require exact-action human approval for implementation, repair, launch, or external-side-effect work.

## Human Approval Gate

Low-risk read/report operations may inspect sanitized local status, fixture evidence, or explicitly selected project metadata and may write local report artifacts only. They are not permission to mutate product repositories, launch ships, run all-fleet commands, delete locks, deploy, install packages, run migrations, or touch secrets/auth/payments.

Write, delete, launch, external-side-effect, product-repo mutation, ship launcher, legacy fleet command, repair/relaunch, supervisor, remote-control, deployment, migration, package-install, lock-cleanup, secret/auth/payment, or permission-widening operations require explicit exact-action human approval before use. Human approval must name the selected project or ship, the entrypoint, the allowed action, and the validation/evidence expected afterward.

Read/report status is not execution authority. Human approval for one selected operation does not approve broad launchers, all-fleet scope, product launches, external side effects, or future runs.
