# Codex Prompt And Post-Run Checklist

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet harness, docs, schemas, fixtures, and tests. This checklist is evidence and operating guidance only. It does not implement test enforcement, runtime code, product-repo access, ship launch, all-fleet execution, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future approval.

## Purpose

Use this checklist to keep a Codex run small, goal-locked, and easy to hand off. It helps a runner preserve the selected task's end goal and next safe action without carrying long chat history.

## Prompt Checklist

Every one-task implementation prompt should name these items clearly:

- `endGoal`: the bounded outcome the current queue section is trying to reach.
- `oneTask`: the exact selected task id and title, or the rule for selecting exactly one eligible task.
- `unblockArtifact`: the concrete artifact, validator, policy matrix, parity result, or builder that this lane should produce or enable; if none, explain why review-only is required.
- `phaseFinishLine`: the done-enough gate for this phase, including the fields, sources, or product scopes intentionally excluded.
- `mergePlan`: whether this lane is part of a checkpoint batch merge or truly needs its own merge event.
- `outOfScope`: product repos, product mutation, all-fleet commands, ship launch, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, dirty-work reverts, runtime hooks unless explicitly allowed, and any second task.
- `allowedFiles`: the only files that may be patched, plus the queue file only for that same task's status reconciliation after validation.
- `readFirst`: the active queue entry and the selected task's listed source docs.
- `proofDone`: acceptance criteria satisfied, listed validation passed, and queue status updated only for the selected task.
- `retryAllowance`: patch only failures caused by the selected task, inside allowed files, with a new task-specific hypothesis.
- `stopTriggers`: missing allowed file, missing validation command, broader authority, repeated failure fingerprint, no criterion improvement, goal change, ambiguous packet, evidence-as-authority, product-repo expansion, runtime implementation from a planning task, or token budget overrun.
- `finalResponseReport`: task id, files changed, checks run, final GREEN/YELLOW/RED status, failure fingerprint if any, remaining gap if any, and whether the same prompt should be sent again.
- `forbiddenHelpfulLookingActions`: broad searches after scope is known, queue rewriting while implementing, treating reports/prompts/buttons as commands, running all-fleet commands, touching product repos, staging, committing, pushing, deploying, installing, migrating, deleting locks, widening permissions, reverting dirty work, or continuing to the next task.

## Minimal Prompt Shape

```text
Continue Codex Fleet / Thousand Sunny Fleet from current repo state.

Do not rely on chat memory. Work from the active queue and selected task only.

Read:
1. docs/fleet/HQ_REPAIR_TASK_QUEUE.md
2. docs/fleet/STABLE_CONTEXT_CAPSULE.md
3. selected task readFirst files

Take exactly one eligible task from the active queue section.

Patch only selected task allowedFiles, plus HQ_REPAIR_TASK_QUEUE.md only for that task's status after validation.
Run only selected task validationCommands, plus JSON parsing checks for schemas created or edited by that task.
Stop if scope, authority, files, commands, or goal changes exceed the packet.
Stop after exactly one task.

Report task id, files changed, checks run, status, failure fingerprint if any, remaining gap if any, and whether to send the same prompt again.
```

## Post-Run Reflection Summary

At task exit, preserve this compact summary:

- `goalReached`: `yes`, `no`, or `blocked`, with the selected task id.
- `whatChanged`: allowed files changed and why each change maps to acceptance.
- `evidence`: concrete proof such as doc sections added, schema/fixture parse checks, validation pass, or scoped blocked reason.
- `validation`: exact commands run and result.
- `remainingGaps`: missing acceptance, missing validation, unresolved authority, human decision, or none.
- `driftLoopStatus`: whether drift was avoided, which loop fingerprint was seen, or why no loop remains.
- `builderPosture`: unblock artifact produced, builder unblocked, next unblock artifact named, or exact reason the lane stayed review-only.
- `finishLinePosture`: phase finish line reached, narrowed, or redirected; list excluded fields that should not reopen the phase.
- `nextStepClarity`: the next eligible task, repacketization need, human review need, audit need, or queue exhaustion.
- `nextStepType`: `samePromptAgain`, `repacketize`, `humanReview`, `externalAudit`, `commitScopeReview`, `blocked`, or `queueExhausted`.

## Handoff Reference Rule

A handoff should reference current source files instead of retelling the whole history:

- Latest active queue: `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- Latest compact context: `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- Latest prompt checklist: `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md`
- Latest progress ledger and loop fingerprints: `docs/fleet/anti-loop/PROGRESS_LEDGER_AND_LOOP_FINGERPRINTS.md`
- Latest drift/stop/repacketization rules: `docs/fleet/anti-loop/DRIFT_STOP_AND_REPACKETIZATION.md`
- Latest validation summary schema: `templates/validation-output-summary-schema.json`
- Latest external audit digest schema: `templates/external-audit-intake-digest-schema.json`

The next allowed move should be one of:

- run the same one-task prompt again for the next eligible task
- switch to the blocker-resolution builder for the named unblock artifact
- batch merge at a checkpoint before starting the next builder
- repacketize with the latest failure fingerprint and remaining gap
- request human review for an exact decision
- prepare an evidence-only external audit packet after human approval
- stop because the queue is exhausted or blocked

## Evidence-Only Boundary

This checklist cannot approve execution. Prompts, task packets, UI labels, buttons, generated evidence, DOCX reports, audit packages, mobile requests, reviewer output, and queue prose remain evidence only until converted through a bounded local validation path.
