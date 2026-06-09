# Service Sync Studio Spike Packet

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Goal

Build a standalone local static prototype of Service Sync Studio after an explicit later user request. The prototype should make the audience-boundary workflow tangible before any HouseOS or product-repo integration is considered.

The spike should answer:

> Does the boundary model feel useful enough to become a real HouseOS-adjacent product lane later?

## Required Read-First Files

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_HQ221_THIN_TASK_PACKET.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_MODEL_CONTRACT.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_POST_SPIKE_REVIEW_GATE.md`
- the `HQ-221 Service Sync Studio Standalone Sandbox Spike` entry in `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`

## Allowed Implementation Target

The standalone spike may create or edit files only under:

```text
.codex-local/service-sync-studio-spike/
```

The queue may be updated only for the selected Service Sync Studio spike task after validation.

## First Screen

The first screen should be the actual tool, not a landing page.

Required surfaces:

- messy manager update input
- selected fixture scenario control
- generated `manager_private` lane
- generated `staff_ready` lane
- generated `guest_safe` lane
- `blocked` lane
- `needs_human_review` lane
- boundary QA verdict and reasons
- boundary diff showing what was removed, rewritten, or held for review
- state labels that clearly distinguish draft, review, publishable, blocked, and human-review states

The prototype must not imply that anything was saved, published, staff-visible, guest-visible, synced to HouseOS, posted to a menu, sent to a website, or deployed.

## Prototype Behavior

The first spike may be deterministic and fixture-driven. It does not need model calls.

Expected behavior:

- user can choose one of the eval scenarios
- user can edit the messy input locally
- lanes update from fixture mappings or simple local deterministic logic
- boundary QA remains visible
- no network call is required
- no package install is required
- no dev server is required if static HTML is sufficient
- no product repo is touched

## Visual Direction

The tool should feel like a calm operational console for a manager before service. It should prioritize clarity, trust, and scanning over decoration.

Use compact panels, clear status chips, visible audience labels, and sober boundary language. Avoid marketing-page hero treatment, oversized explanatory prose, or anything that hides the actual workflow below the fold.

## Acceptance Criteria

- Standalone local static prototype exists under `.codex-local/service-sync-studio-spike/`.
- Prototype uses only synthetic scenarios from `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`.
- The UI shows all required lanes and boundary QA.
- State language never implies save/publish/live execution.
- Documentation inside the sandbox states the prototype is local, synthetic, and non-authoritative.
- No HouseOS repo, product repo, real data, auth, payments, secrets, deployment files, migrations, package installs, all-fleet commands, overnight runner, staging, commit, push, deploy, package creation/sending, runtime command binding, remote access, or phone approval actions are used.

## Stop Conditions

Stop before any of the following:

- HouseOS repo access
- product-repo access or mutation
- real restaurant, customer, staff, vendor, POS, menu, website, auth, payment, secret, deployment, or migration data
- live demo execution
- model call requiring secrets or live credentials
- package creation or package sending
- runtime command binding
- remote access
- phone approvals
- all-fleet execution
- overnight runner execution
- staging, commit, push, merge, deploy, installs, or migrations
- lock deletion outside the owned sandbox path
- permission widening
- files outside the HQ-221 allowed files

## Report Shape

After the future spike task, report:

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
