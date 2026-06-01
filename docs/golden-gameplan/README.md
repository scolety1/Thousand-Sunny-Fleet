# Codex Fleet Golden Gameplan

This folder is the master upgrade plan for turning Codex Fleet from a helpful
local automation harness into a bounded autonomous software studio.

The goal is not to make the fleet reckless. The goal is to make it evidence
driven: every run should leave clear proof, every ship should have a state, and
every autonomous decision should be explainable.

## Command Language

Use these commands to work through the plan without drifting:

```text
Write Golden Gameplan Stage 1.
Begin implementing Golden Gameplan Stage 1 Phase 1 only.
Run tests for Golden Gameplan Stage 1 Phase 1.
Patch Golden Gameplan Stage 1 Phase 1 only.
Create an audit package for Golden Gameplan Stage 1.
Resume Golden Gameplan at Stage 2 Phase 1.
```

Each implementation prompt should name one stage and one phase. If the prompt
does not name a phase, Codex should ask for the intended phase before editing
fleet code.

For unattended bounded runs, use
`00-overview/overnight-stage-run-prompt.md`. That prompt is allowed to continue
past YELLOW/RED phase results inside the approved stage range, while recording
morning repair notes. It should only stop early for safety risks, user-work
protection, or failures that make the next phase technically impossible.

## Stage Map

1. Stability First
2. Standard Run Evidence
3. Audit Package Loop
4. Task Packet Ingestion
5. State Machine
6. Decision Engine
7. Product Quality Contracts
8. Autonomy Wrapper
9. External Agent Workflow
10. Overnight Mode
11. Specialized Lanes
12. Dashboard and Control Room
13. Mobile Captain Console
14. Final Hardening and Stress Test

Optional templates after the core Golden Gameplan:

- `16-audit-loop-mode/` - opt-in Audit Loop Mode for projects that benefit from compact external review packages, structured audit findings, bounded generated queues, one-task execution, and explicit accepted limitations. This is optional and captain-approved, not the default workflow.

Before implementing any stage, read:

- `00-overview/dependency-map.md`
- `00-overview/safety-rules.md`
- `QUICK_START_CAPTAIN.md` for the short controlled-use operating guide
- the target stage `stage-plan.md`
- the target phase prompt

If a phase appears to require a later-stage capability, stop and document the
missing dependency instead of building around it.

## Current Scope

This initial commit creates only the `00-overview` docs. It does not implement
fleet code, modify fleet scripts, launch ships, or clean project repositories.
