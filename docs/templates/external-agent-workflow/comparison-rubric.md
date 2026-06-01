# Multi-Agent Comparison Rubric

Use this rubric when multiple external reports return for the same audit package.

## Buckets

- `ACCEPT`: same bounded recommendation appears in multiple valid reports.
- `ACCEPT_WITH_EDITS`: one valid low-risk recommendation needs normalization through Stage 4.
- `DEFER`: low-priority or useful later, but not needed for the next run.
- `REJECT`: invalid, stale, forbidden scope, broad rewrite, or unsafe direct action.
- `NEEDS_CAPTAIN`: taste, business, high-risk approval, or conflicting direction.

## Rules

- Consensus does not override guardrails.
- Security/scope objections override improvement suggestions.
- Formula correctness objections override visual polish for analytical tools.
- Product taste disagreements become captain questions, not endless implementation loops.
- Human review is the final taste/approval gate, not the repair path for broken evidence.

