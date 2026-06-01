# Golden Gameplan Definitions

This document defines the words used throughout the Golden Gameplan.

## Fleet

The Codex Fleet control system in `C:\Dev\codex-fleet`. It contains the scripts,
policies, tests, project registry, launchers, reviewers, and reporting tools.

## Ship

A project managed by the fleet. A ship usually has:

- a source repository
- `docs/codex/TASK_QUEUE.md`
- fleet reports
- run locks or state files
- build/test/runtime commands
- project-specific guardrails

## Captain

The user. The captain sets priorities, approves taste decisions, and authorizes
high-risk actions.

## Run

One bounded execution pass on one or more ships. A run may attempt one or more
tasks, but it must produce evidence before the fleet decides what to do next.

## Phase

A small implementation unit inside a stage. A phase should be narrow enough that
the required files, tests, and stop point are clear.

## Stage

A larger upgrade area made of multiple phases. Stages are completed in order
unless a later stage is explicitly pulled forward for planning only.

## Audit Package

A zip or folder of evidence prepared for a human or external ChatGPT agent. It
should be small, deterministic, and safe to share. It should include enough
context to review the current system without including secrets or generated
dependency folders.

## External Task Packet

A structured response from an outside auditor or ChatGPT agent. The fleet should
validate it before adding anything to a ship's task queue.

## Taste Gate

A stop point where deterministic checks pass, but the remaining decision is
subjective: design direction, brand feel, copy tone, product taste, or business
priority.

## Repair

A bounded follow-up action caused by a deterministic failure such as a broken
build, failed test, stale lock, missing evidence, or invalid task.

## Park

Stop scheduling work for a ship because it is done enough, waiting for taste, or
not currently worth more model budget.

## Rate Governor

The future rate-limit safety layer. It should slow down at low budget, safe-land
ships before exhaustion, and resume paused ships after reset when allowed.

## Canonical Evidence

The standard files every run should eventually produce:

```text
docs/codex/RUN_RESULT.json
docs/codex/RUN_SUMMARY.md
docs/codex/EVIDENCE_INDEX.md
```

These names are planning targets until the relevant Golden Gameplan stages are
implemented.

