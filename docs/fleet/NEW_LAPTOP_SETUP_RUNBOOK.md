# New Laptop Fleet Setup Runbook

Prepared: 2026-06-12

Evidence only; not executable authority or approval.

## Purpose

This runbook records the minimum safe checks for bringing Codex Fleet up on a new laptop. It is local setup guidance only. It does not approve product work, PrivateLens mutation, proof runs, all-fleet execution, overnight runners, push, merge, deploy, package installs, migrations, remote access configuration, secrets handling, phone approvals, runtime command binding, lock deletion, permission widening, or future authority.

## Expected Fleet Repo Location

Use a stable human-owned clone path for Codex Fleet on the laptop, for example:

```powershell
C:\Users\<you>\Documents\Vacation\Thousand-Sunny-Fleet
```

Do not hardcode generated agent output paths as durable Fleet clone locations. If a product project was registered from another machine or temporary generated path, treat that project path as untrusted until a read-only preflight confirms it exists locally.

## First Shell Checks

Run these from the Fleet repo before any task work:

```powershell
git status --short
git log --oneline -3
codex --version
where.exe codex
```

GREEN requires a clean Fleet tree unless the current task explicitly approves local changes, and `codex --version` must run from the same shell that will run Fleet helpers.

## Codex CLI Shim Check

On Windows, prefer a runnable user or npm shim before blocked WindowsApps package resources. A healthy shell may show entries like:

```text
C:\Users\<you>\AppData\Roaming\npm\codex
C:\Users\<you>\AppData\Roaming\npm\codex.cmd
```

If `codex` resolves only to `C:\Program Files\WindowsApps\...` and `codex --version` returns `Access is denied`, stop and repair the local CLI shim before attempting proof-run work. Do not work around this by weakening Fleet checks or claiming Codex is usable.

## Baseline Fleet Validation

Run the local Fleet suite after clone/setup and after any Fleet-only patch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

The suite may take several minutes on a laptop. A local timeout is not proof of failure until the slow section is identified. Do not skip tests to make a setup pass.

## Proof-Run Caveat

A runnable Codex CLI is necessary but not sufficient for a product proof run. A proof run remains blocked until all of these are true:

- exactly one project is selected
- exactly one unchecked task is selected when `-RequireSelectedTask` is used
- the registered product repo path exists on this laptop
- the product repo state is known
- the task queue exists
- the configured build directory and validation command are available
- launch gate and checkpoint review scripts are available

Use preflight only until the product context is present:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fleet-proof-run-preflight.ps1 -ProjectId PrivateLens
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\fleet-proof-run-preflight.ps1 -ProjectId PrivateLens -TaskSelector "CSV validation/import warnings" -RequireSelectedTask
```

Do not run an actual PrivateLens proof run from a new laptop merely because Codex CLI and Fleet tests pass.

## No-Secrets And No-Product-Runs Boundary

Never put secrets, tokens, credentials, PINs, passwords, MFA material, recovery codes, keys, private device identifiers, or remote access details in Fleet docs, task packets, chat, logs, or runbooks.

New laptop setup does not approve:

- touching PrivateLens or any product repo
- installing product dependencies
- running product builds
- running proof runs
- all-fleet execution
- overnight runners
- staging, committing, pushing, merging, or deploying product work
- configuring remote access
- approving phone/dashboard actions
- binding runtime commands

## GREEN New-Laptop Setup

New-laptop setup is GREEN only when:

- Fleet repo is clean
- `codex --version` works from the active shell
- `where.exe codex` shows a runnable shim before any blocked WindowsApps package path
- `tests/run-fleet-tests.ps1` passes
- proof-run preflight fails closed clearly when product context is missing

If the registered product path is missing, the Fleet harness can still be GREEN while product proof-run readiness remains YELLOW or RED.
