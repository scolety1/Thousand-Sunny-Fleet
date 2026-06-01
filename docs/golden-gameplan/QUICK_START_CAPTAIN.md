# Captain Quick Start

This is the short operating guide for controlled Codex Fleet use. It is for a
captain who wants to check status, approve safe work, create audit evidence, or
pause the fleet without rereading the whole Golden Gameplan.

## Phone-Readable Commands

Use these as request phrases. They do not execute raw shell commands.

```text
status
why is ShipName blocked?
create audit package for ShipName
submit idea for ShipName: ...
approve plan PLAN-ID
reject plan PLAN-ID
resume safe after reset for ShipName
pause ShipName safely
```

Phone requests are not execution. They create request records only. The local PC
must still validate scope, state, budget, locks, packet evidence, and safety
before anything runs.

## Controlled-Use Rules

- Do not touch real product repos without explicit approval.
- Do not launch all ships by default.
- Do not merge, push, deploy, publish, delete locks, or clean user work
  automatically.
- Do not use phone commands as shell commands.
- Do not import task packets unless Stage 4 validation evidence exists.
- Do not continue when build, test, state, budget, or scope evidence is missing.
- Trust artifacts, not prose summaries.

## Safe Ship Selection

Before approving work, name the exact ship and repo. Prefer disposable fixtures
or explicitly approved safe demo ships.

Use this checklist:

- Ship name is explicit.
- Repo path is known.
- Repo is clean or the dirty files are owned and documented.
- The lane/profile is known.
- The task has a narrow target.
- The expected check command is listed.
- Rollback/no-op behavior is clear.

Stop if the request says "all ships", "everything", "make it beautiful", or
"just fix it" without a selected ship, lane, and acceptance check.

## Status First

When you are unsure, ask for status before approving work.

```powershell
.\fleet-status.ps1
.\invoke-control-room.ps1 -InputPath .\out\control-room-input.json
```

Good status evidence names:

- running ships
- blocked ships
- stale heartbeat or lease state
- budget/rate state
- latest run evidence
- latest audit package
- next safe captain action

## Fixture-Only Checks

Use fixture checks when validating the harness itself.

```powershell
.\tests\run-fleet-tests.ps1
.\invoke-final-readiness.ps1 -OutDir .\out\final-readiness
```

These checks should not launch product ships or mutate real product repos.

## Audit Packages

Create audit packages when a ship reaches a review point, when the fleet is dirty
and needs external inspection, or before moving from controlled harness use into
real product work.

```powershell
.\new-audit-package.ps1 -ConfigPath .\projects.json -Project ShipName -OutRoot .\out\audits
```

An audit package should include:

- manifest
- sanitized diffs or changed-source snapshots when the repo is dirty
- `RUN_RESULT.json`
- `RUN_SUMMARY.md`
- `EVIDENCE_INDEX.md`
- `test-summary.md` when full test logs are present
- task packet validation evidence when packet import is involved

If the package says the repo is dirty but does not include diffs or changed
source, treat it as incomplete.

## When To Stop

Stop and write a status report instead of acting when:

- selected ship scope is missing or ambiguous
- repo dirtiness is unexplained
- locks, safe-stop files, active PIDs, heartbeat, or lease state is ambiguous
- task packet evidence is missing, stale, duplicated, or invalid
- budget is low, unknown, or near weekly reset pause
- remaining work is subjective taste
- the request touches auth, payments, deployment, migrations, package files,
  secrets, production data, or external APIs without an explicit approval path

## What Must Never Be Automatic

- merge
- push
- deploy
- publish
- delete user work
- manually delete locks
- bypass packet validation
- broaden selected ships to all ships
- treat mobile approval as execution authority
- fabricate rate-limit percentages or reset times

## Repeatable Work Prompt

Use this when continuing the hardening queue:

```text
Start the next unfinished task from the Post-Golden Gameplan Hardening queue in docs/codex/TASK_QUEUE.md.
```

Use this when continuing optional audit-loop repairs:

```text
Start the next unfinished task from the Temporary Audit Loop Mode Queue in docs/codex/TASK_QUEUE.md.
```

## Deeper Docs

- `docs/golden-gameplan/00-overview/safety-rules.md`
- `docs/golden-gameplan/00-overview/runtime-scope-policy.md`
- `docs/golden-gameplan/12-dashboard-control-room/checkpoint.md`
- `docs/golden-gameplan/13-mobile-captain-console/checkpoint.md`
- `docs/golden-gameplan/14-final-hardening-stress-test/checkpoint.md`
- `docs/golden-gameplan/16-audit-loop-mode/audit-loop-mode-spec.md`
