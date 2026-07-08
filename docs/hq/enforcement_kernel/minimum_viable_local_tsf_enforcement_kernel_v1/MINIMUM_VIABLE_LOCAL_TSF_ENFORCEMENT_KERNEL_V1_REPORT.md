# Minimum Viable Local TSF Enforcement Kernel V1 Report

## Verdict

`GREEN_MINIMUM_VIABLE_TSF_ENFORCEMENT_KERNEL_BUILT`

## What Was Built

This lane built the first foreground-only local TSF enforcement kernel.

The kernel now has:

- a structured mission packet schema
- local filesystem mission states
- a preflight validator
- an approval ledger schema and empty local example
- a foreground Codex worker adapter stub
- a post-run verifier
- a preservation packet writer
- fixture-driven scoped tests

## Scope Boundary

This is master TSF infrastructure only. It is not an NWR model task, not a TSF-NWR packet task, and not a product-repo task.

No persistent runner, desktop UI, API bridge, product repo mutation, canonical NWR mutation, normal NWR packet read, push, merge, deploy, install, migration, secrets access, PrivateLens access, all-fleet command, proof run, background process, scheduler, daemon, watchdog, open network port, credential creation, app wiring, ranking/formula/source-truth promotion, recommendation behavior, or hidden sort change was performed.

## Main Files

- `tools/codex-fleet-enforcement-kernel.ps1`
- `tsf-kernel-preflight.ps1`
- `tsf-kernel-worker-adapter.ps1`
- `tsf-kernel-postrun-verify.ps1`
- `tsf-kernel-preserve.ps1`
- `fleet/control/approval-ledger.local.example.json`
- `fleet/missions/*/.gitkeep`
- `tests/run-minimum-viable-kernel-tests.ps1`
- `tests/fixtures/fleet/enforcement-kernel/*.json`

The full file list is in `minimum_viable_kernel_file_manifest.csv`.

## Preflight Behavior

The preflight validator accepts one mission packet and checks:

- JSON shape and required fields
- repo existence
- path scope
- explicit restricted-action coverage
- git branch/status capture
- TSF project registration or TSF control-plane internal exception
- machine-checkable stop conditions
- exact approval ledger matches for approval-gated actions

If a restricted action is requested without active approval, preflight returns `TIM_REQUIRED`.

If scope or schema is unsafe, preflight returns `RED`.

## Approval Ledger Behavior

The V1 approval ledger schema records:

- approval id
- approver
- approval timestamp
- expiry or scope limit
- repo path
- lane
- exact action
- allowed files or paths
- required verifier
- notes

The repo includes only an empty local example and fixture approvals. Fixture approvals are recognized but do not grant real authority unless the explicit test-only switch is used from fixture paths.

## Codex Adapter Status

The V1 adapter is intentionally a safe foreground stub.

Approved preflight produces:

`STUB_READY_CODEX_CLI_BLOCKED`

This means the kernel can prepare a worker instruction packet, but direct Codex CLI execution remains blocked until Tim approves a separate adapter pilot.

## Post-Run Verifier Behavior

The verifier checks:

- mission id match
- expected artifacts exist
- restricted actions were not attempted
- touched-file evidence does not include forbidden output paths when evidence is available

Missing required artifacts fail closed as `RED`.

## Preservation Packet Behavior

The preservation writer creates a packet folder with:

- mission packet
- preflight result
- worker instruction or result
- verifier result
- preservation summary
- manifest
- next-action note

The preservation packet is evidence only and does not approve future work.

## Validation Run

Validated with:

- PowerShell parser checks for new scripts
- JSON parse checks for schemas, fixtures, and ledger example
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-minimum-viable-kernel-tests.ps1`
- `git diff --check`

All validations passed.

## Caveats

- V1 does not invoke Codex CLI.
- V1 does not enforce every future mission with a daemon or UI.
- V1 uses dependency-free PowerShell validation rather than an installed JSON Schema package.
- V1 creates local filesystem state folders and evidence copies; it does not run a queue executor.

## Recommended Next Step

Review this branch and, if Tim wants the kernel to become the required path for live TSF work, approve a V1.1 lane for real mission-packet authoring plus a foreground Codex CLI adapter pilot. Keep API, UI, and persistent runners out of scope until the foreground path is trusted.
