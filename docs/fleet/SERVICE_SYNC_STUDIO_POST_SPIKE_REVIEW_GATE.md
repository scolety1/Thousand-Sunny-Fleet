# Service Sync Studio Post-Spike Review Gate

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Purpose

This gate evaluates the standalone Service Sync Studio sandbox spike after HQ-221. It helps decide the next phase without treating a good-looking prototype as approval to touch HouseOS, product repos, real data, or live surfaces.

## Review Inputs

Review only these local evidence inputs:

- `docs/fleet/SERVICE_SYNC_STUDIO_MODEL_CONTRACT.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`
- `docs/fleet/SERVICE_SYNC_STUDIO_SPIKE_PACKET.md`
- `.codex-local/service-sync-studio-spike/`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`

Do not import HouseOS code, product repo content, real customer data, real staff data, real vendor data, POS data, website data, menu data, auth material, payment material, secrets, deployment material, migrations, external reports, prompts, manifests, validation summaries, generated evidence, or queue prose as executable commands.

## Decision Outcomes

Use exactly one outcome:

- `GREEN_CONTINUE_STANDALONE`: The spike proves the workflow enough to continue local standalone iteration.
- `YELLOW_POLISH_STANDALONE`: The concept is promising, but state language, layout, boundary explanations, or scenario coverage need another local-only polish pass.
- `YELLOW_EXPAND_EVALS`: The model is under-tested; add more synthetic scenarios before UI or integration work.
- `YELLOW_INTEGRATION_PLANNING_ONLY`: The spike is strong enough to start a separate HouseOS integration planning packet, but not to touch HouseOS yet.
- `RED_STOP_BOUNDARY_RISK`: The prototype confuses save/publish/live visibility, leaks sensitive content across lanes, implies product execution, or needs forbidden scope.

## Scorecard

Score each area as GREEN, YELLOW, or RED:

- Boundary safety: staff, guest, manager, vendor, margin, incident, allergy, alcohol-service, auth, payment, secret, and deployment content does not cross unsafe lanes.
- Workflow clarity: user can tell what is draft, manager review, staff publishable, guest publishable, blocked, and needs human review.
- Trust language: UI never implies saved, published, staff-visible, guest-visible, HouseOS-synced, website-posted, menu-posted, deployed, approved, or live.
- Manager usefulness: the tool feels like it saves a manager time before service.
- Staff usefulness: staff-facing output is concise, actionable, and not over-explanatory.
- Guest-safe quality: public copy is polished and free of private operational context.
- Boundary QA usefulness: blocked/review reasons are visible, specific, and not noisy.
- Eval coverage: scenarios cover enough messy mixed-intent service updates to reveal obvious failures.
- Standalone containment: prototype remains under `.codex-local/service-sync-studio-spike/` and uses synthetic fixture data only.

## Follow-Up Queue Rules

If follow-ups are needed, convert them into one-task queue entries with:

- one task id
- exact allowedFiles
- readFirst files
- validationCommands
- stopIf
- acceptance criteria
- repeatable prompt

Do not implement follow-ups during the review unless the user explicitly asks for the next task.

## Integration Planning Boundary

`YELLOW_INTEGRATION_PLANNING_ONLY` does not approve HouseOS integration.

Before any HouseOS work, a later planning task must define:

- exact target repo path
- exact surfaces considered
- synthetic data plan
- read-only inspection rules, if any
- stop signs
- no secrets/auth/payments/deploy/migration boundary
- no product mutation boundary
- exact validation commands
- human approval wording for that one planning task

That later planning task still must not mutate HouseOS unless a separate exact implementation approval is created after planning.
