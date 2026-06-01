# Golden Gameplan Stage Index

This index names each stage and the reason it exists. Detailed prompts are
written one stage at a time.

Before implementation, use `dependency-map.md` to confirm stage ownership and
`safety-rules.md` to resolve conflicts. If two stages seem to cover the same
behavior, the dependency map is the source of truth.

## Stage 1: Stability First

Patch the reliability issues that can cause false stops, missing evidence,
unbounded loops, dirty-state confusion, heartbeat races, and path assumptions.

## Stage 2: Standard Run Evidence

Make every run produce canonical evidence: `RUN_RESULT.json`,
`RUN_SUMMARY.md`, and `EVIDENCE_INDEX.md`.

## Stage 3: Audit Package Loop

Create deterministic audit packages that can be sent to external ChatGPT agents
or reviewed by the captain.

## Stage 4: Task Packet Ingestion

Validate and ingest structured external task packets safely.

## Stage 5: State Machine

Give every ship a clear lifecycle state: ready, running, reviewing, repairing,
blocked, taste gate, parked, or archived.

## Stage 6: Decision Engine

Centralize decisions so the fleet knows when to run again, repair, park, ask for
taste, or request external audit.

## Stage 7: Product Quality Contracts

Prevent overwhelming or vague software output with demo promises, first-screen
contracts, done contracts, and analytical trust contracts.

## Stage 8: Autonomy Wrapper

Connect run, evidence, audit package, task packet, decision, and rerun behavior
into one bounded loop command.

## Stage 9: External Agent Workflow

Formalize the three-agent audit cycle: issue auditor, improvement auditor, and
decision architect.

## Stage 10: Overnight Mode

Make long runs safe with budgets, non-material-change stops, rate governor,
safe-landing, auto-resume, and morning reports.

## Stage 11: Specialized Lanes

Separate operating modes for hospitality websites, manager/internal tools,
analytical software, backend-sensitive work, and maintenance.

## Stage 12: Dashboard and Control Room

Create a readable control-room view of ship states, screenshots, evidence, next
actions, blockers, and taste gates.

## Stage 13: Mobile Captain Console

Allow phone-friendly status checks, idea capture, safe commands, rate-limit
alerts, audit requests, and mobile digests.

## Stage 14: Final Hardening and Stress Test

Run full-loop simulations, failure injection, overnight trials, audit review,
rollback checks, and final readiness validation.
