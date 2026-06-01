# Stage 6 Phase 2 Prompt: Decision Input Normalization

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 2 only: Decision Input Normalization.

Goal:
Create a normalized decision input object from existing fleet evidence.

The decision engine should read from:
- Stage 5 ship state
- Stage 2 RUN_RESULT.json
- Stage 3 audit package metadata
- Stage 4 task packet ingest reports
- task queue counts
- quarantine reports
- safe-stop requests
- rate-limit notes
- latest build/test/runtime/review gates

The normalized input should make missing evidence explicit.

Required fields:
- ship
- state
- repoClean
- activeWorkOwned
- tasksRemaining
- validTasksRemaining
- quarantinedTasks
- deterministicGateStatus
- visualGateStatus
- copyGateStatus
- formulaGateStatus
- auditPackageReady
- externalPacketPending
- acceptedPacketReady
- rateLimitPaused
- explicitStopRequested
- explicitArchiveRequested
- blockers
- evidenceFreshness

Guardrails:
- Do not make the final decision in this phase.
- Do not execute commands from the decision.
- Missing evidence should be represented as unknown, not guessed.

Acceptance:
- A normalized input can be generated for fixture states.
- Missing evidence is visible in the input.
- Active dirty/running ships are represented conservatively.
- Focused tests pass.

Proof:
Show sample normalized inputs for READY, RUNNING, BLOCKED, and AUDIT_READY fixture ships.
```

## Notes

This phase protects the decision engine from scraping scattered Markdown directly.

## Implementation Status

Status: GREEN

Evidence:
- `templates/decision-input-schema.json`
- `tools/codex-fleet-decision.ps1`
- `New-FleetDecisionInput`
- `tests/run-fleet-tests.ps1`

Verification:
- Stage 6 tests prove structured state records normalize into decision inputs without Markdown scraping.
- The helper derives audit package, task packet, taste-gate, rate-limit, repo-clean, task-count, blocker, and evidence fields from Stage 5 state records.
