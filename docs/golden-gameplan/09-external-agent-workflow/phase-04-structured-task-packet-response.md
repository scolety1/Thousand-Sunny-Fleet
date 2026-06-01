# Stage 9 Phase 4 Prompt: Structured Task Packet Response

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 4 only: Structured Task Packet Response.

Goal:
Define the exact response format external agents should return when they recommend new tasks.

The response should include:
- auditId
- agentRole
- ship
- baseCommit
- verdict
- findings
- rejectedIdeas
- taskPacket
- captainQuestions

Task packet tasks should include:
- id
- title
- priority
- risk
- lane
- userPain
- target
- change
- guardrails
- acceptance
- proof
- stopIf
- checkCommand

Guardrails:
- External task packets are suggestions until fleet validation accepts them.
- Packets must not include forbidden scopes.
- Packets must not assume stale commits.
- Packets must not request direct merge/push/deploy.

Acceptance:
- Structured response template exists.
- Example valid response exists.
- Example rejected response exists.
- It maps cleanly to Stage 4 task packet ingestion.

Proof:
Show response schema/template and examples.
```

## Notes

This keeps the review loop from turning back into unstructured chat paste.

## Implementation Status

Status: GREEN

Implemented in `docs/templates/external-agent-workflow/structured-response-template.json`, `valid-response-example.json`, `rejected-response-example.json`, and response validation tests.
