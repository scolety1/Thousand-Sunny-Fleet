# Fixture Readability Inventory

Prepared: 2026-06-03

This inventory defines a local read-only fixture accessibility check for `tests/fixtures/fleet` JSON/Markdown evidence. It is evidence for local harness validation only and is not executable authority.

Canonical notice: Evidence only; not executable authority or approval.

## Scope

The check covers committed fixture evidence under `tests/fixtures/fleet`.

The currently present directory list below is based on this repository state. External audit packages may include a narrower allowlist. When a category is marked "future-capable", absence in a package or future snapshot is not itself a safety issue; it only means no fixtures for that category were included yet.

| Fixture path | Repository status | Expected evidence |
| --- | --- | --- |
| `tests/fixtures/fleet/anti-loop` | currently present | JSON anti-loop fixture evidence |
| `tests/fixtures/fleet/approvals` | currently present | JSON approval-boundary fixture evidence |
| `tests/fixtures/fleet/evidence` | currently present | JSON validation, digest, manifest, and audit evidence |
| `tests/fixtures/fleet/read-only-demo` | currently present | JSON read-only demo readiness denial/defer/planning evidence |
| `tests/fixtures/fleet/read-only-gates` | currently present | JSON selected-project read-only gate evidence |
| `tests/fixtures/fleet/thin-task-packets` | future-capable; currently present in this repo | JSON thin-task packet evidence |
| `tests/fixtures/fleet/ui-control` | future-capable; currently present in this repo | JSON static UI/control posture evidence |

## Local Read-Only Check

Validation may enumerate the currently present fixture directories, read fixture files, and parse JSON fixtures with local PowerShell JSON parsing. Markdown fixtures, if present, may be read as text evidence only.

Future-capable categories are checked only when the directory exists. Validation must not create a missing future-capable directory, widen permissions, or fail solely because a future-capable category is absent from an audit package.

Any unreadable fixture path is reported as validation failure evidence, not fixed by widening permissions. A failed read or parse should stop the local validation run and be handled through a bounded follow-up task.

Read-only demo fixture package-inclusion check: `tests/fixtures/fleet/read-only-demo/*.json` is local evidence only and may be listed in future read-only demo readiness audit package allowlists after exact human package-scope review. The check is limited to confirming the directory is present, fixture files are readable, JSON fixtures parse, and every included file remains excluded from product repos, raw logs, `.git`, `.env`, dependency folders, build outputs, package sending, runtime command binding, approval material for real product work, and permission-widening actions.

## Non-Actions

This inventory does not change ACLs, chmod permissions, ownership, package-builder behavior, product repos, or generated package contents.

It also does not delete, move, rename, rewrite, create, or send audit packages. It does not approve product repo access, runtime command binding, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, or permission widening.

## Authority Boundary

The inventory is documentation for local fixture readability coverage. It cannot approve or execute work, select product repos, send packages, broaden scope, or convert generated evidence into authority.
