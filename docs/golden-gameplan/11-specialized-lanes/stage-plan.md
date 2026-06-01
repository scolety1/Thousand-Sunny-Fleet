# Golden Gameplan Stage 11: Specialized Lanes

## Purpose

Stage 11 splits Codex Fleet into specialized operating lanes.

The fleet should not treat a hospitality website, a manager tool, an analytical model, a backend-sensitive change, and routine maintenance as the same kind of work.

Each lane needs different:

- task rules
- review gates
- model choices
- evidence requirements
- stop conditions
- taste gates
- overnight behavior

## Why This Matters

The fleet's biggest quality failures often came from using the wrong mental model:

- hospitality websites became feature dashboards instead of beautiful guest experiences
- manager tools became overloaded pages instead of daily operating surfaces
- analytical software needed formula truth, not visual polish first
- backend-sensitive work needed guardrails, not speed
- maintenance needed low-cost cleanup, not high-creativity reinvention

Stage 11 makes those differences first-class.

## Stage 11 Outcome

At the end of Stage 11, the fleet should have lane profiles for:

```text
Hospitality Websites
Manager / Internal Tools
Analytical Software
Backend-Sensitive Work
Maintenance
```

Each lane should define:

- purpose
- allowed task types
- forbidden task types
- required contracts
- required evidence
- recommended reviewers
- model budget mode
- done criteria
- taste/approval gates
- overnight eligibility

## Non-Goals

Do not implement these in Stage 11:

- rewriting existing ships
- launching lane-specific runs
- changing model selection scripts
- changing task queues
- deploying anything
- broad migrations

This stage defines lane policy and prompts. Later implementation can wire the policies into the fleet.

## Lane Summary

### Hospitality Websites

Public-facing, emotional, visual, mobile-first websites for restaurants, bars, events, and local hospitality brands.

Primary proof:

```text
First screen, navigation, mobile screenshot, real-feeling brand/content hierarchy.
```

### Manager / Internal Tools

Operational tools for GMs, managers, staff, kitchens, events, and service teams.

Primary proof:

```text
Daily workflow, clear next action, realistic operating data, no first-screen overload.
```

### Analytical Software

Formula-heavy, data-driven systems like Niners War Room, margin labs, forecast tools, pricing simulators, and decision engines.

Primary proof:

```text
Deterministic formulas, fixtures, tests, audit receipts, confidence rules.
```

### Backend-Sensitive Work

Auth, payments, deployment, migrations, database changes, secrets, dependencies, production data, and external API contracts.

Primary proof:

```text
Explicit approval, risk review, rollback plan, tests, security/scope audit.
```

### Maintenance

Bug cleanup, docs cleanup, dependency-safe chores, status reports, low-token tasks, and small repairs.

Primary proof:

```text
Small diff, specific issue resolved, no product churn, no broad redesign.
```

## Phase List

1. Lane Taxonomy
2. Hospitality Website Lane
3. Manager / Internal Tool Lane
4. Analytical Software Lane
5. Backend-Sensitive Work Lane
6. Maintenance Lane
7. Lane Selection and Escalation Rules
8. Stage 11 Integration Check

## Acceptance For Stage 11

Stage 11 is complete when:

- all five lane profiles exist
- each lane has allowed/forbidden work
- each lane maps to review gates
- each lane maps to evidence requirements
- each lane has overnight eligibility rules
- task prompts can reference a lane
- high-risk work is escalated out of normal autonomy

## Hand-Off To Stage 12

Stage 12 will turn these states, decisions, reports, and lanes into a dashboard/control room that the user can inspect quickly.

## Implementation Notes

Status: GREEN as of 2026-05-27.

Implemented artifacts:
- `tools/codex-fleet-lanes.ps1` defines canonical lane profiles, backend-sensitive override, lane resolver, and Markdown report formatting.
- `invoke-specialized-lane.ps1` resolves one task or a JSON fixture list into lane decisions without launching ships.
- `docs/templates/specialized-lanes/` contains profile templates and pass/fail examples.
- `tests/run-fleet-tests.ps1` contains focused Stage 11 routing and escalation coverage.

Stage 11 intentionally does not edit product task queues, launch lane-specific runs, change model selection scripts, deploy, push, merge, or touch real product repos.
