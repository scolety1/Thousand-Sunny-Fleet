# PrivateLens CSV Validation Proof Task

Prepared: 2026-06-12

Evidence only; not executable authority or approval.

## Purpose

Prepare exactly one bounded PrivateLens proof-run task so the one-project proof-run workflow can be exercised again safely.

This packet does not run Codex, modify PrivateLens, approve product-repo mutation, approve merge/push/deploy, bind runtime commands, run all-fleet, run an overnight runner, install packages, handle secrets, or grant future authority.

## Selected Project And Task

- ProjectId: `PrivateLens`
- Quality mode: `best_value`
- Selected task: improve CSV validation/import warnings
- Selected task count: exactly one
- Selected project count: exactly one

## Read-Only Inspection Evidence

The task boundary was based on read-only inspection of the registered PrivateLens repo:

- `package.json`
- `src/lib/parser.ts`
- `src/App.tsx`
- `src/types.ts`
- `docs/codex/TASK_QUEUE.md`

No PrivateLens files were modified during packet preparation.

## Future PrivateLens Allowed Files

The future proof run may edit only these PrivateLens files:

- `docs/codex/TASK_QUEUE.md`
- `docs/codex/NIGHTLY_REPORT.md`
- `src/lib/parser.ts`
- `src/types.ts`
- `src/App.tsx`
- `src/App.css`

`docs/codex/TASK_QUEUE.md` is allowed only to add/select/update the exact CSV validation/import warnings task. `docs/codex/NIGHTLY_REPORT.md` is allowed only for proof-run evidence after validation. App behavior edits must stay within the four `src/` files above.

The future proof-run wrapper may read `package.json` for preflight evidence. It may update Fleet-side checkpoint/report evidence only if the separately approved proof-run packet allows it.

Do not edit `package.json`, `package-lock.json`, backend/auth/payment/deploy files, router/remote-access files, generated build output, hidden credential files, or any file outside the allowed list.

## Expected Behavior

Improve CSV validation/import warnings without broadening the product:

- warn clearly on malformed CSV
- warn on missing or empty headers
- warn on inconsistent row lengths
- warn on unsupported or empty input
- preserve browser-only/local-first behavior
- preserve no upload/server path
- preserve no network calls
- preserve no persistence, local storage history, secrets, analytics, or tracking
- preserve the first screen as the analysis workspace
- avoid a broad UI rewrite, modal, wizard, landing page, or new dependency

Warnings should be useful to a first-time user importing data, but they should not block valid sample switching or valid CSV upload/paste flows.

## Future Validation Commands

Run from the PrivateLens repo during the future proof run:

```powershell
npm.cmd run build
npm.cmd run lint
```

Run from `C:\Dev\codex-fleet` before and after the future proof run as directed by the one-project workflow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fleet-proof-run-preflight.ps1 -ProjectId PrivateLens -TaskSelector "CSV validation/import warnings" -RequireSelectedTask
```

The strict selected-task preflight requires a matching unchecked task in the registered PrivateLens task queue. This packet does not add that product-repo queue entry because this planning task was not allowed to modify PrivateLens.

## Stop If

Stop before or during the future proof run if the work requires:

- secrets, tokens, credentials, PINs, passwords, MFA material, recovery codes, keys, or private device identifiers
- backend, auth, payments, deploy, or production-sensitive work
- package installs, dependency changes, or migrations
- remote access configuration or port exposure
- all-fleet execution
- overnight runner execution
- broader authority than one selected project and one selected task
- merge, push, deploy, staging, or release approval
- files outside the future PrivateLens allowed files
- unclear scope, multiple selected tasks, or no selected task
- network calls, analytics, tracking, persistence, local storage history, or server/upload behavior
- phone/dashboard UI treated as execution authority

## Required Review Stop

The future proof run must run launch gate before Codex, run exactly one selected task, run validation, run checkpoint review after Codex edits, and stop for human review before merge, push, deploy, or another task.

GREEN checkpoint evidence does not approve merge, push, deploy, product launch, package installs, all-fleet, overnight runner, phone approval, or future authority.

## Repeatable Future Prompt

```text
Use Codex Fleet for one project only.

Selected project:
PrivateLens

Selected task:
CSV validation/import warnings from docs/fleet/PRIVATE_LENS_CSV_VALIDATION_PROOF_TASK.md.

Goal:
Improve CSV validation/import warnings for malformed CSV, missing/empty headers, inconsistent row lengths, unsupported/empty input, and clear browser-only local-first reassurance.

Allowed PrivateLens files:
- docs/codex/TASK_QUEUE.md
- docs/codex/NIGHTLY_REPORT.md
- src/lib/parser.ts
- src/types.ts
- src/App.tsx
- src/App.css

Validation:
- npm.cmd run build
- npm.cmd run lint

Before Codex:
- confirm this is exactly one selected project and one selected task
- run one-project proof-run preflight
- run launch gate
- confirm Codex CLI/service_tier compatibility
- confirm repo clean/dirty state
- confirm task queue and build command

During run:
- one checkpoint batch only
- no package installs
- no backend/auth/payments/deploy/secrets work
- no network calls, persistence, analytics, tracking, or broad UI rewrite
- no all-fleet
- no overnight runner

After run:
- run validation
- run checkpoint review
- stop for human review
- no merge, push, deploy, or second task without separate approval
```
