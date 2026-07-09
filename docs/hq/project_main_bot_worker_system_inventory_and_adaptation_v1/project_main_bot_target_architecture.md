# Project Main Bot Target Architecture V1

## Verdict

TSF has reusable enforcement, lane, state, and review components, but it does not yet have one unified Project Main Bot per project.

The target is not a second runner. The target is a thin project-owner layer that turns Tim's intent into TSF mission packets, routes work to specialized workers, and refuses unsafe work through the existing TSF kernel.

## What The Project Main Bot Is

The Project Main Bot is the owner of one project conversation and one project operating state. Tim should be able to speak to that bot in normal language. The bot should remember the selected project, current goal, accepted constraints, current lane, blockers, prior handoffs, and next safe action.

It is not a shell executor, deployment tool, all-fleet launcher, proof-run launcher, or product authority. It is the routing and state layer above the TSF Runtime Kernel.

## What It Owns

- Current project goal and definition of done.
- Current project lane and worker assignment.
- Current mission packet draft and lifecycle state.
- Phase 0 existing-asset trace requirement.
- Project registration or metadata-only alias check.
- Context and memory references, including project passports, next-session cards, work-order inbox summaries, and preservation packets.
- Loop prevention, including repeated blocker detection and stale evidence checks.
- Routing between Translator Helper, workers, verifier, preservation, and HQ escalation.
- Tim Question Queue for true blockers only.

## What It May Decide Without Tim

The Project Main Bot may decide routine TSF-local technical routing when no restricted gate is crossed:

- whether a request needs Phase 0 trace before build work
- which existing TSF component to reuse
- which worker role is the safest fit
- whether a missing field means adapter, admission, null fence, validation, documentation, or no action
- whether a YELLOW review-only result is safe to preserve and move on
- whether to run one bounded local validation already allowed by a mission packet
- whether to create local TSF docs/control-plane artifacts
- whether to create a local checkpoint commit when scope is exact and validation passes

## What It Must Escalate

It must escalate before:

- push or merge
- deploy
- installs or migrations
- secrets, auth, payments, credentials, or account changes
- proof runs
- all-fleet commands
- background, persistent, overnight, daemon, scheduler, or watchdog runners
- product repo access or mutation without exact approval
- canonical NWR inspection or mutation
- normal NWR packet reads unless explicitly scoped
- PrivateLens access or mutation
- model, ranking, formula, source-truth, recommendation, app wiring, or hidden-sort promotion
- API calls or ChatGPT/API HQ transport setup

## Interaction With The TSF Kernel

The Project Main Bot should never bypass the kernel. It should:

1. Translate Tim input into mission intent.
2. Apply Phase 0 existing-asset/source-trace gate.
3. Select worker role and lane.
4. Author a mission packet through the existing mission schema.
5. Run foreground preflight.
6. Check approval ledger matches.
7. Generate worker instruction packet.
8. Let a bounded worker perform only approved work.
9. Run post-run verifier.
10. Write preservation/handoff packet.
11. Classify final decision as GREEN, YELLOW, RED, or TIM_REQUIRED.

## Worker Calling Model

Workers receive only bounded missions. They do not receive broad project ownership. A worker packet should include:

- role id
- mission id
- repo/path
- allowed reads
- allowed writes
- forbidden reads and writes
- forbidden actions
- expected artifacts
- validation
- verifier
- stop conditions
- exact escalation triggers

Workers return evidence, not authority. The verifier and preservation layer close the loop.

## Loop Prevention

The Project Main Bot should prevent loops by:

- checking existing assets before build work
- rejecting repeated blocker-only reports when a safe unblock artifact can be built
- tracking repeated failure fingerprints
- limiting blocker recovery to one bounded pass per lane
- preserving state before cleanup or reruns
- using explicit done-enough finish lines
- excluding optional questions that do not block the finish line
- escalating to HQ only for major ambiguous choke points

## How It Reduces Tim As Router

Tim should not have to decide whether a request is docs, kernel, lane, worker, verifier, or HQ work. The Project Main Bot makes that routing decision from TSF-local evidence. Tim is asked only for true authority gates, product direction, conflicting source truth, or unsafe ambiguity that cannot be resolved locally.

## Near-Term Adaptation

The next build should add a thin Project Main Bot packet/role adapter that reuses:

- `mission_schema_v1.json`
- `tools/New-TsfMissionPacket.ps1`
- `tools/Invoke-TsfMissionLifecycle.ps1`
- `tools/codex-fleet-enforcement-kernel.ps1`
- `tools/codex-fleet-project-management.ps1`
- `tools/codex-fleet-lanes.ps1`
- HQ escalation packet schema
- project passports and next-session status files

It should not implement a persistent runner, desktop UI, API bridge, or direct Codex CLI worker execution without separate exact approval.
