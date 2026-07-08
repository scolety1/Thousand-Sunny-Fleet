# TSF Control-Plane Artifact Index V1

Prepared: 2026-07-02

Evidence only; not executable authority or restricted-action approval.

## Purpose

TSF Control-Plane Artifact Index V1 maps the major Thousand Sunny Fleet
control-plane artifacts so Tim and Codex can quickly tell:

- which files define current TSF operating rules
- which files are evidence, status, generated output, UI guidance, tools, tests,
  prompts, or historical context
- which artifacts can guide safe TSF-local work
- which artifacts cannot approve product repo access, PrivateLens work, push,
  deploy, installs, migrations, secrets/auth/payments, proof runs, all-fleet
  commands, background runners, external account changes, spending, archived
  project reactivation, or history/remote release changes

This index prevents docs, generated outputs, status reports, work orders,
research packets, UI text, and historical snapshots from being mistaken for
approval authority.

## Classification Model

Authority level:

- `AUTHORITY`: defines current TSF-local operating rules, guardrails, stop
  conditions, lane closure rules, or exact approval requirements.
- `EVIDENCE_ONLY`: provides status, review, handoff, audit, or research evidence
  but does not approve action by itself.
- `GENERATED_STATUS`: generated or refreshed status output; evidence only.
- `GENERATED_WORK_ORDER`: generated task/work-order proposal; requires normal
  scope, validation, and restricted-gate checks before action.
- `UI_ONLY`: static UI/prototype/readable guidance; not command authority.
- `TEST_FIXTURE`: regression fixture or test-only sample; not live authority.
- `HISTORICAL`: older snapshot or closed evidence; useful context only.

Freshness:

- `CURRENT`: current return-context or status file.
- `CURRENT_CONTROL`: current control-plane operating artifact.
- `STALE`: known old enough to require fresh verification before use.
- `HISTORICAL`: past evidence only.
- `GENERATED_ON_DEMAND`: produced by tools when explicitly run.
- `UNKNOWN`: classify from local evidence before relying on it.

Safe default action:

- `read first`: open before lane selection or status decisions.
- `read as evidence`: use as supporting context only.
- `regenerate`: recreate with the named TSF-local generator when explicitly in
  scope.
- `ignore unless selected`: do not inspect or mutate unless the lane names it.
- `do not mutate without Tim approval`: stop unless exact Tim approval covers
  the restricted scope.

Can authorize action:

- `yes`: can guide safe TSF-local docs/control-plane decisions within its stated
  scope.
- `no`: cannot approve work by itself.

No artifact in this index can approve restricted actions without exact Tim
approval.

## Core Rules

- Research is evidence, not authority.
- Generated work orders are proposals, not approval.
- Status files are evidence, not permission to inspect or mutate product repos.
- The Fleet Console is UI/readable guidance, not executable authority.
- Archived project artifacts do not reactivate archived projects.
- Product repo paths in TSF files do not authorize inspection or mutation.
- Push, deploy, installs, migrations, secrets/auth/payments, proof runs, external account changes, all-fleet commands, background runners, archived reactivation, and history/remote release changes require exact Tim approval.

## Authority / Contract

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md` | Authority / Contract | Defines safe autonomous TSF-local docs/control-plane work and true Tim gates. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Does not approve restricted actions or future blanket authority. |
| `docs/fleet/TSF_SAFE_STOP_ESCALATION_MATRIX_V1.md` | Authority / Contract | Decides continue, local commit, stop, exact approval, unsafe hold, or phase close. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Guides decision state only; restricted gates still need exact Tim approval. |
| `docs/fleet/TSF_HQ_ADAPTER_MODE.md` | Authority / Contract | Defines HQ verdict shape, JSON decision block, lane discipline, and Tim gates. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Strategic operating format, not product repo authority. |
| `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` | Authority / Contract | Queue of safe TSF-local control-plane builder lanes and next-use conditions. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Queue helps choose work; it does not execute work or approve push. |
| `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md` | Authority / Contract | Source-of-truth order and freshness classification for return moments. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Freshness map is not current git truth; still verify branch, HEAD, remote, and status. |
| `docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md` | Authority / Contract | Classifies TSF artifacts by category, authority level, freshness, and safe default action. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Index does not replace live validation or exact Tim approvals. |
| `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md` | Authority / Contract | Final-report checklist and classifier for autonomy-era TSF reports. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Report quality is not the same as approval to push or mutate restricted scopes. |
| `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md` | Authority / Contract | Fast scan for classifying authority leaks across docs, prompts, status, UI text, logs, work orders, and Tim-gate packets. | `AUTHORITY` | `CURRENT_CONTROL` | read first when authority is ambiguous | yes | Classifies and routes ambiguity; it does not approve restricted actions. |
| `docs/fleet/TSF_REPO_ONBOARDING_WORKFLOW_V1.md` | Authority / Contract | Canonical route for registering a repo, running read-only inventory/source trace, generating improvement and handoff artifacts, and stopping before mutation. | `AUTHORITY` | `CURRENT_CONTROL` | read first for repo onboarding | yes | Extends `add-project.ps1`/`projects.json`; does not approve product repo mutation. |
| `docs/fleet/TSF_HISTORICAL_DATA_FOUNDATION_PROTOCOL_V1.md` | Authority / Contract | Defines mandatory source discovery, provenance, suspicious-low-coverage, acquisition-gate, scoring, comparison, and no-promotion rules for data foundation lanes. | `AUTHORITY` | `CURRENT_CONTROL` | read first for data foundation lanes | yes | Does not approve public data acquisition, product mutation, model tuning, source-truth promotion, or app/ranking changes. |
| `docs/fleet/TSF_BLOCKER_RECOVERY_LOOP_V1.md` | Authority / Contract | Defines freeze, classify, preserve, recover-once, validate, compare, and escalate behavior when TSF lanes hit blockers. | `AUTHORITY` | `CURRENT_CONTROL` | read first when a blocker appears | yes | Forces one bounded safe recovery artifact before blocker-only packets; restricted gates still stop. |
| `docs/fleet/TSF_BLOCKER_CLASSIFICATION_MATRIX_V1.md` | Authority / Contract | Classifies blocker types, safe recovery actions, stop conditions, Tim gates, examples, and expected artifacts. | `AUTHORITY` | `CURRENT_CONTROL` | read first when classifying blockers | yes | Includes NWR historical foundation as worked example; does not approve restricted actions. |
| `docs/fleet/TSF_PUSH_DECISION_RUBRIC.md` | Authority / Contract | Defines exact push-decision posture and non-authority evidence boundaries. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Push still needs exact Tim approval after GREEN readiness. |
| `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md` | Authority / Contract | Turns blocker-documentation loops into builder/unblock-artifact lanes. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Should redirect safe blockers, not bypass restricted gates. |
| `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md` | Authority / Contract | Prevents repeated review/documentation treadmill behavior. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Avoids churn; does not approve unsafe shortcuts. |
| `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md` | Authority / Contract | Prompt/post-run checklist for bounded Codex lanes. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Checklist supports scope discipline only. |
| `docs/fleet/ARTIFACT_INDEX_CONTRACT.md` and other `*_CONTRACT.md` files | Authority / Contract | Older or specialized schemas/contracts for TSF subsystems. | `AUTHORITY` | `UNKNOWN` | read as evidence | yes | Verify freshness against current autonomy docs before treating as current control. |

## Evidence / Status

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fleet/status/current.md` | Evidence / Status | Current phone-readable TSF snapshot. | `GENERATED_STATUS` | `CURRENT` | read first | no | Must verify git truth live before conclusions. |
| `fleet/status/today.md` | Evidence / Status | Current local daily autonomy/status notes. | `GENERATED_STATUS` | `CURRENT` | read first | no | Evidence only; not approval. |
| `fleet/status/autonomous-work-intake-2026-07-01.md` | Evidence / Status | Closed evidence for autonomous work intake status refresh. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Do not reopen unless a concrete defect appears. |
| `docs/fleet/TSF_FINAL_GATE_CLOSURE_BOARD_V1.md` | Evidence / Status | Closure board for final gate review. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Summarizes gates; does not approve new restricted action. |
| `fleet/runs/overnight-runner/overnight-runner-pilot-v0-2026-07-02.md` | Evidence / Status | Completed controlled overnight-runner harness pilot log. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Closed runner evidence; not approval for product repos or persistent runners. |
| `fleet/runs/overnight-runner/overnight-runner-json-template-dry-run-v0-1-2026-07-02.md` and `.json` | Evidence / Status | Completed structured decision-log template dry run. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Proves template usability; does not approve product-repo pilots. |
| `docs/fleet/product-pilots/NWR_HISTORICAL_FOUNDATION_TSF_RECOVERY_POSTMORTEM_V1.md` and `fleet/runs/product-pilots/nwr-historical-foundation-tsf-recovery-postmortem-v1-2026-07-03.json` | Evidence / Status | Postmortem and run log for the NWR historical foundation TSF miss/recovery/parity lesson. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | read as evidence | no | Supports future data foundation prompts; does not approve NWR work, public downloads, model use, or source-truth promotion. |
| `fleet/runs/templates/blocker-recovery-loop-v1-template.json` | Evidence / Status | Reusable run-log template for blocker classification, preservation, recovery attempt, result, and authority request fields. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | read as evidence | no | Template only; does not approve reruns, deletion, public acquisition, product mutation, or restricted actions. |
| `fleet/status/master-codex-status.md` | Evidence / Status | Historical Master Codex status report. | `HISTORICAL` | `STALE` | read as evidence | no | Do not trust for current branch, HEAD, or push posture. |
| `fleet/status/return-review.md` and `fleet/status/return-triage-score.*` | Evidence / Status | Return review and triage outputs. | `GENERATED_STATUS` | `HISTORICAL` | read as evidence | no | Useful background; rerun only if selected. |
| `fleet/status/product-completion-board-*.md` | Evidence / Status | Product completion/status evidence. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Product claims need fresh approved product-repo inspection. |
| `fleet/status/blocked-project-repo-audit-*.md` | Evidence / Status | Evidence of blocked product-repo/path audits. | `EVIDENCE_ONLY` | `HISTORICAL` | read as evidence | no | Confirms a gate; does not satisfy it. |
| `fleet/status/projects.md` and `fleet/status/projects.json` | Evidence / Status | TSF-local project registry snapshots. | `EVIDENCE_ONLY` | `STALE` | read as evidence | no | Archived/active labels do not approve repo mutation or reactivation. |

## Generated Outputs

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fleet/status/project-passports/*.md` | Generated Outputs | Project passport summaries. | `GENERATED_STATUS` | `GENERATED_ON_DEMAND` | regenerate | no | Do not treat as current product truth without approved inspection. |
| `fleet/status/next-session/*.md` | Generated Outputs | Next-session cards. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Proposals only; validate scope before action. |
| `fleet/status/work-orders/*.md` and `fleet/status/work-order-splits/*.md` | Generated Outputs | Work-order drafts and split task proposals. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Work orders do not approve restricted actions. |
| `fleet/status/repo-xray/*.md` and `fleet/status/context-packs/*.md` | Generated Outputs | Repo x-ray/context-pack summaries. | `GENERATED_STATUS` | `GENERATED_ON_DEMAND` | read as evidence | no | May contain product paths; paths do not approve inspection or mutation. |
| `fleet/status/diff-risk-review.md` and `fleet/status/coding-lessons/*.md` | Generated Outputs | Diff risk and lessons-learned outputs. | `GENERATED_STATUS` | `GENERATED_ON_DEMAND` | read as evidence | no | Evidence for future checks, not live approval. |
| `fleet/status/stuck-playbooks/*.md` | Generated Outputs | Stuck-state playbooks. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Redirects safe work; restricted gates still stop. |
| `fleet/status/repo-onboarding/**` | Generated Outputs | Repo onboarding identity, baseline, existing-asset trace, structure/docs/tests/data/risk inventories, reuse matrix, improvement queue, summary, review, validation, and handoff packets. | `GENERATED_STATUS` | `GENERATED_ON_DEMAND` | read as evidence | no | Review packet only; stop before product-repo mutation unless Tim approves exact scope. |
| `fleet/status/game-forge/**` | Generated Outputs | Game Forge templates, blueprints, system maps, risk reviews, research prompts, prototype slices, and game work orders. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Game research/prompts are proposals and evidence, not authority. |

## UI / Console

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/fleet/ui/prototype/fleet-console.html` and `fleet-console.css` | UI / Console | Static Fleet Console prototype. | `UI_ONLY` | `CURRENT_CONTROL` | ignore unless selected | no | UI labels/buttons are not executable controls or approval. |
| `docs/fleet/ui/prototype/README.md` and prototype packets | UI / Console | Prototype review/readme guidance. | `UI_ONLY` | `CURRENT_CONTROL` | read as evidence | no | Static review packets do not approve runtime command binding. |
| `docs/fleet/ui/FLEET_CONSOLE_*.md` | UI / Console | Console design, phone mode, remote security, status/action model, and button policy docs. | `AUTHORITY` | `CURRENT_CONTROL` | read as evidence | yes | Authority is limited to console design/control policy; no executable browser controls. |

## Tools / Generators

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tools/write-*.ps1` | Tools / Generators | Generate TSF-local status, packs, reviews, work orders, and Game Forge outputs. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | ignore unless selected | no | Running a generator must be in scope and safe; tool existence is not approval to run it. |
| `tools/register-project-metadata-only.ps1` | Tools / Generators | Metadata-only project registration wrapper for exact repo paths without target-repo mutation. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | run only when read-only onboarding registration is selected | no | Writes TSF registry metadata only, blocks same-name/different-path overwrites, and validates target git status is unchanged. |
| `tools/write-repo-onboarding-packet.ps1` | Tools / Generators | Read-only repo inventory, existing-feature detector, improvement register, review packet, validation JSON, and handoff generator. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | run only when repo onboarding is selected | no | Writes only configured output and rejects output inside the scanned repo. |
| `tools/codex-fleet-*.ps1` | Tools / Generators | Fleet helper/entrypoint scripts for TSF subsystems. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | ignore unless selected | no | Some helpers are wrappers; inspect before use and avoid all-fleet/proof/overnight scopes. |
| `tools/render-fleet-console.ps1` and `tools/static-preview-server.ps1` | Tools / Generators | Render or preview static console artifacts. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | ignore unless selected | no | Do not start background servers/watchers unless exact approval exists. |
| `tools/fleet-proof-run-preflight.ps1`, launchers, and overnight/proof scripts | Tools / Generators | Preflight or launch gated fleet/product work. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | do not mutate without Tim approval | no | Proof runs, all-fleet commands, and background/overnight runners are restricted gates. |

## Tests / Fixtures

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tests/run-fleet-tests.ps1` | Tests / Fixtures | Main TSF regression suite. | `TEST_FIXTURE` | `CURRENT_CONTROL` | read first | no | Test pass is evidence, not approval to push or deploy. |
| `tests/fixtures/fleet/**` | Tests / Fixtures | Regression fixtures for TSF subsystems, gates, UI safety, read-only demos, and anti-loop behavior. | `TEST_FIXTURE` | `CURRENT_CONTROL` | ignore unless selected | no | Fixture examples are not live packets or approvals. |
| `tests/fixtures/fleet/repo-onboarding/**` | Tests / Fixtures | Safe local fixture for repo onboarding inventory, existing-feature detection, improvement register, and handoff validation. | `TEST_FIXTURE` | `CURRENT_CONTROL` | ignore unless selected | no | Fixture is not a product repo and does not approve live repo onboarding. |
| `.codex-local/fixtures/**` | Tests / Fixtures | Runtime-created temporary fixtures when tests run. | `TEST_FIXTURE` | `GENERATED_ON_DEMAND` | ignore unless selected | no | Local/generated; do not treat as durable status. |

## Prompt Libraries / Work Orders

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/fleet/TSF_AUTONOMY_PROMPT_LIBRARY_V1.md` | Prompt Libraries / Work Orders | Copyable prompts for autonomy intake, checkpointing, push-prep, exact approval, and final-report self-checks. | `AUTHORITY` | `CURRENT_CONTROL` | read first | yes | Prompt text does not bypass live repo validation or restricted gates. |
| `docs/fleet/TSF_NEXT_SESSION_CARDS_V1.md` | Prompt Libraries / Work Orders | Compact next-session routing cards for safe TSF-local sessions and true Tim approval gates. | `GENERATED_WORK_ORDER` | `CURRENT_CONTROL` | read first | no | Cards are routing evidence; they do not approve restricted work. |
| `docs/fleet/overnight-runner/TSF_READ_ONLY_PRODUCT_REPO_PILOT_APPROVAL_PACKET_V0.md` | Prompt Libraries / Work Orders | Exact approval-packet template for a future read-only product-repo pilot. | `GENERATED_WORK_ORDER` | `CURRENT_CONTROL` | read as evidence | no | Does not approve product repo or PrivateLens access by itself. |
| `docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_*.md` and `docs/fleet/overnight-runner/*.json` | Prompt Libraries / Work Orders | Runner harness design, stop conditions, decision-log schema, and template artifacts. | `AUTHORITY` | `CURRENT_CONTROL` | read as evidence | no | Runner guidance shapes TSF-local mechanics; it does not approve product repos, persistent runners, or restricted work. |
| `docs/fleet/hq-adapter/**` | Prompt Libraries / Work Orders | HQ decision bench, tuning runbook, dry run, and scorecard artifacts. | `EVIDENCE_ONLY` | `CURRENT_CONTROL` | read as evidence | no | Bench/tuning artifacts improve judgment but do not approve execution. |
| `docs/fleet/HQ_REPAIR_TASK_QUEUE.md` and thin task packets | Prompt Libraries / Work Orders | Historical and active HQ repair/task packet records. | `GENERATED_WORK_ORDER` | `UNKNOWN` | read as evidence | no | Queue entries are proposals until selected, scoped, validated, and gated. |
| `fleet/status/work-orders/**` | Prompt Libraries / Work Orders | Project/game work-order drafts generated by TSF tools. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Product repo paths or names in work orders do not approve product repo access. |
| `fleet/status/draft-queue/**` | Prompt Libraries / Work Orders | Prepared approval packets, morning decision queues, and draft work orders. | `GENERATED_WORK_ORDER` | `GENERATED_ON_DEMAND` | read as evidence | no | Draft packets are proposals Tim can approve, edit, deny, or ignore. |

## Stale / Historical / Evidence Only

| Path | Category | Purpose | Authority Level | Freshness | Safe Default Action | Can Authorize Action | Notes / Risks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fleet/status/*2026-06-*.md` | Stale / Historical / Evidence Only | Older status, boards, handoffs, audits, and completion evidence. | `HISTORICAL` | `HISTORICAL` | read as evidence | no | Re-verify current git and lane state before relying on them. |
| Older `docs/fleet/*GREEN_AUDIT_RECORD*.md`, `POST_*`, `REMOTE_TRAVEL_*`, and read-only demo records | Stale / Historical / Evidence Only | Closed proof/evidence for prior TSF lanes. | `HISTORICAL` | `HISTORICAL` | read as evidence | no | Closed evidence is not standing approval for new work. |
| Archived project mentions in `fleet/status/projects.*`, passports, work orders, or status files | Stale / Historical / Evidence Only | Archived/project registry evidence. | `HISTORICAL` | `STALE` | read as evidence | no | Archived project artifacts do not reactivate archived projects. |
| Product repo paths in any TSF doc/status/work order | Stale / Historical / Evidence Only | Reference to possible external/product work. | `EVIDENCE_ONLY` | `UNKNOWN` | do not mutate without Tim approval | no | Paths do not authorize inspection, mutation, tests, or proof runs. |

## Safe Default Reading Order

For normal autonomous TSF-control-plane work:

1. Verify live git state: branch, HEAD, `origin/main`, ahead/behind, and
   `git status --short`.
2. Read `fleet/status/current.md` and `fleet/status/today.md` for current
   status evidence.
3. Read `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`.
4. Read `docs/fleet/TSF_SAFE_STOP_ESCALATION_MATRIX_V1.md`.
5. Read `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md`.
6. Read this artifact index to classify any other docs/status/tools before
   using them.
7. Read `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md` when freshness or stale
   status is the question.
8. Read `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md` when an
   artifact blurs evidence, authority, generated work, UI guidance, historical
   status, or Tim-required gates.

## Do Not Treat As Authority

The following cannot approve work by themselves:

- research notes
- generated work orders
- generated status files
- return reviews
- completion boards
- Fleet Console UI text
- benchmark examples
- test fixtures
- older green audit records
- product repo paths inside TSF docs
- archived project references
- Codex final reports

## Final Rule

When in doubt, classify the artifact before acting:

- `AUTHORITY` can guide safe TSF-local control-plane behavior inside its scope.
- `EVIDENCE_ONLY`, `GENERATED_STATUS`, `GENERATED_WORK_ORDER`, `UI_ONLY`,
  `TEST_FIXTURE`, and `HISTORICAL` cannot approve action by themselves.
- Restricted actions always require exact Tim approval, regardless of what any
  artifact says or implies.
