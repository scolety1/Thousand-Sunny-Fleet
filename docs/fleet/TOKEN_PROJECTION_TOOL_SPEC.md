# Token Projection Tool Spec

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Purpose

The token projection tool estimates whether a bounded Codex Fleet task is likely to fit comfortably in a single implementation run before the run starts.

It is intentionally conservative. It estimates prompt text, read-first files, validation command text, expected patch size, and output reserve. It does not call model APIs, inspect billing, verify model availability, or claim exact provider-side token accounting.

## Implemented Helper

Local helper:

```text
tools/codex-fleet-token-projection.ps1
```

Primary function:

```powershell
New-FleetTokenProjection
```

CLI example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\codex-fleet-token-projection.ps1 -PromptText "Take exactly HQ-221." -ReadFiles docs\fleet\STABLE_CONTEXT_CAPSULE.md,docs\fleet\HQ_REPAIR_TASK_QUEUE.md -ExpectedPatchTokens 6000 -AsJson
```

## Decision Labels

- `GREEN_PROCEED`: estimated usage is below 70 percent of `MaxContextTokens`.
- `YELLOW_COMPRESS`: estimated usage is at least 70 percent and below 90 percent.
- `RED_SPLIT_OR_STOP`: estimated usage is at least 90 percent.

## Safety Boundary

The helper:

- reads only explicitly named local files under the fleet root
- refuses paths outside the fleet root
- refuses sensitive-looking paths such as `.env`, secret, credential, private-key, payment, or stripe paths
- returns `evidenceOnly: true`
- returns `executes: false`
- does not touch product repos
- does not run all-fleet commands
- does not run overnight runners
- does not stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, create or send packages, bind runtime commands, or approve future work
- does not approve future work

## Intended Use

Use before:

- long one-task prompts
- external-audit intake compression
- Service Sync Studio spike runs
- queue sections with many read-first files
- validation-heavy tasks where raw logs might tempt context bloat

Do not use the estimate to skip required source files, weaken validation, broaden scope, or override stop conditions.
