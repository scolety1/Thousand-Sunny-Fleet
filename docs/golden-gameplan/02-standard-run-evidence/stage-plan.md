# Stage 2: Standard Run Evidence

Stage 2 gives every fleet run the same evidence shape.

Stage 1 makes the fleet safer to run. Stage 2 makes every run understandable
after it finishes, fails, pauses, or parks.

## Goal

Create canonical run evidence that future stages can depend on:

```text
docs/codex/RUN_RESULT.json
docs/codex/RUN_SUMMARY.md
docs/codex/EVIDENCE_INDEX.md
```

These files should become the common language for the audit package loop, state
machine, decision engine, overnight mode, and mobile status reports.

## Why This Stage Matters

The current fleet writes many useful reports, but the outputs are inconsistent
across ships and phases. A human or external agent often has to inspect several
files to answer basic questions:

- What ran?
- What changed?
- What passed?
- What failed?
- What evidence exists?
- Is the ship safe to rerun?
- What should happen next?

Stage 2 creates one canonical run record so later automation can reason from
evidence instead of scraping vibes from scattered Markdown.

## Phase Order

1. RUN_RESULT schema
2. RUN_RESULT writer
3. RUN_SUMMARY writer
4. EVIDENCE_INDEX writer
5. Checkpoint loop integration
6. Experiment and dry-run integration
7. Failure and partial-run evidence
8. Stage 2 integration check

## Canonical Files

### `docs/codex/RUN_RESULT.json`

Machine-readable run record. Future scripts should read this before reading
human-facing reports.

### `docs/codex/RUN_SUMMARY.md`

Short human-readable summary of the latest run.

### `docs/codex/EVIDENCE_INDEX.md`

Index of evidence files, logs, screenshots, reports, and generated artifacts from
the latest run.

## Files Likely Touched During Implementation

Planning only in this document. When implementation begins, likely files include:

- `run-checkpoint-loop.ps1`
- `fleet-experiment.ps1`
- `fleet-night-report.ps1`
- `checkpoint-review.ps1`
- `runtime-verify.ps1`
- `fleet-visual-check.ps1`
- `simon-design-review.ps1`
- `robin-copy-review.ps1`
- `franky-formula-review.ps1`
- `tests/run-fleet-tests.ps1`
- new helper script or template files if useful

## Stage Exit Criteria

Stage 2 is complete when:

- every normal checkpoint run writes `RUN_RESULT.json`
- every normal checkpoint run writes `RUN_SUMMARY.md`
- every normal checkpoint run writes `EVIDENCE_INDEX.md`
- failure paths still write useful partial evidence where safe
- dry-run/experiment paths produce compatible run evidence
- tests validate schema-required fields
- tests validate success, failure, and partial-run evidence behavior
- `.\tests\run-fleet-tests.ps1` passes

## Do Not Do

- Do not build the Stage 3 audit-package zip system.
- Do not build external task packet ingestion.
- Do not build the final state machine.
- Do not build the decision engine beyond a simple optional `decisionHint` field.
- Do not change downstream product repos.
- Do not redesign existing reports unless needed to index them.

## Implementation Rule

Stage 2 should be additive. Existing reports may continue to exist. The new files
are the canonical layer above them, not a destructive replacement.

