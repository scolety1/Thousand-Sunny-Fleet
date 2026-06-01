# Golden Gameplan Stage 9: External Agent Workflow

## Purpose

Stage 9 formalizes how Codex Fleet works with outside review agents.

The goal is not to let an outside agent directly control the fleet. The goal is to let the fleet produce a clean audit package, give that package to an external reviewer, receive a structured task packet back, validate it, and then decide whether it is safe to act.

The loop should feel like:

```text
Fleet runs -> Fleet packages evidence -> external agent audits -> task packet returns -> Fleet validates -> Fleet decides next safe action
```

## Why This Matters

The user wants more autonomy, but the fleet currently stalls when it has to decide what to do next.

External agents can help with:

- issue finding
- improvement suggestions
- product taste review
- architecture review
- formula/model review
- task planning
- audit comparison from multiple perspectives

But external agents must not bypass fleet safety. Their output is advice until the fleet validates it.

## Stage 9 Outcome

At the end of Stage 9, the fleet should have:

- standard external audit roles
- prompt templates for each role
- audit package handoff instructions
- task packet response format
- multi-agent comparison rules
- validation and conflict resolution rules
- human captain review points
- reports showing what was accepted, rejected, or deferred

## Non-Goals

Do not implement these in Stage 9:

- fully automatic online agent calls
- autonomous deployment
- automatic merges
- bypassing task packet validation
- letting external agents edit repos directly
- long overnight scheduling
- mobile command interface

Those belong to later stages or manual use.

## External Agent Roles

Use these roles unless implementation finds better names:

```text
Issue Auditor
Improvement Auditor
Product Taste Auditor
Formula Auditor
Security / Scope Auditor
Tie-Breaker Auditor
```

## Core Rule

External agents may produce:

- findings
- suggestions
- task packets
- risk notes
- questions for the captain

External agents must not directly:

- edit files
- run ships
- approve sensitive changes
- merge, push, deploy
- override safe-stop or rate-limit rules

## Phase List

1. External Review Roles
2. Audit Package Handoff Prompt
3. Role-Specific Audit Prompts
4. Structured Task Packet Response
5. Multi-Agent Comparison
6. Ingest Review and Conflict Resolution
7. Captain Summary and Approval Points
8. Stage 9 Integration Check

## Acceptance For Stage 9

Stage 9 is complete when:

- external agent roles are documented
- prompts exist for each role
- task packet output format is clear
- multi-agent disagreements have a process
- accepted/rejected/deferred task packet handling is documented
- human approval points are explicit
- local harness behavior can generate prompts and validate structured responses without calling outside agents

## Hand-Off To Stage 10

Stage 10 will focus on overnight mode, rate-limit protection, auto-pausing, and scheduled/resumable runs.

## Implementation Status

Status: GREEN

Implemented on 2026-05-27.

Evidence:
- `tools/codex-fleet-external-agent.ps1`
- `new-external-agent-workflow.ps1`
- `docs/templates/external-agent-workflow/`
- `tests/run-fleet-tests.ps1`

Stage 9 remains local-only. It creates handoff prompts, validates structured external responses, and compares reports. It does not call external agents, ingest packets, launch ships, or start overnight mode.
