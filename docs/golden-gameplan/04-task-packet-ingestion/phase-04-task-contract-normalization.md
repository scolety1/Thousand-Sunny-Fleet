# Stage 4 Phase 4: Task Contract V2 Normalization

## Goal

Ensure external tasks are concrete, bounded, and compatible with Fleet task
contracts.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 4 only: Task Contract V2 normalization.

Do not implement any other Golden Gameplan phase.

Goal:
Validate or normalize accepted packet tasks into Task Contract V2 checklist lines
before they can be appended to TASK_QUEUE.md.

Before editing:
- Run .\fleet-status.ps1.
- Read docs/codex/TASK_CONTRACT_V2.md.
- Inspect generate-next-five.ps1 task output rules if useful.

Scope:
- Likely files: task packet ingest/validator script, tests/run-fleet-tests.ps1,
  maybe a shared task-quality helper.
- Do not append tasks yet unless Phase 5 is explicitly started.

Required task contract checks:
- checklist line starts as unchecked task
- user pain or equivalent is present
- target is concrete
- change is concrete
- guardrails exist
- acceptance/check command or proof exists
- scope is bounded
- risk/class/mode/impact metadata exists where required
- UI tasks include first-screen or visible proof when relevant
- analytical tasks include formula/test proof when relevant

Acceptance:
- Add tests for valid Task Contract V2 line.
- Add tests rejecting vague task lines.
- Add tests rejecting oversized multi-surface tasks.
- Add tests rejecting sensitive forbidden work.
- Add tests preserving accepted task text exactly enough for queue insertion.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Task Contract V2 itself needs changes. Document the change proposal and stop
  unless user approves updating the contract.
```

## Done When

External tasks are no weaker than fleet-generated tasks.

