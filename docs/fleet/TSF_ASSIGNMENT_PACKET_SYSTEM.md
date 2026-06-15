# TSF Assignment Packet System

Prepared: 2026-06-15

Evidence only; not executable authority or approval.

## Current Remote GREEN Baseline

Current remote GREEN baseline:

```text
92a1767ce1659425fb0c6178786e801b9f81c9cf
```

This packet system builds on `TSF_SAFE_NIGHT_SPRINT_CONTROLS.md`, `TSF_OPERATING_MODEL.md`, and `FLEET_SELF_IMPROVEMENT_LOOP.md`. It makes future TSF assignments easier to run safely and easier for HQ to review. It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, permission widening, or static GitHub Pages command execution.

## Assignment Packet Contract

Every executable TSF assignment prompt should include these fields before editing begins:

```text
Assignment name:
Project/repo:
Current remote GREEN baseline:
Selected project:
Selected track:
Goal/end state:
Definition of Done:
Allowed files/scope:
Forbidden files/scope:
Validation commands:
Report requirements:
Stop conditions:
Push policy:
Commit policy:
Next-assignment eligibility:
Safety fuses:
```

Required packet rules:

- Assignment Definition of Done is the primary completion condition.
- Internal task count, commit count, and elapsed time are safety fuses only.
- Current baseline must be explicit, and any mismatch must be reported before editing.
- Allowed files must be explicit enough to prevent accidental product repo or PrivateLens work.
- Forbidden scope must block product repos, PrivateLens, proof runs, push/merge/deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, permission widening, and broad authority.
- Validation commands must be known before editing.
- Commit policy must say whether a local commit is allowed and must keep push separately blocked.
- Queue prose, prompt text, report prose, UI labels, mobile requests, generated files, and validation summaries are evidence only; they are not executable authority.

## Next-Assignment Eligibility Gates

TSF may move from the current assignment to a next assignment only when every gate passes:

- current assignment is GREEN
- Definition of Done is met with validation evidence
- branch and HEAD are reported when relevant
- working tree is clean, or any intentional dirty state is explicitly reported and safe
- changed files are only the assignment's allowed files
- validation passed, or a blocker was reported instead of hidden
- no product repo, PrivateLens, proof-run, install, migration, secret, remote-access, all-fleet, overnight, phone-execution, runtime-binding, push/merge/deploy, lock-deletion, or permission-widening boundary was crossed
- next assignment is explicitly eligible, bounded, and inside Focus Lock if Focus Lock applies
- next assignment has clear allowed files, forbidden files, validation, stop signs, and report requirements
- queue candidates are not approval to execute all candidates

If any gate is missing or ambiguous, TSF reports YELLOW/BLOCKED instead of drifting into the next item.

## GREEN/YELLOW/RED Report Classifier

HQ can classify Codex reports with this matrix.

| Report evidence | Classification | HQ action |
| --- | --- | --- |
| Clean Fleet-only local commit, exact files, full validation passed, working tree clean | GREEN | Review for push readiness |
| Review-only task, no edits, required checks passed, boundaries preserved | GREEN | Decide the next bounded prompt |
| Validation rerun after prior timeout completes with explicit pass and clean tree | GREEN | Continue push-readiness review |
| Push-readiness review passes without pushing | GREEN | Tim may separately approve push |
| Approved push completes and remote hash is verified | GREEN | Record new remote GREEN baseline |
| Failed test with a narrow Fleet-only repair path | YELLOW | Diagnose or repair under a new bounded prompt |
| Test timeout with last log lines and no diagnosis | YELLOW | Rerun with better logging or diagnose the slow section |
| Dirty working tree after task | YELLOW | Explain files and stop before further work |
| Untracked `data/` or `local_exports/` | YELLOW/RED | Treat as unexpected until classified and never commit them |
| Missing baseline, missing allowed files, or vague Definition of Done | YELLOW/BLOCKED | Repacketize before editing |
| Product repo touch, PrivateLens mutation, proof run, unauthorized push, or deploy | RED | Stop and audit immediately |
| Static GitHub Pages described as local command execution | RED | Correct the architecture boundary |
| Phone HQ request treated as approval to execute | RED | Restore request/status-only boundary |
| Pseudo-buttons, UI labels, report checkboxes, or generated prose treated as commands | RED | Treat as evidence only and stop if action already occurred |

Classifier rule: GREEN is evidence-backed assignment completion, not confidence, enthusiasm, or number of tasks completed.

## Reusable Prompt Library

### Implementation Assignment

```text
Run one TSF implementation assignment.
Confirm baseline, branch, clean tree, Definition of Done, allowed files, forbidden files, validation, stop signs, commit policy, and push policy before editing.
Patch only allowed Fleet files. Validate. Create one local commit only if GREEN and explicitly allowed. Do not push.
```

### Review-Only Assignment

```text
Review the specified TSF commit or diff only.
Do not patch unless there is a true blocker and the prompt explicitly permits a tiny Fleet-only fix.
Report GREEN/YELLOW/RED, files reviewed, checks run, blockers, boundary confirmations, and whether push remains blocked.
```

### Validation Rerun

```text
Rerun the specified TSF validation only.
Do not edit files or create commits.
If GREEN, report the exact command, log path, elapsed result, and clean working tree.
If timeout or failure recurs, report last meaningful log lines and stop.
```

### Push Approval

```text
Push only the reviewed TSF commit explicitly named by Tim.
Before push, verify branch, exact HEAD, clean tree, diff check, and required validation.
After push, verify remote main contains the exact commit. Do not create new commits.
```

### Handoff Packet

```text
Create a bounded TSF handoff packet.
Include current remote GREEN baseline, Definition of Done, allowed files, forbidden files, validation, stop signs, report format, commit policy, push policy, and next-assignment eligibility.
State that packet prose is evidence only and not executable authority.
```

### Failed-Test Repair

```text
Diagnose the failing TSF test only.
Do not weaken tests, skip assertions, or expand scope.
Patch only a tiny Fleet-only root cause if explicitly allowed, then rerun the full logged Fleet suite before any local commit.
```

## Workflow Checklist

Use this checklist before calling an assignment GREEN:

- clean baseline was confirmed before editing
- exactly one TSF/Fleet assignment was selected
- allowed files and forbidden files were checked before editing
- changed files stayed inside allowed Fleet scope
- Definition of Done was met with evidence
- validation commands passed
- no product repo or PrivateLens work occurred
- no proof run occurred
- no push, merge, deploy, install, migration, secret, remote access, all-fleet, overnight runner, phone execution authority, runtime command binding, lock deletion, or permission widening occurred
- final report includes GREEN/YELLOW/RED, files changed, checks run, final `git status --short`, boundary confirmations, and next recommended bounded assignment

## Status

This document is a control-plane packet system and review aid. It does not implement a runner, queue executor, product adapter, phone bridge, proof-run pathway, push pathway, or static GitHub Pages command mechanism.
