# Service Sync Studio HQ-221 Thin Task Packet

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Task

Take exactly `HQ-221 Service Sync Studio Standalone Sandbox Spike`.

Take exactly HQ-221 Service Sync Studio Standalone Sandbox Spike.

## Goal

Build a standalone local static prototype of Service Sync Studio using only synthetic fixture scenarios and the model contract.

## Allowed Files

Patch only:

- `.codex-local/service-sync-studio-spike/`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`

## Read First

Read only:

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_HQ221_THIN_TASK_PACKET.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_MODEL_CONTRACT.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_SPIKE_PACKET.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_POST_SPIKE_REVIEW_GATE.md`
- the `HQ-221 Service Sync Studio Standalone Sandbox Spike` entry in `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`

Do not read the full handoff packet or whole repair queue unless exact wording conflicts and repacketization is needed.

## Acceptance

- Standalone static prototype exists only under `.codex-local/service-sync-studio-spike/`.
- Prototype uses only synthetic scenarios from `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`.
- First screen is the tool itself and includes messy manager update input, selected fixture scenario control, all five output lanes, Boundary QA verdict, boundary diff, and clear non-live state language.
- Prototype does not imply saved, published, staff-visible, guest-visible, HouseOS-synced, website-posted, menu-posted, or deployed state.
- Sandbox README states the prototype is local, synthetic, fixture-only, non-authoritative, and not HouseOS.
- No HouseOS repo, product repo, real data, auth, payments, secrets, deployment files, migrations, package installs, all-fleet commands, overnight runner, staging, commit, push, deploy, package creation/sending, runtime command binding, remote access, phone approval actions, lock deletion outside the owned sandbox path, or permission widening are used.

## Validation Commands

Run only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

## Stop If

Stop before HouseOS repo access, product-repo access, real restaurant/customer/staff/vendor data, real demo execution, model calls requiring secrets or live credentials, package creation/sending, runtime command binding, remote access, phone approvals, all-fleet execution, overnight runner execution, staging, commit, push, merge, deploy, installs, migrations, secrets/auth/payments/deploy work, deleting anything outside the exact owned sandbox path, permission widening, or files outside allowedFiles.

## Report

Report:

- task id
- sandbox path used
- files changed
- checks run
- status GREEN/YELLOW/RED
- whether any stop signs were active
- what the prototype proves
- what remains before HouseOS integration can be considered
- recommended post-spike review outcome from `docs/fleet/SERVICE_SYNC_STUDIO_POST_SPIKE_REVIEW_GATE.md`, if enough evidence exists
- next recommended prompt
