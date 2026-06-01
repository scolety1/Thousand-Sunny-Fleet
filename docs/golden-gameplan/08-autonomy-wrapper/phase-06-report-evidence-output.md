# Stage 8 Phase 6 Prompt: Report And Evidence Output

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 6 only: Report and Evidence Output.

Goal:
Make every autonomy wrapper cycle produce a clear report.

Required reports:
- machine-readable cycle result JSON
- human-readable cycle summary Markdown
- per-ship action summary
- skipped/blocked reason list
- budget usage
- evidence paths
- next captain action

The report should answer:
- What ships were selected?
- What state was each ship in?
- What decision was made?
- What action was taken or skipped?
- What evidence supports it?
- What should happen next?

Guardrails:
- Do not hide skipped ships.
- Do not call skipped ships failed.
- Do not call taste-gated ships done.
- Do not overwrite previous reports; write timestamped output.

Acceptance:
- Reports are generated for dry run and real bounded cycle.
- Reports are phone-readable.
- JSON can be consumed by later dashboard stages.

Proof:
Show sample report paths and excerpts.
```

## Notes

This is the captain's receipt. Every autonomous step needs a receipt.

## Implementation Status

Status: GREEN

Every wrapper invocation writes a machine-readable `cycle-result.json` and a phone-readable `cycle-summary.md`. Reports include selected ships, decisions, intended/executed actions, skipped/blocked reasons, budget usage, evidence, and next captain action.
