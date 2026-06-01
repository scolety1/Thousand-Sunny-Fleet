# Golden Gameplan Stage 16: Audit Loop Mode

## Purpose

Audit Loop Mode is an optional, opt-in workflow for projects that benefit from compact external review cycles. It captures the pattern that worked in the HouseOS Customer Website Builder loop without making that pattern mandatory for every Codex Fleet project.

The mode is meant to support this bounded rhythm:

1. Codex implements a scoped task.
2. Codex prepares a compact audit package and prompt.
3. A read-only external reviewer audits the package.
4. The audit report is converted into a short task queue.
5. Codex executes one queued task at a time with focused checks and proof.
6. The loop stops when the audit finds no actionable issues or only accepted limitations remain.

## Non-Goals

- Do not make Audit Loop Mode the default Fleet workflow.
- Do not copy HouseOS Customer Website Builder rules into global policy.
- Do not launch product ships from this stage.
- Do not implement phone, remote, or external-agent automation here.
- Do not merge, push, deploy, delete locks, or touch real product repos.
- Do not treat external audits as executors. They are reviewers only.

## Inputs

- Audit-loop metadata for the selected project.
- A declared project or ship scope.
- Runtime scope policy and safety rules.
- A list of high-signal files to include in the package.
- Accepted limitations that should not keep reappearing as new tasks.
- Focused checks for each queue task.
- A maximum task count for each audit-to-queue conversion.

## Outputs

- `audit-loop-mode-spec.md`
- Optional metadata/schema docs in later phases.
- External audit prompt template in later phases.
- Task queue template and task schema in later phases.
- Audit package builder and queue converter in later phases.
- One-task runner guidance in later phases.
- Captain guide and checkpoint in later phases.

## Phase Plan

### Phase 1: Spec and Boundaries

Define Audit Loop Mode as an optional workflow. Document reusable primitives, HouseOS-specific boundaries, audit package contents, prompt rules, queue shape, stop/continue rules, and anti-loop criteria.

### Phase 2: Metadata

Add a metadata schema and docs so each project can declare surfaces, safe data sources, forbidden sources, default checks, max tasks, risk tier, and accepted limitations.

### Phase 3: External Audit Prompt Template

Create a reusable prompt template that tells an external reviewer what to inspect, what to ignore, how to report verdicts, and how many tasks to recommend.

### Phase 4: Queue Task Format

Create a bounded task format for converting audit findings into one-task-at-a-time implementation work.

### Phase 5: Package Builder

Implement a fixture-safe package builder that reads metadata, includes only declared high-signal files, writes a manifest and prompt, and excludes forbidden paths.

### Phase 6: Queue Converter

Implement a dry-run converter that accepts structured audit findings, validates scope and duplicate caveats, and writes a bounded queue.

### Phase 7: One-Task Runner

Add a safe runner pattern for executing exactly one audit-loop task with focused checks, proof, and queue updates.

### Phase 8: Captain Guide and Checkpoint

Write the captain-facing guide, link the mode from the Golden Gameplan index, and record final GREEN/YELLOW/RED readiness.

## Safety Rules

- Audit Loop Mode is opt-in.
- External reviewers provide analysis, not execution.
- Product-specific rules stay inside product metadata or local docs.
- Accepted limitations should be recorded and should not create endless repeat tasks.
- A dirty repo must be paired with reviewable diffs or source snapshots.
- Every implementation task needs a focused check and proof.

## Completion Criteria

Stage 16 is ready when a captain can choose this mode for a suitable project, generate a compact review package, convert a structured audit into a short safe queue, execute one task at a time, and stop without looping once the remaining findings are non-actionable or accepted.
