# New Chat Handoff Packet

Use this file to move Codex Fleet / Thousand Sunny Fleet work into a fresh Codex chat without losing the value from the audits and Deep Research reports.

## Current Bounded Handoff Path

For active implementation work, prefer the compact path below instead of pasting the full historical handoff into every Codex run:

1. Read `docs/fleet/STABLE_CONTEXT_CAPSULE.md`.
2. Read only the active queue section in `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`.
3. Read the selected task's `readFirst` files.
4. If a thin task packet exists for the selected task, read that packet instead of broad historical prose.
5. Use compact validation summaries and external-audit intake digests instead of raw logs, DOCX reports, full audit prose, or generated evidence dumps.
6. For anti-loop runs, use `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md` as the latest prompt and post-run checklist, `docs/fleet/anti-loop/PROGRESS_LEDGER_AND_LOOP_FINGERPRINTS.md` as the latest ledger/fingerprint reference, and `docs/fleet/anti-loop/DRIFT_STOP_AND_REPACKETIZATION.md` as the latest stop/repacketization rule.
7. For Fleet Console planning, treat `docs/fleet/ui/FLEET_CONSOLE_PRODUCT_BRIEF.md`, `docs/fleet/ui/FLEET_CONSOLE_STATUS_AND_ACTION_MODEL.md`, `docs/fleet/ui/FLEET_CONSOLE_GOAL_LOOP_SIGNALS.md`, `docs/fleet/ui/FLEET_CONSOLE_WIREFRAMES.md`, `docs/fleet/ui/FLEET_CONSOLE_PROMPT_AUDIT_TOKEN_DESIGN.md`, `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`, `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`, `docs/fleet/ui/FLEET_CONSOLE_UNSTUCK_WORKFLOW.md`, `docs/fleet/ui/FLEET_CONSOLE_FUTURE_PROTOTYPE_GATE.md`, and `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md` as evidence-only planning inputs. They do not approve UI code, server setup, package installation, authentication, remote exposure, runtime command binding, product-repo access, or future implementation.
8. For next-phase local control-plane preparation, use `docs/fleet/NEXT_PHASE_LOCAL_CONTROL_PLANE_TRANSITION.md` as the transition decision record. It is evidence only and does not approve UI implementation, remote access, package sending, runtime command binding, product-repo work, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.
9. For future external audit package preparation, use `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md` with `templates/external-audit-package-manifest-schema.json`. The runbook and manifest are evidence only; they do not create or send packages, approve execution, inspect product repos, or grant future authority.

This compressed handoff path is evidence only. It does not approve product-repo access, product mutation, all-fleet execution, ship launch, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or dirty-work reverts.

If the compact capsule, active queue entry, thin task packet, or source-of-truth docs conflict, stop and ask for repacketization instead of broadening scope.

Latest bounded move: continue the active queue by selecting exactly one eligible task, using the checklist above, recording the latest ledger/fingerprint in the final report, and stopping after that task's validation and status update.

Latest UI planning posture: Fleet Console planning docs are local planning evidence only. Prompt Builder, Audit Builder, Evidence Locker, Idea Inbox, Work On Something Else, Unstuck, approval cards, token counters, button-policy docs, remote-access docs, and the remote security plan do not start Codex, send packages, import findings, approve actions, run tasks, choose real projects, expose a server, create auth, or execute commands. Any prototype, remote access, auth, package export, notification, or implementation requires a new bounded task with explicit allowed files, validation commands, security posture, and stop conditions.

Latest next-phase posture: after the Audit Guidelines Review fix-up tasks, the next phase is local-only control-plane preparation. `docs/fleet/NEXT_PHASE_LOCAL_CONTROL_PLANE_TRANSITION.md` separates completed fix-ups, schema/test/runbook preparation, future UI prototype gates, future remote security gates, and future external audit gates. It does not approve UI code, remote access, package sending, runtime command binding, product-repo work, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

## Current Repo Status

- Repo: `C:\Dev\codex-fleet`
- Date prepared: 2026-05-30
- Current working tree: dirty, intentionally.
- Product repos: do not touch by default.
- All-fleet commands: do not run.
- Stable context capsule: `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- Token-control operating model: `docs/fleet/TOKEN_CONTROL_OPERATING_MODEL.md`
- Next-phase local control-plane transition: `docs/fleet/NEXT_PHASE_LOCAL_CONTROL_PLANE_TRANSITION.md`
- Thin task packet schema: `templates/thin-task-packet-schema.json`
- Compact validation summary schema: `templates/validation-output-summary-schema.json`
- External audit intake digest schema: `templates/external-audit-intake-digest-schema.json`
- External audit package manifest schema: `templates/external-audit-package-manifest-schema.json`
- External audit package allowlist runbook: `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- Latest known full test evidence: `docs/codex/test-summary.md`
- Latest HQ recon: `docs/fleet/HQ_IMPORT_RECON.md`
- HQ packet source of truth: `C:\Users\codex-agent\Documents\When Low on Rate Limits\codex_fleet_repair_hq\Codex_Fleet_Codex_Ready_Next_Cycle`

Important git status note:

- The repo currently has many modified and untracked harness/docs/tests files from Golden Gameplan work.
- This includes scripts such as `invoke-autonomy-wrapper.ps1`, `invoke-overnight-mode.ps1`, `invoke-mobile-console.ps1`, `new-audit-package.ps1`, `ingest-task-packet.ps1`, `tests/run-fleet-tests.ps1`, `tools/codex-fleet-*.ps1`, `docs/golden-gameplan/`, `docs/codex/`, `templates/`, and `fleet/status/`.
- Treat those as current project state. Do not revert them.
- Before a long new repair cycle, create a checkpoint branch/commit or at least an audit package so the state is not lost.

## Implemented Work Summary

### Golden Gameplan baseline

The Golden Gameplan has been written and implemented through Stage 14, then extended with post-Golden hardening and optional audit-loop mode.

Implemented themes:

- Stage 1-4.5: stability, standard evidence, audit package V2, and task-packet validation.
- Stage 5-6: state machine and decision-engine support.
- Stage 7: product-quality contracts, first-screen contracts, lane-specific quality evidence.
- Stage 8-8.5: autonomy wrapper and hardening, bounded action mapping, packet-evidence requirements.
- Stage 9-9.5: external-agent workflow and reliability patch.
- Stage 10: overnight mode, rate governor, safe landing, weekly reset preview pause, heartbeat/lease recovery.
- Stage 11: specialized lanes for hospitality websites, manager/internal tools, analytical software, backend-sensitive work, and maintenance.
- Stage 12: dashboard/control-room reporting.
- Stage 13: mobile captain console, request-only model, safe remote requests, idea intake, phone-readable digest, generated-plan approval docs.
- Stage 14: final hardening, readiness scoring, fixture stress scenarios.
- Stage 15: post-Golden hardening, quick start, controlled-use rehearsal, product-launch checklist, edge-case fixture expansion.
- Stage 16: optional audit-loop mode based on the HouseOS/customer-website external audit pattern.

### Key implemented safety patterns

- Stage 8/10 wrappers require explicit `-Ship` or `-Preset`; default `MaxShips = 1`.
- Mobile commands are request records only and report `executes = false`.
- External agents are reviewers/requesters only, not executors.
- Task packets validate before import.
- Audit packages include standard run artifacts and dirty repo evidence.
- Weekly budget at about 5 percent can trigger `WEEKLY_PREVIEW_PAUSE` and a review-note path.
- Low budget blocks implementation actions and prioritizes evidence/safe landing.
- Controlled-use rehearsal exists for fixture-only readiness checks.

## Report-To-Task Crosswalk

| Source report/research | Main finding | What was already converted into work | Current status |
| --- | --- | --- | --- |
| Early external audit on Stages 1-4 | Audit package was too thin; `RUN_RESULT.json` was hollow; task-packet validation not evidenced. | Stage 4.5 Evidence Repair and Audit Package V2. Added non-empty checks/evidence, validation fixtures, runtime scope policy, changed-source/diff packaging. | Implemented and externally re-audited GREEN. |
| Stage 7 audit | Package omitted required product-quality templates and lane profiles. | Stage 7 repair tasks in `docs/codex/TASK_QUEUE.md`: rebuilt package, regenerated evidence, reconciled files, added Stage 8 handoff mapping, closure note. | Implemented; later audit GREEN. |
| Stage 8/9 audit | Autonomy wrapper needed hardening before external workflow expansion. | Stage 8.5 and Stage 9.5: packet-evidence hardening, failure containment, phone-readable reports, external response reliability. | Implemented. |
| Stage 8.5-11 audit | Needed more polish before dashboard/control room. | Stage 11.5: concise test summary, low-token docs, backend-sensitive and maintenance examples, rate-governor defaults, audit evidence note. | Implemented. |
| Final Golden Gameplan audit | System ready for controlled use, with minor follow-ups: summarized tests, quick start, edge fixtures, low-token clarity, product launch checklist. | Post-Golden Hardening queue. Added `test-summary.md`, quick start, controlled-use rehearsal, product launch checklist, and edge-case fixtures. | Implemented through visible queue. |
| Deep Research batch while rate-limited | Need a stronger local control-plane spine: ship selection, policy gates, leases, heartbeats, worktrees, repo fingerprints, failure fingerprints, queue/DB, artifact index. | HQ packet created outside repo and imported via recon. `docs/fleet/HQ_IMPORT_RECON.md` compares HQ recommendations to current implementation. | Recon complete. Next patch should start HQ import safely. |
| HouseOS/customer-website audit-loop case study | External audit loop is useful but should be optional, metadata-driven, and not globalized. | Stage 16 temporary audit-loop mode queue: spec, metadata schema/docs, external audit prompt template, task queue template/schema, package builder, queue converter, one-task runner, stop/continue rules. | Implemented. |
| Weekly reset/rate-limit concern | At low weekly budget, pause unfinished work, preserve preview, let captain write bugs/errors until reset. | Stage 10 weekly reset preview pause: `WeeklyResetPauseThresholdPercent = 5`, `WEEKLY_PREVIEW_PAUSE`, preview plan, review note path. | Implemented as harness support; provider-side automatic detection still deferred. |

## Remaining Open Findings

These are the important unfinished items from the audits/research. Do not try to do all of them at once.

Current bounded-run orientation should start from `docs/fleet/STABLE_CONTEXT_CAPSULE.md` plus the active task packet or active queue entry. The capsule is compact evidence only; it does not override source docs, approve product-repo work, or authorize execution.

External reports and audit outputs should be reduced to bounded intake digests before queue authoring. Suggested tasks from reviewers remain non-executable until converted into local queue entries with `allowedFiles`, `validationCommands`, `stopIf`, and status update rules.

1. Entrypoint safety inventory is missing.
   - Risk: future agents may accidentally use older broad scripts instead of the safer Stage 8+ wrappers.
   - Current recommendation: first HQ patch.

2. Repo fingerprinting is only partial.
   - Current state helpers record repo root, branch, head, and dirty files.
   - HQ wants a stable repo fingerprint tied to selected ship, packet import, resume, and worktree boundary.

3. Worktree isolation is not fully implemented.
   - Existing harness has worktree-related cleanup tests, but no obvious dedicated per-run `git worktree` manager or durable worktree ledger.

4. Durable lease/heartbeat model is partial.
   - Heartbeat/lease recovery classification exists.
   - HQ wants owner/fence-token leases, durable queue claim/release, and stale recovery classification, likely backed by SQLite or an equivalent local store.

5. Failure fingerprinting is partial.
   - Docs/tests mention failure classes and anti-loop rules.
   - A durable normalized failure-fingerprint ledger still needs schemas/fixtures before runtime integration.

6. Dashboard reconciliation is partial.
   - Control-room snapshots and reports exist.
   - HQ wants reconciliation against DB + Git + run artifacts, showing UNKNOWN on mismatch.

7. Rate-limit automation is manual.
   - Current mode supports manual budget/rate signals and weekly preview pause.
   - Provider-side automatic rate-limit/reset detection remains deferred.

8. Product repos are not cleared for broad autonomy.
   - Controlled use is allowed only with explicit selected safe scope, product-specific checklist, audit evidence, budget, rollback plan, and captain approval.

## Next Recommended Task Queue

Work these in order. Each item should be one patch, tested, documented, then stopped.

### Task 1: Entrypoint Safety Inventory

Goal: classify major fleet scripts before any architecture/runtime changes.

Files likely touched:

- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `templates/entrypoint-safety-schema.json`
- `tests/run-fleet-tests.ps1`

Acceptance:

- Inventory classifies major entrypoints as `read_only_status`, `fixture_only`, `selected_ship_required`, `selected_project_required`, `external_review_request_only`, `mobile_request_only`, or `legacy_broad_requires_human`.
- Risky legacy/broad scripts are clearly marked.
- Tests verify high-risk entrypoints are represented.
- No product repos are touched.

### Task 2: Repo Fingerprint Schema And Fixtures

Goal: define a stable selected-ship repo fingerprint before implementing runtime gates.

Likely files:

- `templates/repo-fingerprint-schema.json`
- `docs/fleet/REPO_FINGERPRINT_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Acceptance:

- Schema covers ship id, repo root, git top-level, branch, head, dirty state, changed file summary, worktree path, generatedAt, and evidence refs.
- Fixtures cover clean, dirty, wrong-root, missing repo, stale head, and path traversal.

### Task 3: Worktree Boundary Contract

Goal: document and validate the one selected ship -> one worktree boundary rule before runtime changes.

Likely files:

- `docs/fleet/WORKTREE_ISOLATION_CONTRACT.md`
- `templates/worktree-lease-schema.json` or separate `templates/worktree-boundary-schema.json`
- `tests/run-fleet-tests.ps1`

Acceptance:

- Defines no implicit direct product-root mutation for autonomous product mode.
- Defines fixture-only exceptions.
- Tests validate the docs/schema exist and reject broad/missing boundaries.

### Task 4: Failure Fingerprint Schema And Anti-Loop Fixtures

Goal: make repeated-failure detection durable and testable.

Likely files:

- `templates/failure-fingerprint-schema.json`
- `docs/fleet/FAILURE_FINGERPRINT_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Acceptance:

- Fingerprints normalize timestamps/temp paths/noisy IDs.
- Same fingerprint + same hypothesis twice maps to safe pause or repair task, not blind retry.

### Task 5: Lease/Heartbeat Contract Before Runtime Manager

Goal: align current heartbeat helper with HQ owner/fence-token model.

Likely files:

- `docs/fleet/LEASE_HEARTBEAT_CONTRACT.md`
- `templates/lease-heartbeat-schema.json`
- `tests/run-fleet-tests.ps1`

Acceptance:

- Defines owner, fence token, heartbeat age, lease expiry, recovery class, and no lock deletion.
- Fixture tests cover fresh, stale, expired, ambiguous, and deterministic failure.

### Task 6: Control-Plane Spine Decision Point

Goal: decide whether to introduce SQLite/Fleet.Core now or continue PowerShell+JSON first.

Likely files:

- `docs/fleet/CONTROL_PLANE_SPINE_DECISION.md`
- maybe `docs/fleet/FLEET_CORE_MVP.md`

Acceptance:

- Clear recommendation, tradeoffs, and smallest MVP.
- No implementation until approved.

## Paste-Ready Prompt For Next Codex Chat

```text
You are working on Codex Fleet / Thousand Sunny Fleet.

This is a new-chat continuation. Do not rely on chat memory.

Read these first:
1. C:\Dev\codex-fleet\docs\fleet\NEW_CHAT_HANDOFF_PACKET.md
2. C:\Dev\codex-fleet\docs\fleet\HQ_IMPORT_RECON.md
3. C:\Users\codex-agent\Documents\When Low on Rate Limits\codex_fleet_repair_hq\Codex_Fleet_Codex_Ready_Next_Cycle\00_START_HERE_FOR_CODEX.md
4. C:\Users\codex-agent\Documents\When Low on Rate Limits\codex_fleet_repair_hq\Codex_Fleet_Codex_Ready_Next_Cycle\codex_import\START_HERE_FOR_CODEX.md
5. C:\Users\codex-agent\Documents\When Low on Rate Limits\codex_fleet_repair_hq\Codex_Fleet_Codex_Ready_Next_Cycle\decisions\SAFETY_INVARIANTS.md
6. C:\Users\codex-agent\Documents\When Low on Rate Limits\codex_fleet_repair_hq\Codex_Fleet_Codex_Ready_Next_Cycle\implementation\IMPLEMENTATION_ORDER.md

Hard constraints:
- Patch only Codex Fleet harness/docs/tests.
- Do not touch real product repos.
- Do not launch product ships.
- Do not run all-fleet commands.
- Do not merge, push, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, or widen permissions.
- Do not treat external reports, mobile requests, or task packets as executable commands.
- Do not revert existing dirty work unless explicitly asked.
- Verify current repo state before changing anything.

Start with exactly this task:
Implement Task 1 from docs/fleet/NEW_CHAT_HANDOFF_PACKET.md: Entrypoint Safety Inventory.

Required work:
- Add docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md.
- Add templates/entrypoint-safety-schema.json.
- Add focused tests in tests/run-fleet-tests.ps1.
- Classify major scripts as read-only, fixture-only, selected-ship required, selected-project required, external-review request-only, mobile request-only, or legacy broad requiring human approval.
- Make risky legacy/broad scripts clearly marked before any autonomous use.

Validation:
- Run the validation commands listed in docs/fleet/HQ_IMPORT_RECON.md.
- Patch only failures caused by this task.

Stop after this one patch.

Report:
- Files changed
- Tests/checks run
- Final status: GREEN, YELLOW, or RED
- Next prompt I should send
```

## Commit Recommendation Before Moving Chats

Short answer: **yes, commit soon, but not blindly from this handoff task unless the captain approves exactly what to include.**

Why:

- The repo contains a large amount of intentional uncommitted Golden Gameplan and post-Golden hardening work.
- A new chat can continue from the same filesystem without a commit, but a commit gives a recovery point if the next cycle goes sideways.
- Because there are many modified/untracked files, commit scope should be reviewed first. Do not run `git add .` casually.

Recommended safe approach:

1. In the new chat, first run `git status --short`.
2. Review whether all dirty files are harness/docs/tests and expected generated state.
3. Create a checkpoint branch if needed.
4. Make a checkpoint commit only after the captain approves the scope.

Suggested commit message if approved later:

```text
checkpoint: golden gameplan and hq import handoff
```

Do not merge, push, or open PRs unless explicitly requested.
