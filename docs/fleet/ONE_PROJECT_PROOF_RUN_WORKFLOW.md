# One-Project Proof Run Workflow

Prepared: 2026-06-11

Evidence only; not executable authority or approval.

## Purpose

This workflow turns a phone or HQ request into one local, bounded Codex Fleet proof run for exactly one registered project and exactly one selected task.

It is designed for the path proven by PrivateLens: selected project only, one bounded task only, launch gate before Codex, Codex checkpoint run, build/validation, checkpoint review, then stop for human review before merge, push, deploy, or any broader authority.

## Required Contract

Before a proof run can start, HQ/Codex must name:

- selected project: exactly one `projects.json` entry
- selected task: exactly one unchecked task from that project's `docs/codex/TASK_QUEUE.md`
- allowed files or allowed scope from the task
- validation command from the task or project config
- stop conditions
- report format

Phone/dashboard controls are request-only. A phone request can propose the selected project and task, but it cannot execute Codex, approve work, merge, push, deploy, bind runtime commands, or grant product-repo authority.

## Preflight

Run the read-only Fleet preflight from `C:\Dev\codex-fleet`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fleet-proof-run-preflight.ps1 -ProjectId PrivateLens
```

For an actual proof run packet, add exactly one selected task and require it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fleet-proof-run-preflight.ps1 -ProjectId PrivateLens -TaskSelector "<unique task text>" -RequireSelectedTask
```

The preflight is evidence only. It verifies project registration, repo state, task queue presence, build/validation command presence, launch-gate script presence, checkpoint reviewer presence, and Codex CLI/service_tier compatibility. It does not run Codex, run a product build, edit product files, stage, commit, push, merge, deploy, install packages, configure remote access, or run all-fleet/overnight work.

## Proof Run Sequence

1. Confirm exactly one selected project in `projects.json`.
2. Confirm exactly one selected task in that project's task queue.
3. Confirm repo clean/dirty state and stop if it is unclear or dirty beyond the selected task's allowed workflow.
4. Run launch gate before Codex:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fleet-launch-gate.ps1 -Project PrivateLens -LoopPhase proof -Mode enforce
```

5. Confirm Codex CLI/service_tier compatibility before spending runtime. The Fleet runtime must use `service_tier="fast"` or another supported value such as `flex`; `service_tier="default"` is not accepted.
6. Run exactly one checkpoint batch for the selected project and selected task only. Do not run all-fleet or overnight.
7. Run the configured build/validation command.
8. Run checkpoint review after Codex edits.
9. Stop for human review before merge, push, deploy, or any next task.

## Stop Conditions

Stop before Codex or during review if the work requires:

- secrets, tokens, credentials, PINs, MFA, recovery codes, keys, or private device identifiers
- backend, auth, payments, deploy, or production-sensitive changes
- package installs, dependency changes, or migrations
- remote access configuration or port exposure
- all-fleet execution
- overnight runner execution
- broader authority than the selected one-project/one-task contract
- merge, push, deploy, staging, or release approval
- lock deletion or permission widening
- unclear selected project, unclear selected task, or multiple matching tasks
- phone/dashboard UI treated as execution authority

## Human Review Stop

A GREEN checkpoint review is evidence that the bounded run passed its checks. It does not approve merge, push, deploy, product launch, or a second task.

After checkpoint review, Fleet must stop for human review. The next action must be separately selected and packetized.
