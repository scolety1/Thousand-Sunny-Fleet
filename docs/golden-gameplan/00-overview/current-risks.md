# Current Risks

This document captures the main known risks from the three external audit
reports and prior fleet runs. These risks guide the stage order.

## Highest Priority Risks

### Unrelated Safe Stops Can Block Work

Safe-stop requests may be too global. A stop request for one ship can interfere
with unrelated experiments or dry runs.

Planned response: Stage 1, Stability First.

### Phase 13 Evidence Failure

The experiment runner has recently failed to write expected Markdown and JSON
evidence. A failed experiment must still leave evidence.

Planned response: Stage 1, then Stage 2.

### Inconsistent Evidence

Ships currently leave different combinations of reports, scorecards, logs, and
screenshots. That makes external audit and autonomous decision-making brittle.

Planned response: Stage 2, Standard Run Evidence.

### No Unified Ship State Machine

The system can report status, but it does not yet have one canonical lifecycle
state per ship that controls the next action.

Planned response: Stage 5, State Machine.

### No Validated External Task Ingestion

External agents can review audit packages, but the fleet does not yet have a
safe, structured way to ingest their task packets.

Planned response: Stage 4, Task Packet Ingestion.

### Vague Task Loops

The planner can produce tasks that are too vague, too broad, or too polish-heavy.
This creates stalls, churn, and low-quality output.

Planned response: Stage 4 task validation and Stage 7 product contracts.

### Rate-Limit Exhaustion

Overnight runs can run out of model budget halfway through and stop without a
clean resume path.

Planned response: Stage 10, Overnight Mode.

### Ambiguous Stage Boundaries

Several later stages intentionally touch nearby concepts: audit packages,
external task packets, state, decisions, autonomy, overnight mode, and mobile
commands. If these boundaries are vague, Codex may implement later-stage
behavior too early or duplicate logic.

Planned response: use `dependency-map.md` before implementation and keep each
phase scoped to its owner stage.

### Phone-Based Steering Is Missing

The captain needs to check status, capture ideas, park ships, request audit
packages, and steer safe actions while away from the desktop.

Planned response: Stage 13, Mobile Captain Console.

## Secondary Risks

- Hardcoded local paths.
- Infinite or long-running loops without retry caps.
- Silent error swallowing in PowerShell scripts.
- Dirty repo checks that conflate missing repos with changed repos.
- Heartbeat and lock race conditions.
- Default branch assumptions such as `main`.
- Safe-name collisions between similarly named ships.
- Too much information on first screens of generated websites.
- Analytical apps presenting confidence before evidence is strong enough.

## Planning Principle

Do not build the autonomy loop on top of unstable foundations.

The first implementation stage must reduce random stalls and false blockers
before adding audit packages, task ingestion, decision automation, or mobile
commands.
