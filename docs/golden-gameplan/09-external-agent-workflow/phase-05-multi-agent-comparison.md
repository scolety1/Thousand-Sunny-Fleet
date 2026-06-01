# Stage 9 Phase 5 Prompt: Multi-Agent Comparison

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 5 only: Multi-Agent Comparison.

Goal:
Define how the fleet and captain compare multiple external audit reports.

The user may send the same audit package to three agents:
- one focused on issues
- one focused on improvements
- one focused on tie-breaking or product direction

Create a comparison process that:
- groups findings by ship and severity
- detects duplicate recommendations
- flags conflicts
- identifies consensus tasks
- identifies risky suggestions
- recommends accepted, rejected, or deferred task packets

Decision buckets:
- ACCEPT
- ACCEPT_WITH_EDITS
- DEFER
- REJECT
- NEEDS_CAPTAIN

Guardrails:
- Consensus does not override guardrails.
- High-risk tasks still require explicit approval.
- Vague tasks are rejected or rewritten.
- Taste disagreements should become captain questions, not endless work.

Acceptance:
- Comparison rubric exists.
- Example three-agent comparison exists.
- The process produces a conservative next-task plan.

Proof:
Show comparison doc and example output.
```

## Notes

This is how we use multiple agents without getting three piles of chaos.

## Implementation Status

Status: GREEN

Implemented in `Compare-FleetExternalAgentResponses` and documented in `docs/templates/external-agent-workflow/comparison-rubric.md`.
