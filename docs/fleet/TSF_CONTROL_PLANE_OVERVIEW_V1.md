# TSF Control Plane Overview V1

Prepared: 2026-07-02

Evidence only; canonical overview only; not executable authority or approval.

## Definition

Thousand Sunny Fleet is Tim's local coding and product control plane. It turns
messy ideas, research, status, blockers, and return-state questions into
bounded Codex work lanes with clear guardrails, so Tim does not have to
reconstruct what matters, what is safe, and what needs exact approval every time
he comes back.

## What TSF Is

TSF is a local cockpit for coordination, strategy, status, and safe Codex work
preparation. It helps Codex and Tim:

- reduce context switching across projects
- turn fuzzy ideas and research into bounded work orders
- show what needs Tim now
- keep Codex moving on safe TSF-local docs/control-plane work
- preserve guardrails around product repos, archived projects, push/deploy,
  installs, migrations, secrets, proof runs, all-fleet commands, background
  runners, and unsafe autonomy
- distinguish authority from evidence, proposals, generated status, UI text,
  and historical snapshots

## What TSF Is Not

TSF is not a product repo. It is not PrivateLens. It is not a deploy pipeline,
remote-control system, proof-run launcher, all-fleet runner, scheduler,
background daemon, external-account manager, spending tool, or credential
store.

TSF docs, status files, generated work orders, prompts, console text, reports,
benchmarks, and HQ responses are evidence or operating guidance. They do not
authorize product repo access, product repo mutation, PrivateLens work, push,
deploy, installs, migrations, secrets/auth/payments work, proof runs,
all-fleet commands, background runners, archived reactivation, external account
changes, spending, credential/account changes, history rewrite, or remote
release changes.

## Core Job

The core job of TSF is to answer the return question calmly:

```text
Where are we, what matters, what is safe to do next, and what needs Tim's exact approval?
```

TSF should move safe local coordination forward by producing concrete artifacts:
status boards, indexes, validators, approval packets, bounded work orders,
prompt libraries, queue entries, closeout notes, and decision rubrics. It should
avoid research-only loops and blocker-only paperwork unless the blocker cannot
be attacked directly.

## Main Components

### Fleet Console

The Fleet Console is a static, readable cockpit UI for status, lanes, decisions,
draft queue items, and safe next actions. It is UI/readable guidance only. It
has no executable controls, command hooks, forms, scripts, network calls, or
browser automation authority.

### Master Codex / Control Layer

Master Codex is the control-plane reviewer and triage lead. It checks branch,
HEAD, remote baseline, ahead/behind, working tree, lane state, tests, push
readiness, gate closure, and do-not-touch rules. It summarizes TSF state so Tim
does not have to reconstruct it manually.

### Autonomy Envelope

`docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md` defines what Codex may do
autonomously inside TSF: classify TSF-local packets, choose one safe builder
lane, define done-enough finish lines, create TSF-local docs/control-plane
artifacts, run safe local validation, reconcile classifiable dirty TSF docs,
and create local commits when scope is clean and staged files are exact.

It does not approve restricted gates. Local commits are preservation
checkpoints, not push approval.

### HQ Adapter / Decision Bench / Tuning Pack

The HQ adapter, decision bench, tuning runbook, and dry-run artifacts help TSF
ChatGPT HQ return decisive strategic judgments instead of producing endless
blocker documentation. HQ can choose finish lines, one next builder, unblock
artifacts, exclusions, and batch plans. HQ output remains strategic evidence,
not execution authority.

### Anti-loop Policies

The anti-loop policies prevent safe process from becoming slow bureaucracy.
They push lanes toward artifact-producing builders, batch review-only packets
into checkpoints, accept safe YELLOW review-only work when incomplete by design,
and redirect blocker-only lanes into the smallest usable unblock artifact.

### Blocker Recovery Loop

`docs/fleet/TSF_BLOCKER_RECOVERY_LOOP_V1.md` and
`docs/fleet/TSF_BLOCKER_CLASSIFICATION_MATRIX_V1.md` define what Codex does
when a lane hits a blocker. Codex must classify the blocker, preserve useful
state, try one bounded safe recovery path when current authority allows it, and
produce a recovered artifact, narrowed artifact, exact Tim approval request, or
RED stop report. The NWR historical foundation miss/recovery is the worked
example: shallow four-artifact discovery was corrected with preservation,
fresh sandbox recovery, provenance, comparison, and exact public acquisition
approval before parity.

### Control-Plane Artifact Index

`docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md` classifies important TSF
artifacts by category, authority level, freshness, safe default action, and
whether they can authorize action. Its standing rule is simple: research,
generated work orders, status files, UI text, and historical snapshots are
evidence, not approval.

### Draft Queue

`fleet/status/draft-queue/` holds prepared packets Tim can approve, edit, deny,
or ignore. The draft queue currently includes PrivateLens read-only inspection
approval, PrivateLens follow-up work, Nytheria Slice 1 approval and work order,
TSF push approval, Lane 6 ambiguity trigger, Lane 7 product access approval,
morning decision queue, and Master Codex daily check prompt.

Drafts are proposals. They do not authorize implementation or restricted work
until Tim sends exact approval.

### Daily Driver / Coder Upgrade / Game Forge Lanes

These lanes provide reusable TSF systems:

- Daily Driver: project passports, next-session cards, work-order drafts,
  triage scoring, return review, and morning/after-work context
- Coder Upgrade: repo x-rays, context packs, diff risk review, bug journal,
  work-order splitting, and stuck-state playbooks
- Game Forge: intake templates, engine blueprints, systems maps, prototype
  slices, research prompts, risk reviews, game work orders, and Nytheria toy
  prototype planning

## Authority Model

### Codex May Do Autonomously

When the work is TSF-local docs/control-plane work and no restricted gate is
involved, Codex may:

- inspect TSF repo status, logs, diffs, and local docs/status
- classify TSF-local packets and dirty TSF-local docs/control-plane work
- choose exactly one safe next builder lane
- define a done-enough finish line
- choose a concrete unblock artifact
- create or update TSF-local docs, status, indexes, validators, prompt
  libraries, approval packets, work orders, and closeout notes
- run safe local validation commands
- create local commits when validation passes, scope is understood, and staged
  files are exact

### Exact Tim Approval Required

Codex must stop before these actions unless Tim gives exact approval with
scope, repo/path, branch, allowed commands, max scope, stop conditions, and
expiration:

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
- archived project reactivation
- external account changes
- spending
- credential/account changes
- force push, history rewrite, branch protection changes, or remote release
  changes

Product repos require exact Tim approval before mutation. Product repo access
also requires exact Tim approval unless the approval explicitly says read-only
inspection and names the repo/path and scope.

## Current Operating Philosophy

Codex should keep moving on safe TSF-local coordination work. It should build
the artifact that removes or narrows the blocker, validate it, checkpoint it
locally when safe, and return one clear report.

Codex should not ask Tim to arbitrate normal TSF strategy. It should stop only
for true restricted gates, unsafe ambiguity, validation failure, unclear product
direction, or when no useful safe builder remains.

The preferred loop is:

1. Verify repo state.
2. Read current TSF control-plane truth.
3. Choose one safe builder.
4. If a blocker appears, classify it and run one bounded safe blocker recovery
   pass when current authority allows it.
5. Produce the concrete unblock artifact.
6. Exclude optional questions that do not block the finish line.
7. Validate locally.
8. Commit locally when safe and exact.
9. Stop before push or any restricted gate.

## How Future Codex Runs Should Use This Overview

Future Codex sessions should read this overview early when they need the
shortest durable answer to what TSF is. Use it as orientation before choosing a
lane, writing a status report, preparing a prompt, or deciding whether a file is
authority or evidence.

This overview does not replace the detailed control docs:

- use the autonomy envelope for autonomous-action boundaries
- use the safe stop matrix for continue/commit/stop/escalate decisions
- use the blocker recovery loop and classification matrix before producing
  blocker-only packets
- use the artifact index for file-level authority and freshness classification
- use the HQ adapter for strategic HQ response shape
- use the lane queue for safe next builders when no user-selected lane exists
- use the draft queue for approval packets Tim may approve later

If this overview conflicts with a more specific authority document, stop and
report the conflict instead of inventing authority.

## Copy/Paste Summary

Thousand Sunny Fleet is Tim's local coding/product control plane. It reduces
context switching by turning messy ideas, research, status, and blockers into
bounded Codex work lanes with guardrails. TSF is not a product repo and does
not authorize product repo or PrivateLens work by itself. Codex may continue
safe TSF-local docs/control-plane work, produce concrete artifacts, validate
them, and commit locally when scope is exact. Push, deploy, installs,
migrations, secrets/auth/payments, proof runs, all-fleet commands,
background/overnight runners, product repo access or mutation, PrivateLens
work, archived reactivation, external accounts, spending, credentials, and
history/remote release changes still require exact Tim approval.

## Final Note

This overview is orientation, not approval authority. It should help future
Codex and HQ sessions understand TSF quickly while preserving the existing
restricted-gate boundaries.
