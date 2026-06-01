# Stage 13 Phase 4 Prompt: Idea Intake And Task Drafting

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 4 only: Idea Intake and Task Drafting.

Goal:
Define how the mobile console captures user ideas without immediately turning every thought into a task.

Idea intake should support:
- rough idea
- target ship if known
- lane if known
- urgency
- user pain
- desired outcome
- do-not-do notes
- needs research flag
- needs captain follow-up flag

Idea statuses:
- CAPTURED
- NEEDS_CLARIFICATION
- READY_FOR_TASK_DRAFT
- DRAFTED
- DEFERRED
- REJECTED

Task drafting should:
- convert only clear ideas into Task Contract V2 candidates
- mark unclear ideas for clarification
- avoid broad redesigns without approval
- avoid immediate queue mutation unless explicitly approved

Guardrails:
- Ideas are not tasks by default.
- Do not append to TASK_QUEUE.md automatically in this docs stage.
- Do not start coding from an idea message.
- Do not lose the original wording.

Acceptance:
- Idea intake schema/spec exists.
- Examples include quick idea, vague idea, high-risk idea, and ready-to-draft idea.
- The spec explains how ideas later become validated task packets.

Proof:
Show idea intake spec and examples.
```

## Notes

This gives the user a place to toss good ideas while traveling without derailing the fleet.

## Implemented Idea Record

Idea capture writes:

```text
ideaId
sourceCommandId
capturedAt
originalMessage
targetShip
lane
urgency
status
needsResearch
needsCaptainFollowUp
queueMutationAllowed = false
nextStep
```

Examples:

- Quick idea: `Idea for Bottlelight: add a private dining inquiry card`
  - `READY_FOR_TASK_DRAFT`
  - no queue mutation
- Vague idea: `make the manager thing better`
  - `NEEDS_CLARIFICATION`
- High-risk idea: `add Stripe billing to the menu site`
  - `NEEDS_CLARIFICATION`
  - high-risk local approval required later
- Ready-to-draft idea: `Idea for KeeperLab: add CSV fixture for rookie value`
  - can become a Task Contract V2 candidate inside a validated task packet

Ideas become tasks only after later local validation. The original wording is
preserved.
