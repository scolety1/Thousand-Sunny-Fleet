# Away-Safe Microtask Packet

Prepared: 2026-06-13

Evidence only; not executable authority or approval.

## Purpose

Use this packet when Tim is away and wants Codex Fleet to take one small Fleet-only task without product work. It is a reusable prompt packet, not runtime authority. It does not approve product repo access, PrivateLens changes, proof runs, all-fleet execution, overnight runners, package installs, migrations, remote access configuration, secrets handling, phone approvals, runtime command binding, push, merge, deploy, or future authority.

## Copy/Paste Prompt

```text
Run one Codex Fleet away-safe microtask.

Repo:
<Fleet repo path>

Rules:
- Do exactly one Fleet-only task, then stop.
- Do not touch PrivateLens or any product repo.
- Do not run proof runs.
- Do not push, merge, deploy, install packages, run migrations, configure remote access, store secrets, run all-fleet, run overnight, approve phone actions, or bind runtime commands.
- Do not start a second task.
- Local commit is allowed only if this prompt explicitly permits it, the task is GREEN, tests pass, and only allowed files changed.
- If local commit is not explicitly permitted, leave validated changes unstaged and uncommitted.

Baseline first:
- git status --short
- codex --version
- powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1

If baseline fails, stop BLOCKED.

Selection:
- Pick the first not-done task from the supplied away-safe task list.
- Confirm its allowed files before editing.
- Patch only those allowed files.
- Do not infer a second task from nearby queue prose.

Continue only if GREEN:
- Run the task validation exactly as listed.
- If validation fails, patch only failures caused by this task and rerun validation.
- If the same uncertainty, failing validation, missing context, or scope question appears twice, stop and report BLOCKED for HQ repacketization.
- If validation cannot be made GREEN without broadening scope, stop and report BLOCKED.

Forbidden while away:
- product repo access or mutation
- PrivateLens mutation
- proof-run execution
- push, merge, deploy, release, or staging
- package installs or dependency updates
- migrations
- remote access configuration
- secrets, tokens, credentials, PINs, passwords, MFA material, recovery codes, keys, or private device identifiers
- all-fleet execution
- overnight runner execution
- phone/dashboard approval or execution authority
- runtime command binding
- lock deletion or permission widening

Final report:
- selected task
- files changed
- commit hash if committed
- checks run
- GREEN/YELLOW/RED
- working tree status
- stop signs encountered, if any
- exact next prompt

Stop after one task.
```

## Use Conditions

This packet is appropriate only for Codex Fleet docs/tests/fixtures/harness work with a small allowed file list and known validation command. It is not appropriate for product repos, proof runs, package management, deploy work, remote access setup, secret handling, or any task that needs Tim to choose a path, credential, product branch, or policy exception.

## Commit Boundary

Local commit is safe only when the prompt explicitly permits local commit and all of these are true:

- baseline passed before edits
- exactly one task was selected
- changed files are limited to that task's allowed files
- `git diff --check` passed
- `tests/run-fleet-tests.ps1` passed
- no product repo or proof run was touched

Push is never included in away-safe microtask authority. A later explicit push review and push approval prompt is required.

## Anti-Loop Stop

Stop instead of looping if any of these happens twice:

- same uncertainty
- same validation failure
- same missing context
- same scope question

Report BLOCKED for HQ repacketization with the exact repeated condition.

## Larger Fleet-Only Loops

For explicitly bounded multi-iteration Fleet self-improvement, use `docs/fleet/FLEET_SELF_IMPROVEMENT_LOOP.md`. That packet preserves the one-task boundary inside each iteration, requires GREEN validation and a clean working tree before continuing, keeps model routing advisory and alias-only, and still blocks product repos, PrivateLens mutation, proof runs, push, merge, deploy, installs, migrations, remote access, secrets, all-fleet execution, overnight runners, phone approvals, and runtime command binding.

Use `docs/fleet/TSF_OPERATING_MODEL.md` for the shared project-section and mode vocabulary when an away-safe task needs to discuss Ideas / Backlog, Active / Development, Review / Release Candidate, Paused, Archived / Parked, Finished / Rolled Out, Blocked, Focus Lock, known-fix routes, or the Tim Question Queue. The operating model is evidence only and does not approve a second task or phone execution.

Use `docs/fleet/TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md` when the work is a
project-management packet with a project brain, `C:\TSF_INBOX\<project_name>\`
artifact intake, research/root files, a task queue, and an autonomy profile.
That V1 can guide `review_only`, `bounded_implementation`,
`batch_implementation`, and `away_safe` work, but remains non-executable
control-plane evidence.

## Assignment-Completion Boundary

Away Mode self-improvement should be assignment-completion based, not task-count based. The assignment definition of done is the primary completion condition. Numeric task, commit, and time limits are safety fuses only. Away Mode may work through many internal tasks if they are necessary to complete the current assignment, but it must stop on YELLOW, RED, BLOCKED, failed tests, undiagnosed timeouts, unexpected files, vague definition of done, missing validation evidence, ineligible next assignment, product repo touch, proof-run need, push/merge/deploy need, install/package need, secrets/auth/credential issues, remote access need, all-fleet need, overnight/unbounded runner behavior, phone/dashboard execution authority, runtime command binding, or repeated uncertainty.

## Status

This packet is evidence-only prompt guidance. It does not create an automation, approve unattended all-fleet work, approve overnight runners, or grant authority beyond one explicitly supplied Fleet-only microtask.
