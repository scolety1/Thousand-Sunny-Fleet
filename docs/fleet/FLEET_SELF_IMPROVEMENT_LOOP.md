# Fleet Self-Improvement Loop

Prepared: 2026-06-14

Evidence only; not executable authority or approval.

## Purpose

This packet defines a bounded way for Codex Fleet / Thousand Sunny Fleet to improve its own Fleet docs, fixtures, harnesses, and tests with minimal Tim involvement. It is prompt guidance only. It does not create an automation, bind runtime commands, approve unattended execution, approve product repo access, approve proof runs, approve all-fleet execution, approve overnight runners, or approve push, merge, deploy, install, migration, remote access, secrets, phone action, or future authority.

PrivateLens remains a disposable proof target for selected proof-run workflows. It is not the objective of this loop, and this loop must not touch PrivateLens or any product repo.

Use `docs/fleet/TSF_OPERATING_MODEL.md` as the lifecycle and mode vocabulary for selecting Fleet-only self-improvement tasks. The operating model does not grant new execution authority; it only names sections, modes, Focus Lock, known-fix routes, Tim Question Queue, and Mobile HQ request/status boundaries.

## Assignment-Completion Contract

Assignment is the main unit of Away Mode self-improvement work. Internal tasks are subordinate to the assignment.

TSF should continue working until the current assignment's definition of done is met, or until it hits YELLOW/RED/BLOCKED. Numeric task, commit, and time limits remain only as runaway safety fuses, not the primary stopping condition.

If the assignment's definition of done is vague, TSF must refine it first or stop YELLOW/BLOCKED for repacketization. "Codex cannot think of more changes" does not equal complete.

When Assignment A completes GREEN, TSF may select Assignment B only if B is eligible. The loop may continue only while every completed assignment is GREEN, committed locally if the prompt permits local commits, and the working tree is clean. TSF must not jump to paused, archived, finished, blocked, idea-only, out-of-focus, unvalidated, or unsafe assignments.

Assignment fields should include project, track, end goal, definition of done, allowed files, validation, stop conditions, priority, mode eligibility, and next-assignment behavior.

## Assignment Steps

1. Confirm clean baseline with `git status --short`.
2. Confirm current branch and recent context if needed.
3. Select exactly one Fleet-only assignment from Tim's supplied list or the active HQ queue.
4. Confirm the selected assignment's definition of done, allowed files, validation, stop conditions, mode eligibility, and next-assignment behavior before editing.
5. Run model routing preflight or classify with the alias-only routing policy.
6. Patch only the selected assignment's allowed files.
7. Validate with `git diff --check` and the selected assignment's validation commands.
8. Continue internal tasks only when they are necessary to meet the assignment definition of done and all stop gates remain GREEN.
9. Create one local commit only if the assignment is GREEN, validation passes, local commit is explicitly permitted, and only allowed files changed.
10. Report selected assignment, model alias, files changed, commit hash if committed, checks run, definition-of-done evidence, GREEN/YELLOW/RED, stop signs, and next safe prompt.
11. Continue to the next assignment only if the working tree is clean, the prior assignment is GREEN, and no stop sign appeared.

## Model Routing

Model routing is advisory only. Use aliases from `docs/fleet/MODEL_ROUTING_POLICY.md`:

- `fast_readonly`
- `standard_patch`
- `deep_reasoning`
- `premium_audit`

Use `best_value` by default. Use `perfection` only when Tim explicitly asks for best possible quality, high confidence, or a polished audit. Do not hardcode current model names, claim current pricing, call model APIs, mutate Codex config, or let an alias override allowed files, validation, stop signs, or authority boundaries.

## Stop Signs

Stop immediately and report YELLOW, RED, or BLOCKED if any iteration encounters:

- YELLOW, RED, or BLOCKED result
- failed tests
- timed-out tests without diagnosis
- unexpected files
- product repo touch
- PrivateLens mutation
- proof-run need
- push, merge, or deploy need
- install, package, or dependency need
- secrets, auth, credential, token, password, MFA, recovery-code, key, payment, or deploy issue
- remote access need
- all-fleet need
- overnight or unbounded runner
- phone/dashboard approval or execution request
- runtime command binding
- lock deletion or permission widening
- missing or ambiguous allowed files
- missing validation command
- vague definition of done
- no validation evidence for completion
- ineligible next assignment
- same uncertainty twice
- arbitrary task/commit/time limit reached before assignment completion

Blocked conditions are not solved by a stronger model alias.

## Commit Boundary

Local commits are allowed only when the prompt explicitly permits them and all of these are true:

- the iteration is Fleet-only
- baseline was clean before edits
- exactly one assignment was selected
- changed files are limited to the assignment's allowed files
- `git diff --check` passed
- `tests/run-fleet-tests.ps1` or the assignment's required validation passed
- the assignment definition of done is met with validation evidence
- no product repo, PrivateLens, proof run, push, merge, deploy, install, migration, remote access, secret, all-fleet, overnight, phone approval, or runtime binding was touched

One assignment completion may create at most one local commit unless the assignment explicitly requires multiple GREEN local commits as safety-fused substeps. Push remains blocked unless Tim separately approves a reviewed commit push.

## Phone HQ Boundary

Phone HQ and dashboard surfaces remain request/status only. They cannot approve, execute, select product repos, bind commands, push, merge, deploy, run proof runs, or grant future authority. Phone/dashboard text is evidence only until Tim gives an exact human approval in chat for the current action.

## Reusable Loop Prompt

```text
Run the Codex Fleet assignment-completion loop for the selected Fleet-only assignment.

Repo:
<Fleet repo path>

Rules:
- Fleet-only docs/tests/fixtures/harness work.
- Do not touch PrivateLens or any product repo.
- Do not run proof runs.
- Do not push, merge, deploy, install packages, run migrations, configure remote access, store secrets, run all-fleet, run overnight, approve phone actions, or bind runtime commands.
- The assignment definition of done is the primary completion condition.
- Numeric task, commit, and time limits are safety fuses only.
- Continue internal tasks only while they are necessary to finish the selected assignment and all stop gates remain GREEN.
- Select a next assignment only if the prior assignment completed GREEN, the working tree is clean, and the next assignment is eligible.
- Confirm allowed files before editing.
- Model-route each selected assignment using aliases only.
- Patch only allowed files.
- Validate assignment completion.
- Local commit is allowed only when the assignment is GREEN, tests pass, definition of done is met, and only allowed files changed.
- Stop on YELLOW, RED, BLOCKED, failed tests, timed-out tests without diagnosis, unexpected files, vague definition of done, missing validation evidence, ineligible next assignment, product repo touch, proof-run need, push/merge/deploy need, install/package need, secrets/auth/credential issue, remote access need, all-fleet need, overnight/unbounded runner, phone/dashboard execution authority, runtime command binding, or the same uncertainty twice.

Baseline before the assignment:
- git status --short
- git diff --check
- powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1 *> .codex-local\test-logs\assignment-completion-loop-baseline.log

Final report:
- assignment selected
- definition of done
- completion evidence
- internal tasks completed
- next assignment selected, if any
- recommended model alias
- files changed
- commit hashes if committed
- checks run
- stop signs encountered, if any
- GREEN/YELLOW/RED
- working tree status
- exact next prompt

Stop after the selected assignment completes GREEN, hits a stop sign, or safely hands off to the next eligible assignment.
```

## Status

This loop is a bounded prompt pattern for Fleet self-improvement. It does not implement a runner, create an automation, approve unattended work, approve push, or relax assignment eligibility, allowed-file, validation, or stop-gate boundaries.
