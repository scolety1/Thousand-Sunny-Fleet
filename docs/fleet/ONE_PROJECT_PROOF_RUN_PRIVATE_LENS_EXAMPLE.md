# One-Project Proof Run PrivateLens Example

Prepared: 2026-06-11

Evidence only; not executable authority or approval.

## Proven Pattern

PrivateLens proved the v1 one-project proof-run pattern:

- selected project only: `PrivateLens`
- one bounded task only
- launch gate passed before Codex work
- Codex checkpoint run executed
- configured build check passed: `npm.cmd run build`
- checkpoint review returned `GREEN`
- Fleet stopped for human review
- no merge, push, deploy, product launch, all-fleet, or overnight runner occurred

## Public-Safe Project Summary

PrivateLens is a local-first privacy-focused personal data analyzer MVP built with React, TypeScript, Vite, Recharts, Lucide React, and PapaParse. The first screen remains the analysis workspace, not a landing page.

The successful proof task added a compact browser-only session confidence readout while preserving:

- browser-only CSV parsing
- seeded sample datasets
- summary stats
- automatic chart
- preview table
- column profiles
- local anomaly/insight cards
- privacy messaging
- no upload/server path

## Evidence From The Proof Run

The PrivateLens proof run ended with:

- branch: `codex/experiment-PrivateLens-20260611-010133`
- repo state: clean
- checkpoint verdict: `GREEN`
- build result: passed
- pending task count after proof: `0`
- recommended next step: stop for human review

This evidence is useful as a repeatable example. It is not approval to mutate PrivateLens again without a new one-project/one-task packet.

## Reusable Prompt Shape

```text
Use Codex Fleet for one project only.

Selected project:
PrivateLens

Selected task:
<paste exactly one unchecked task from docs/codex/TASK_QUEUE.md>

Before Codex:
- run one-project proof-run preflight
- run launch gate
- confirm Codex CLI/service_tier compatibility
- confirm clean/dirty state
- confirm task queue and build command

During run:
- one checkpoint batch only
- one selected task only
- configured build/validation only
- no all-fleet
- no overnight runner
- no package installs
- no backend/auth/payments/deploy/secrets work

After run:
- checkpoint review required
- stop for human review
- no merge, push, deploy, or second task without separate approval
```

## Current Caveat

The current PrivateLens task queue is empty after the successful proof. A new proof run must first add or select exactly one new bounded task through a separate safe request/repacketization step.

