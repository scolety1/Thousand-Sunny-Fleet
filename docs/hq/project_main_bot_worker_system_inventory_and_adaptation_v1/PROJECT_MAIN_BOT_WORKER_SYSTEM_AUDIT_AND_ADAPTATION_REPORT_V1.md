# Project Main Bot Worker System Audit And Adaptation Report V1

## Verdict

`YELLOW_PARTIAL_TSF_BOT_ORCHESTRATION_FOUND_ADAPTATION_NEEDED`

## Short Answer For Tim

TSF already has many of the parts needed for a Project Main Bot and worker system: mission packets, preflight, approval ledger, foreground lifecycle runner, worker instruction packets, verifier, preservation, HQ escalation schema, lane taxonomy, project-management packets, external auditor roles, and console/inbox concepts.

It does not yet have one unified Project Main Bot that owns one project's goal, state, routing, loop prevention, and worker assignment. The safest move is adaptation, not rebuild.

## What Already Exists

- `tools/codex-fleet-enforcement-kernel.ps1` and related wrapper scripts provide the foreground enforcement spine.
- `tools/Invoke-TsfMissionLifecycle.ps1` proves one mission can move through preflight, approval check, worker instruction, verifier, and preservation.
- `tools/New-TsfMissionPacket.ps1` can author structured mission packets.
- `docs/hq/enforcement_kernel/overnight_hardening_batch_v2/hq_escalation/` prepares HQ escalation packets without API calls.
- `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`, `TSF_SAFE_STOP_ESCALATION_MATRIX_V1.md`, and `TSF_BLOCKER_RECOVERY_LOOP_V1.md` define autonomy, stop states, and loop prevention.
- `docs/fleet/TSF_OPERATING_MODEL.md` and `TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md` define projects, tracks, assignments, autonomy profiles, and question queues.
- `tools/codex-fleet-lanes.ps1` and specialized-lane docs define lane classification.
- `tools/codex-fleet-external-agent.ps1` and external-agent docs define reviewer roles.
- Fleet Console docs and daily-driver files define the future UI/status/inbox shape.

## What Should Be Adapted

Adapt the existing kernel and project-management system into a Project Main Bot layer:

- use mission schema as the worker packet base
- use mission authoring helper as the Translator Helper backend
- use lane resolver for worker routing
- use project-management helper for project/track/assignment state
- use HQ adapter and escalation packet schema for major strategy choke points
- use verifier and preservation packet writer for every worker handoff

## What Is Missing

- Project Main Bot as a named role and state owner
- Translator Helper as a first-class intake role
- role-aware mission packet fields
- worker permission profile validation
- lane collision validator
- persistent project conversation state
- Operator Console implementation
- API/ChatGPT HQ transport

## What Should Not Be Rebuilt

Do not rebuild:

- mission schema
- approval ledger
- preflight validator
- post-run verifier
- preservation packet writer
- specialized lane taxonomy
- external audit role prompts
- project management packet concepts

These should be wrapped and connected, not replaced.

## Proposed Final Architecture

```text
Tim
  -> Translator Helper
  -> Project Main Bot
  -> TSF Runtime Kernel
  -> Specialized Worker Bots
  -> Auditor / Verifier / Preservation
  -> ChatGPT/API HQ only for major choke points
```

## Role List

The V1 role registry preserves 18 roles:

1. Project Main Bot
2. Translator Helper Bot
3. Context / Memory Steward
4. Parallel Lane Coordinator
5. Organizer Worker
6. Builder Worker
7. UI Builder Worker
8. AI Builder Worker
9. Stats/Data Worker
10. Tester Worker
11. Auditor Worker
12. Export Creator Worker
13. Researcher / Source Tracer Worker
14. Verifier Worker
15. Refactor Worker
16. Documentation Worker
17. Release / Preservation Worker
18. ChatGPT/API HQ Escalation Judge

## Authority Model

The Project Main Bot may decide routine TSF-local routing, worker selection, context freshness, and validation paths. Workers may decide only inside mission scope. The TSF kernel enforces scope and approvals. The verifier fails closed. HQ gives strategy evidence only. Tim approves true restricted gates.

## How This Reduces Tim As Router

Tim should no longer need to decide whether a task is trace, builder, tester, auditor, verifier, or HQ work. The Project Main Bot should infer that from mission intent and TSF-local evidence, then produce one bounded mission packet or one exact approval packet.

## Recommended Next Step

Run a bounded build lane for a Project Main Bot mission-intake adapter:

- add optional role fields to mission schema
- create a role-profile validator
- create a mission-intent-to-packet adapter
- add fixtures for at least source-trace, docs builder, tester, verifier, and Tim-required cases
- keep it foreground-only
- no UI, API, persistent runner, product repo access, Codex CLI execution, push, or merge

## Restricted-Action Confirmation

This audit did not start background runners, invoke Codex CLI, mutate canonical NWR, mutate product repos, read normal NWR packets, push, merge, deploy, install packages, run migrations, access secrets, use PrivateLens, run all-fleet, open network ports, create credentials, change app wiring, rankings, formulas, source truth, recommendations, or hidden sort.
