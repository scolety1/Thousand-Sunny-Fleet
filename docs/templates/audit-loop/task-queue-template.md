# Audit Loop Task Queue Template

Use this template when an external audit report is converted into bounded Audit Loop Mode tasks. Each task must be small enough to run alone, must have focused checks, and must not become a nested audit loop.

## Queue Rules

- Convert only specific, actionable, in-scope audit findings.
- Reject giant "fix everything" tasks.
- Reject nested audit loops unless package evidence is genuinely missing.
- Respect the project metadata `maxTasks` limit.
- Skip repeated accepted limitations.
- Keep HouseOS/customer-website rules local to HouseOS metadata.
- Every task needs proof and a clear `stopIf` condition.

## Task Fields

| Field | Meaning |
| --- | --- |
| `id` | Stable task identifier. |
| `title` | Short name for the issue. |
| `dispatchPhrase` | Exact captain prompt for starting this one task. |
| `goal` | One concrete outcome. |
| `readList` | Files or docs to inspect first. |
| `workList` | Files, docs, or tests this task may edit. |
| `acceptanceCriteria` | What must be true at the end. |
| `requiredChecks` | Commands or checks to run. |
| `commitExpectation` | `none`, `optional`, `one-commit`, or `captain-decides`. |
| `riskLevel` | `low`, `medium`, or `high`. |
| `notes` | Reviewer context. |
| `stopIf` | Conditions that stop the task. |
| `proof` | Evidence to record back into the queue. |

## Valid Example

```json
{
  "id": "audit-loop-queue-template",
  "title": "Add bounded audit-loop task queue template",
  "dispatchPhrase": "Start Audit Loop task audit-loop-queue-template from docs/codex/TASK_QUEUE.md.",
  "goal": "Document the standard shape for converting audit findings into one-task-at-a-time work.",
  "readList": [
    "docs/golden-gameplan/16-audit-loop-mode/audit-loop-mode-spec.md",
    "docs/golden-gameplan/16-audit-loop-mode/metadata.md"
  ],
  "workList": [
    "docs/templates/audit-loop/task-queue-template.md",
    "templates/audit-loop-task-schema.json",
    "tests/run-fleet-tests.ps1"
  ],
  "acceptanceCriteria": [
    "Template includes all required fields.",
    "Schema parses as JSON.",
    "Tests assert required fields."
  ],
  "requiredChecks": [
    ".\\tests\\run-fleet-tests.ps1"
  ],
  "commitExpectation": "captain-decides",
  "riskLevel": "low",
  "notes": "Docs/templates/tests only. No product repos or ships.",
  "stopIf": [
    "The task requires product-specific decisions.",
    "The task would touch real product repos."
  ],
  "proof": [
    "Template path.",
    "Schema path.",
    "Passing test output."
  ]
}
```

## Rejected Vague Example

```json
{
  "title": "Fix everything from the audit",
  "goal": "Make the project better",
  "requiredChecks": []
}
```

Reject this because it has no bounded scope, no explicit files, no required checks, no stop condition, no proof, and no way to know when the task is done.

## Task Contract V2 Mapping

Audit Loop tasks do not replace Task Contract V2. When an audit task is converted into a Fleet implementation task, map:

- `goal` to `User pain` and `Change`.
- `workList` to `Target` and `scope`.
- `acceptanceCriteria` to `Acceptance`.
- `requiredChecks` to `Check`.
- `stopIf` to `Stop if`.
- `proof` to `Proof`.
- `riskLevel` to `risk`.

If the mapping is unclear, stop and ask for a narrower task instead of guessing.
