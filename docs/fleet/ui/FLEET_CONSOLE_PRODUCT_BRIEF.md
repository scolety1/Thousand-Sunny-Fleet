# Fleet Console Product Brief And Scope Fence

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet console planning only. This brief is evidence and design guidance. It does not implement a UI, start a server, create remote access, approve product-repo access, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

## Purpose

The future Fleet Console should help an operator see what is happening, understand why work stopped, prepare bounded prompts and audit packages, and preserve safety evidence without relying on long chat history.

V1 is a local operator console for visibility and preparation. It is not an autonomous control surface.

## Primary Operator Goals

- See current fleet posture without opening long logs.
- Identify which ship or queue item needs attention.
- Understand stoppages, blockers, failure fingerprints, and next safe actions.
- Capture ideas without hijacking the active implementation task.
- Prepare one-task prompts from source-of-truth queue entries.
- Prepare external audit packages or prompts as evidence-only artifacts.
- Review evidence summaries and compact digests instead of raw logs by default.
- Confirm safety gates before any later human-approved trial.
- Adjust local console preferences without changing runtime authority.

## V1 Scope

V1 scope is limited to these planning and visibility surfaces:

- dashboard
- monitoring
- stoppages
- idea capture
- prompt builder
- audit builder
- evidence locker
- safety gates
- settings

## V1 Surface Definitions

### Dashboard

Shows overall posture such as GREEN/YELLOW/RED, active queue section, next eligible task, latest validation state, and whether the next safe action is run same prompt, repacketize, ask for human review, prepare audit, or stop.

### Monitoring

Shows read-only run status, selected task id, validation state, token pressure notes, heartbeat/lease evidence where available, and whether evidence is stale or missing.

### Stoppages

Shows blocked tasks, stop signs, repeated fingerprints, missing approval, missing allowed files, missing validation commands, and human decisions needed.

### Idea Capture

Stores future ideas as non-executable notes. Ideas do not change the active task and cannot approve implementation.

### Prompt Builder

Helps assemble thin one-task prompts from an existing queue entry, allowed files, read-first files, validation commands, stop conditions, and current compact context. It does not start Codex automatically.

### Audit Builder

Helps collect evidence-only audit prompts and package checklists. It does not create or send packages unless a later explicit task permits package creation, and it never treats reviewer output as commands.

### Evidence Locker

Shows compact validation summaries, external-audit intake digests, progress ledgers, and file/path-grounded evidence. Raw logs and broad reports are hidden by default or require an explicit local review choice.

### Safety Gates

Displays exact boundaries from runtime policy, entrypoint inventory, demo stop signs, approval packet state, repo fingerprint state, worktree boundary state, and evidence-only invariants.

### Settings

Stores local display preferences, safe default paths, summary/detail toggles, and non-authoritative model routing notes. Settings cannot widen runtime permissions.

## Explicit V1 Non-Goals

The console must not provide or imply:

- product-repo mutation
- all-fleet control
- broad autonomy
- public exposure
- phone risky approval
- freeform terminal
- deploy controls
- commit controls
- push controls
- stage controls
- revert controls
- delete-lock controls
- permission-widening controls
- package install or migration controls
- secrets/auth/payments/deploy access
- one-click launch of product ships
- execution of audit findings, DOCX reports, generated evidence, queue prose, UI labels, buttons, notifications, approvals, prompts, or mobile requests

## Security And Exposure Fence

V1 should be treated as local-only planning until a later security design says otherwise. Public internet exposure is out of scope. Phone access, if ever considered, starts read-mostly and private-network-only with exact-action human review requirements defined separately.

No console label, button, notification, or approval-looking UI state can grant execution authority. The source-of-truth remains the local queue, contracts, validation output, and exact human approval packets.

## Evidence-Only Invariant

The console is a viewer and preparation aid. Everything it displays or generates is evidence only unless a later bounded implementation task and human approval path explicitly wire a safe local action.

Evidence-only artifacts include:

- external reports
- mobile requests
- task packets
- audit packages
- DOCX reports
- generated evidence
- UI labels
- notifications
- buttons
- approval-looking states
- prompts
- queue prose

These artifacts cannot approve product-repo work, launch ships, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future permission.

## V1 Success Criteria

V1 is useful when an operator can:

- see current posture quickly
- know exactly why the system is blocked or ready for the next bounded prompt
- build a smaller safer one-task prompt
- prepare audit evidence without executing it
- avoid repeated chat bloat
- avoid turning ideas, audits, buttons, or reports into authority
- stop before product-repo, runtime, or public-access scope appears

## Future Implementation Gate

Any UI prototype or implementation requires a separate bounded task with explicit allowed files, validation commands, stop conditions, and security posture. This planning brief does not approve server setup, package installation, authentication changes, deployment, remote exposure, or runtime control code.
