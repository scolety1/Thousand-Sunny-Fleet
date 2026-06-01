# Fleet.Core MVP

Prepared: 2026-05-31

Status: proposal only. This file does not approve implementation, install packages, create database files, create migrations, launch ships, or authorize product-repo mutation.

## Current Decision

Do not build Fleet.Core yet.

Continue PowerShell plus JSON for the immediate HQ repair and demo-trial readiness work. Fleet.Core should remain a local no-service-first CLI/library proposal until the captain explicitly approves implementation after the remaining docs, tests, external audit, and fixture-only rehearsal are complete.

## MVP Shape

Fleet.Core should start as a local library plus command-line interface used by harness scripts. It should not expose a network listener, run as a background daemon, start workers, launch product ships, or bypass the existing human approval gates.

The MVP should be fixture-first and dry-run-first. Real product mutation remains out of scope until a later approval binds one selected project or ship, one action, expected evidence, and stop conditions.

## Modules

### Registry

Purpose: load known ships/projects from an explicit registry input and return normalized records.

Responsibilities:

- require an explicit registry path
- reject unknown ship ids
- reject blank, all, wildcard, or multi-ship mutation targets
- expose read-only metadata only

### Selection

Purpose: bind one operation to exactly one selected ship.

Responsibilities:

- create a selected-ship record in dry-run or fixture mode
- require owner, reason, createdAt, expiresAt, and evidence refs
- reject selection drift between task, selection, lease, and run ids
- never grant permission by itself

### Policy

Purpose: produce deterministic allow, deny, or defer decisions.

Responsibilities:

- fail closed on missing approval, stale fingerprint, forbidden entrypoint, mobile execution, external report execution, broad scope, and unknown fields
- record exact denial or deferral reasons
- keep the model from granting itself permission
- require captain approval for high-risk actions

### Queue

Purpose: model one-task claim/release records before runtime execution.

Responsibilities:

- claim exactly one task
- reject skip-ahead, nested-loop, and all-queue execution
- record task id, selected ship, owner, lease id, status, and evidence refs
- stay dry-run or fixture-only in the MVP

### Leases

Purpose: model owner/fence-token heartbeat records.

Responsibilities:

- record owner, fence token, heartbeat age, expiry, stale/expired/ambiguous state, and recovery class
- reject ambiguous ownership
- forbid deleting locks as recovery
- produce evidence instead of killing processes

### Artifacts

Purpose: index evidence created by harness runs, review packets, audit packages, and status reports.

Responsibilities:

- record artifact id, path, type, ship id, run id, hash, createdAt, retention class, sensitive export policy, and source command
- reject secret-like or non-exportable paths for external packages
- preserve generated evidence without moving or deleting existing artifacts

### Reconciliation

Purpose: compare registry/DB-like state, Git fingerprint state, run artifacts, and dashboard/status records.

Responsibilities:

- return MATCH, MISMATCH, or UNKNOWN
- show UNKNOWN when trust is lost
- record mismatch reasons such as stale run artifact, repo fingerprint drift, missing state ref, or contradictory lease
- never hide uncertainty behind a green dashboard

## No-Service-First CLI/Library Boundary

Fleet.Core should initially be callable as a local command or imported library from existing harness scripts. The first approved implementation should avoid:

- network services
- background daemons
- watchers
- schedulers
- package installation
- database migrations
- product repo writes
- all-fleet execution

## Migration Decision

Migration decision: no database migrations in the MVP proposal.

The near-term source of truth remains PowerShell plus JSON schemas, fixture records, and local evidence files. SQLite may be proposed later, but only after the demo-trial readiness path is externally audited and the captain approves a durable local store. Until then, any database-like records should be represented as JSON fixtures and validated by tests.

## Test Plan Reference

The test plan lives in `docs/fleet/FLEET_CORE_TEST_PLAN.md`.

## Deferred Until Captain Approval

- choosing SQLite or another durable store
- installing packages
- creating database files
- creating migrations
- building runtime scaffolding
- integrating with launchers or supervisors
- creating/deleting git worktrees
- using Fleet.Core to authorize real product mutation
- changing mobile or external review posture from evidence-only to executable
- touching secrets, auth, payments, deployment settings, migrations, locks, or permissions
