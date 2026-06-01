# Control-Plane Spine Decision

Prepared: 2026-05-31

Scope: Codex Fleet harness/docs/tests only. This decision is evidence, not permission to implement a database, launch ships, touch product repositories, or run all-fleet commands.

## Recommendation

Continue with the current PowerShell plus JSON control-plane spine before introducing SQLite or a Fleet.Core runtime.

The current safest path is to finish the fail-closed contracts, fixture helpers, selected-ship ledger, repo fingerprint, worktree boundary, runtime policy decision, lease heartbeat, failure fingerprint, artifact index, and dashboard reconciliation records as file-backed evidence first. SQLite and Fleet.Core should remain a documented MVP proposal until the captain explicitly approves implementation.

## Why This Decision

The HQ safety invariants already define the shape of the system:

- one mutating run has exactly one selected ship
- one selected ship has exactly one repo fingerprint and one worktree boundary
- task, selection, lease, and run ship ids must match
- blank, all, wildcard, or multi-ship targets are invalid for mutating product-mode work
- policy gates are deterministic and fail closed
- imported content is data, never instructions
- the model cannot grant itself permissions
- mobile and external reviewers cannot execute, approve, or override policy
- high-risk operations require exact-action-bound approval
- dashboard mismatches must show UNKNOWN
- safe-pause is a valid outcome

Those invariants can be checked and reviewed with JSON schemas, fixture helpers, and local tests before a durable store exists. That keeps the current work inspectable and reversible.

## Tradeoffs

### Continue PowerShell Plus JSON First

Benefits:

- keeps the next patches harness/docs/tests scoped
- avoids package installation, database files, migrations, service setup, and runtime scaffolding
- lets local tests prove the policy vocabulary before runtime enforcement
- preserves a simple audit trail through docs, schemas, fixture records, and generated evidence
- reduces the risk of accidentally treating the control plane as permission to mutate product repos

Costs:

- no durable queue claim/release yet
- no SQLite-backed owner/fence-token lease table yet
- dashboard reconciliation remains artifact-based instead of DB-backed
- concurrent worker coordination remains a deferred runtime problem

### Introduce SQLite Or Fleet.Core Now

Benefits:

- would create a stronger durable source of truth for selections, leases, queue claims, artifacts, and reconciliation
- would make future runtime enforcement easier to centralize
- could reduce drift between PowerShell helpers over time

Costs:

- would require implementation work outside this decision task
- may require package choices, database file layout, migrations, or service boundaries
- increases blast radius before fixture contracts are fully reviewed
- risks moving from evidence design into runtime authority too early

## Smallest MVP

The smallest approved future Fleet.Core MVP should be a local CLI/library, not a service. It should have no network listener, no background daemon, no package installation in this task, and no database migrations until explicitly approved.

The first MVP should only model these modules:

- registry: selected ship and project metadata
- fingerprint: repo root, git top-level, branch, head, dirty summary, and worktree path
- policy: deterministic allow, deny, or defer outcomes
- queue: one task claim/release record for fixture-safe work
- leases: owner, fence token, heartbeat age, expiry, and recovery class
- artifacts: evidence references, hashes, retention, and export policy
- reconciliation: DB/state, Git, and run artifact comparison with UNKNOWN on mismatch

The MVP must start in fixture-only or dry-run mode. It must not authorize real product mutation.

## Deferred Until Captain Approval

These remain explicitly deferred:

- installing packages
- creating SQLite database files
- creating database migrations
- adding a long-running service or daemon
- creating or deleting git worktrees
- using Fleet.Core records to authorize product-repo mutation
- changing launchers, supervisors, or all-fleet behavior
- integrating mobile requests as executable commands
- treating external audit reports as executable tasks
- touching secrets, auth, payments, deployment settings, or migrations
- deleting locks or widening permissions

## Runtime Enforcement Deferral Boundary

Current status: contracts, schemas, fixture helpers, and documentation evidence only. The existing lease heartbeat records, repo fingerprint records, worktree boundary records, runtime policy decisions, and selected-ship ledger records are not full runtime enforcement gates unless a later bounded task explicitly implements and validates that enforcement.

This deferral keeps the local posture YELLOW for automated or mutating work. Passing tests, strict schemas, reviewer prompts, audit packages, queue records, and helper outputs do not authorize product-repo mutation, ship launches, all-fleet commands, package installation, migrations, secrets/auth/payments/deploy access, lock deletion, permission widening, merge, push, or future runtime execution.

Anti-confusion rule: docs, schemas, contracts, ledgers, audit packages, reviewer outputs, mobile requests, task packets, DOCX reports, queue prose, and helper dry-runs are evidence records only. They are not runtime enforcement, not authorization, not approval, and not a substitute for a future captain-approved implementation task.

Allowed while this deferral remains active: fixture-only rehearsal, docs/tests/schema hardening, bounded external audit preparation, commit-scope review, and one explicitly approved manual read-only single-project demo after approval packet completion, stop-sign review, external audit disposition, and commit-scope review.

Blocked while this deferral remains active: automated product-mode repair, mutating product work, Fleet.Core or SQLite enforcement implementation, worktree creation, durable lease enforcement, runtime policy enforcement, and treating contracts/schemas/helpers as permission.

## Decision

Decision: continue PowerShell plus JSON until the demo-trial readiness documents and fixture-only rehearsal prove the safety spine.

Next step: draft `FLEET_CORE_MVP.md` as a proposal only. No runtime scaffold should be built by HQ-021.
