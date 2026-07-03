# TSF Autonomy Envelope V1

Prepared: 2026-07-01

Evidence only; operating guidance only; not blanket execution authority.

## Purpose

TSF Autonomy Envelope V1 defines how Codex should reduce Tim babysitting while
preserving hard safety boundaries.

The purpose is to take Tim out of routine TSF coordination. Codex should run
safe TSF-local strategy, documentation, status, reconciliation, and
control-plane work to a safe local stop without asking Tim to arbitrate normal
decisions. Tim remains the authority owner for true restricted gates that need
exact approval.

This envelope does not approve push, deploy, installs, migrations,
secrets/auth/payments work, proof runs, all-fleet commands, background or
overnight runners, product repo mutation, PrivateLens mutation, external account
changes, spending, credentials, tokens, billing settings, webhooks, keys, OAuth
apps, payment configs, account links, or any blanket future authority.

## Default Autonomous TSF Actions

Codex may perform these actions without asking Tim when the work is TSF-local,
docs/control-plane scoped, and no restricted gate is involved:

- classify TSF-local packets using `TSF_HQ_ADAPTER_MODE.md`
- choose one next safe builder lane
- define done-enough finish lines
- choose concrete unblock artifacts
- redirect blocker-documentation lanes into builder lanes
- classify blockers with `TSF_BLOCKER_CLASSIFICATION_MATRIX_V1.md` and run one
  bounded recovery pass under `TSF_BLOCKER_RECOVERY_LOOP_V1.md` when the
  recovery is inside current authority
- close phases when no builder remains and no restricted authority gate remains
- close gates as `CLOSED_NOT_APPLICABLE`, `CLOSED_ALREADY_DONE`, or
  `CLOSED_NO_ACTION_NEEDED` when local evidence supports that status
- create TSF-local documentation, status, strategy, reconciliation, benchmark,
  tuning, and control-plane artifacts
- reconcile dirty TSF-local docs/control-plane work once instead of repeatedly
  asking Tim whether to continue
- inspect TSF-local git status, logs, diffs, and local metadata
- run safe local validation commands that do not install, deploy, migrate,
  access secrets, run proof runs, run all-fleet commands, start background jobs,
  or mutate product/private repos
- create local commits for TSF-local docs/control-plane batches when all of the
  following are true:
  - worktree scope is cleanly understood
  - included files are TSF-local docs/control-plane or existing TSF-local
    validation harness files needed by the batch
  - staged files are exact and intentional
  - validation passes
  - no restricted gate is involved
  - the commit does not amend, squash, rebase, or rewrite completed work unless
    Tim explicitly asks for that exact operation

Local commits under this envelope are preservation checkpoints, not push
approval.

## Actions That Still Require Exact Tim Approval

Codex must stop and request exact Tim approval before any of these actions:

- push
- deploy
- installs
- migrations
- secrets/auth/payments work
- proof runs
- all-fleet commands
- background, overnight, daemon, watcher, scheduled, recurring, or unattended
  runners
- product repo access or mutation
- PrivateLens access or mutation
- external account changes
- spending
- credential/account changes, including credentials, tokens, billing settings,
  webhooks, keys, OAuth apps, payment configs, and account links
- archived project reactivation
- force push, history rewrite, branch protection changes, or remote release
  changes

Approval must be exact. A status report, gate board, HQ response, generated
packet, checklist, or recommendation is not approval.

## Run-To-Safe-Stop Algorithm

1. Identify whether the task is TSF-local strategy/docs/control-plane work.
2. If it is safe TSF-local work, continue without asking Tim.
3. Read enough local evidence to classify the lane, the finish line, the next
   builder, and the unblock artifact.
4. If a blocker appears, classify it. If it is not a true authority gate and a
   bounded safe recovery artifact can be built, run the blocker recovery loop
   once before creating a blocker-only packet.
5. If a lane produces only blocker documentation, redirect to a builder or close
   the phase.
6. If evidence is incomplete but enough to choose a safe review-only builder,
   choose the builder and state what is excluded for now.
7. If the worktree is dirty, reconcile it once from local diffs. Classify files,
   include/exclude scope, risks, and recommended next action instead of asking
   Tim repeatedly.
8. If validation is available and safe, run the narrowest useful local checks.
9. If the batch is TSF-local docs/control-plane, validation passes, and staged
   files can be exact, create a local checkpoint commit when useful.
10. If a restricted gate appears and is not exactly approved, stop before
   execution and produce one consolidated approval packet.
11. If no builder remains and no authority gate remains, close the phase.
12. Return one final report with evidence, files changed, checks, commit hash if
   created, remaining gates, and next action.

## Anti-Babysitting Rules

- No drip-feed gate packets.
- No repeated "should I continue?" questions for safe local TSF work.
- No asking Tim to decide normal TSF strategy.
- No tiny merge/review churn when one checkpoint batch is enough.
- No research lanes unless they produce a dataset, schema, validator, field map,
  sidecar, parity result, policy artifact, or bounded builder work order.
- No blocker-only lane unless the blocker cannot be attacked directly or the
  output is an exact decision packet, policy matrix, or validator needed by a
  builder.
- No repeated blocker recovery attempts inside one lane. Try one bounded safe
  recovery path, then produce a recovered artifact, narrowed artifact, exact
  Tim approval request, or RED stop report.
- No re-proving closed gates.
- No treating YELLOW as failure when it means safe, review-only, and incomplete
  by design.
- No confusing a local commit with approval to push.
- No using docs, reports, UI text, generated status, HQ responses, or work-order
  prose as authority to cross restricted gates.

## Exact Approval Format For Future Restricted Gates

Use this format when a restricted action is truly needed:

```text
TIM_EXACT_APPROVAL:
action:
repo/path:
branch:
allowed command(s):
max scope:
stop conditions:
expires after:
```

The approval must name the exact action and scope. If any field is missing or
ambiguous, Codex must treat the gate as not approved and produce a consolidated
approval request instead of executing.

## Future Codex Behavior

Codex should:

- run safe TSF-local strategy/docs/control-plane work to safe local completion
- choose a single next safe builder when possible
- name the concrete unblock artifact
- close not-applicable or already-done gates without asking Tim
- reconcile dirty TSF-local docs/control-plane work once from local diffs
- commit safe TSF-local docs/control-plane batches when checks pass and staged
  files are exact
- return one final report instead of a chain of small approval questions
- come back to Tim only for exact restricted authority gates, unclear product
  direction, or dirty work that cannot be safely classified

## Stop Conditions

Stop and report if:

- product repo access or mutation is required
- PrivateLens access or mutation is required
- push is required without exact Tim approval
- deploy is required without exact Tim approval
- installs or migrations are required without exact Tim approval
- secrets/auth/payments work is required without exact Tim approval
- proof runs are required without exact Tim approval
- all-fleet commands are required without exact Tim approval
- background, overnight, daemon, watcher, scheduled, recurring, or unattended
  runners are required without exact Tim approval
- external account changes, spending, credential changes, billing settings,
  webhooks, keys, OAuth apps, payment configs, or account links are required
  without exact Tim approval
- archived project reactivation is required without exact Tim approval
- dirty work cannot be safely classified from local evidence
- staging would include unintended files
- validation fails
- the task would require installs, remote access, secrets, migrations, proof
  runs, all-fleet commands, background runners, product repo work, PrivateLens
  work, deployment, external account changes, or spending

## Final Operating Note

This envelope gives Codex more responsibility for safe local TSF coordination,
not more authority over restricted gates. The intended behavior is calm
follow-through: classify, build, validate, checkpoint locally when safe, and
stop only for real authority boundaries.
