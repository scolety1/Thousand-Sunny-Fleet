# Fleet.Core Test Plan

Prepared: 2026-05-31

Scope: proposal only. This test plan describes future local tests; it does not build Fleet.Core, create a database, install packages, create migrations, launch ships, or touch product repositories.

## Test Posture

Fleet.Core tests should be fixture-first, dry-run-first, and fail-closed. Tests should prove record shapes and decisions before runtime integration. The MVP should use JSON fixtures and local harness assertions until the captain approves a durable store.

## Required Test Groups

### Registry Tests

- accepts an explicit fixture registry path
- rejects missing registry path
- rejects unknown ship ids
- rejects blank, all, wildcard, and multi-ship mutation targets
- does not read product repos in fixture tests

### Selection Tests

- accepts exactly one selected ship
- records owner, reason, createdAt, expiresAt, and evidence refs
- rejects task, selection, lease, and run ship-id mismatch
- records that selection is evidence, not permission

### Policy Tests

- returns allow, deny, or defer deterministically for fixture requests
- denies missing approval
- denies stale repo fingerprint
- denies forbidden entrypoints
- denies mobile command execution
- denies external report execution
- denies broad/all-fleet scope
- fails closed on malformed input and unknown fields

### Queue Tests

- claims exactly one fixture task
- rejects skip-ahead execution
- rejects nested-loop execution
- rejects all-queue execution
- records owner, lease id, status, and evidence refs
- remains dry-run or fixture-only

### Lease Tests

- classifies fresh, stale, expired, ambiguous-owner, fence-token-mismatch, and deterministic-failure records
- rejects ambiguous ownership
- forbids lock deletion as recovery
- records recovery evidence instead of killing processes

### Artifact Tests

- records artifact id, path, type, ship id, run id, hash, createdAt, retention class, sensitive export policy, and source command
- rejects secret-like paths for export
- marks sensitive or non-exportable artifacts correctly
- does not move or delete existing evidence

### Reconciliation Tests

- returns MATCH when registry/state, Git fingerprint, and run artifact agree
- returns MISMATCH when repo fingerprint drift is detected
- returns UNKNOWN when state refs are missing or contradictory
- returns UNKNOWN for stale run artifacts
- never reports green when trust is lost

## Integration Test Boundaries

The first integration tests should run against local fixture records only. They should not invoke launchers, supervisors, remote-control flows, product repos, installs, migrations, deployments, auth, payments, secrets, lock deletion, or permission changes.

## Migration And Storage Tests

Migration decision: no migrations in the MVP proposal.

Until the captain approves SQLite or another durable local store, storage tests should parse JSON fixtures and validate closed record shapes. Any future SQLite test plan must be a separate approved task with explicit allowed files and no product-repo coupling.

## Exit Criteria

Fleet.Core implementation should not begin until:

- this proposal is reviewed
- the fixture-only rehearsal plan exists
- external audit confirms the boundaries
- the captain approves implementation scope
- the task queue names exact allowed files and validation commands
