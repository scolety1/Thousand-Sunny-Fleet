# Selected Ship Ledger Contract

Prepared: 2026-05-30

Scope: Codex Fleet harness, docs, schemas, and tests only. This contract defines a selected-ship ledger record and a fixture-only dry-run writer before any runtime authorization is implemented.

The selected-ship ledger is evidence, not permission. It records a proposed one-ship selection with references to repo fingerprint and runtime policy decision evidence. It does not authorize product mutation, launch ships, import packets, or bypass approval.

Plain invariant: one ledger record binds exactly one selected ship.
Plain invariant: blank, all, wildcard, or multi-ship selections are rejected.
Plain invariant: dry-run ledger writing must stay inside fixture roots.

## Required Fields

Each selected-ship ledger record must include:

- `schemaVersion`
- `ledgerId`
- `selectedShipId`
- `repoFingerprintRef`
- `policyDecisionRef`
- `owner`
- `createdAt`
- `expiresAt`
- `status`
- `evidenceRefs`
- `dryRun`
- `validation`

`repoFingerprintRef` points at a repo fingerprint record. `policyDecisionRef` points at a runtime policy decision record. Both are references, not authority.

## Status Values

Allowed status values:

- `selected`
- `dry-run-only`
- `denied`
- `expired`
- `released`

`dry-run-only` is the only status produced by the fixture helper in this task. Future runtime selection must be separately approved before it can create live selected-ship state.

## Validation Reasons

Validation reasons include:

- `single-selected-ship`
- `blank-ship`
- `all-ship`
- `wildcard-ship`
- `multi-ship`
- `repo-fingerprint-ref-required`
- `policy-decision-ref-required`
- `owner-required`
- `fixture-root-required`
- `fixture-root-escape`
- `dry-run-only`
- `evidence-recorded`

Blank, `all`, `*`, wildcard, comma-packed, or array-like multi-ship selection must be invalid and must not write a ledger file.

## Fixture-Only Dry-Run Writer

`Write-FleetSelectedShipLedgerDryRun` in `tools/codex-fleet-autonomy.ps1` creates a schema-shaped selected-ship ledger record only when:

- the selected ship is exactly one non-wildcard value
- `repoFingerprintRef` is present
- `policyDecisionRef` is present
- `owner` is present
- `FixtureRoot` is present
- `OutPath` resolves inside `FixtureRoot`

The helper returns `written = false` for denied selections or fixture-root escapes. It never writes outside the fixture root and never reads product repos.

## Rejected Fixtures

Tests must cover:

- `blank-ship`
- `all-ship`
- `multi-ship`
- `wildcard-ship`
- `fixture-root-escape`
- `valid-fixture-dry-run`

## Out Of Scope

- Using the ledger to authorize real product mutation
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Importing task packets
- Creating durable DB tables
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings
- Deleting locks
- Widening permissions

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
