# Remote Travel Landing Checklist

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Purpose

Use this compact checklist after travel resumes and before starting any Codex Fleet work from a phone, laptop, or human-controlled remote desktop session.

This checklist does not configure remote access, run the off-network test, execute Codex work, approve phone actions, bind runtime commands, touch product repos, run all-fleet, run overnight, stage, commit, push, deploy, install packages, run migrations, store secrets, delete locks, widen permissions, or grant future authority.

Remote access grants no extra authority. Phone edits are not approvals.

## Phone-Only Status And Request Actions

Safe from phone:

- Open the hosted Phone HQ dashboard.
- Read latest Fleet status.
- Read today log.
- Read the request-only rules.
- Capture one narrow idea in the quick mission request file.
- Request a cooperative emergency stop with non-secret fields only.

Not safe from phone:

- product repo access or mutation
- all-fleet execution
- overnight runner execution
- deploy
- stage
- commit
- push
- installs
- migrations
- secrets, tokens, credentials, PINs, passwords, MFA material, recovery codes, keys, or private device identifiers
- lock deletion
- permission widening
- phone approval
- runtime command binding
- remote access configuration

## Laptop Or Desktop Codex Work

Before any laptop or desktop Codex task run:

1. Confirm you are in `C:\Dev\codex-fleet`.
2. Check repo cleanliness with `git status --short`.
3. Read `docs/fleet/STABLE_CONTEXT_CAPSULE.md`.
4. Read the selected one-task queue entry.
5. Confirm the selected task has `readFirst`, `allowedFiles`, `validationCommands`, `stopIf`, and report format.
6. Confirm the current Phone HQ posture is request-only.
7. Confirm stop signs are inactive.
8. Run only the selected task's validation commands.

If repo status is unclear, the status page is stale, stop signs are active, or validation fails twice, stop and ask HQ for repacketization.

## Stop Signs

Stop if the next action would require product repos, all-fleet, overnight, deploy, stage, commit, push, installs, migrations, secrets, lock deletion, permission widening, phone approval, runtime binding, remote access configuration, command execution from phone text, or treating dashboard UI, prompts, queue prose, notifications, reports, manifests, approvals, or validation summaries as executable commands.

## GREEN / YELLOW / RED

GREEN means status is readable, the request-only posture is clear, the selected task is one bounded Codex Fleet task, stop signs are inactive, and validation is available before work starts.

YELLOW means status is stale, repo cleanliness is unknown, travel evidence is incomplete, or laptop/desktop verification is needed before work.

RED means the path requires secrets, unsafe remote access changes, product repos, all-fleet, overnight, deploy, stage, commit, push, installs, migrations, lock deletion, permission widening, phone approval, runtime binding, or broader authority.

## Next Safe Prompt Source

For Codex work, use `docs/fleet/REMOTE_TRAVEL_CODEX_THIN_PROMPT_PACKET.md` from a laptop or human-controlled remote desktop session. Take exactly one bounded task and stop after validation.
