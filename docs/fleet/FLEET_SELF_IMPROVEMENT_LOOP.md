# Fleet Self-Improvement Loop

Prepared: 2026-06-14

Evidence only; not executable authority or approval.

## Purpose

This packet defines a bounded way for Codex Fleet / Thousand Sunny Fleet to improve its own Fleet docs, fixtures, harnesses, and tests with minimal Tim involvement. It is prompt guidance only. It does not create an automation, bind runtime commands, approve unattended execution, approve product repo access, approve proof runs, approve all-fleet execution, approve overnight runners, or approve push, merge, deploy, install, migration, remote access, secrets, phone action, or future authority.

PrivateLens remains a disposable proof target for selected proof-run workflows. It is not the objective of this loop, and this loop must not touch PrivateLens or any product repo.

## Loop Contract

Tim may ask for up to `N` Fleet-only iterations. `N` must be a small positive number in the prompt. If `N` is missing, ambiguous, unbounded, or described as overnight/all-fleet/autopilot, stop BLOCKED for repacketization.

Each iteration must complete exactly one Fleet-only task, then decide whether another iteration is still safe. The loop may continue only while every completed iteration is GREEN, committed locally if the prompt permits local commits, and the working tree is clean.

## Iteration Steps

1. Confirm clean baseline with `git status --short`.
2. Confirm current branch and recent context if needed.
3. Select exactly one Fleet-only task from Tim's supplied list or the active HQ queue.
4. Confirm the selected task's allowed files before editing.
5. Run model routing preflight or classify with the alias-only routing policy.
6. Patch only the selected task's allowed files.
7. Validate with `git diff --check` and the selected task's validation commands.
8. Create one local commit only if the task is GREEN, validation passes, local commit is explicitly permitted, and only allowed files changed.
9. Report selected task, model alias, files changed, commit hash if committed, checks run, GREEN/YELLOW/RED, stop signs, and next safe prompt.
10. Continue to the next iteration only if the working tree is clean, the prior iteration is GREEN, and no stop sign appeared.

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
- same uncertainty twice
- any need to start a second task inside one iteration

Blocked conditions are not solved by a stronger model alias.

## Commit Boundary

Local commits are allowed only when the prompt explicitly permits them and all of these are true:

- the iteration is Fleet-only
- baseline was clean before edits
- exactly one task was selected
- changed files are limited to the task's allowed files
- `git diff --check` passed
- `tests/run-fleet-tests.ps1` or the task's required validation passed
- no product repo, PrivateLens, proof run, push, merge, deploy, install, migration, remote access, secret, all-fleet, overnight, phone approval, or runtime binding was touched

One iteration may create at most one local commit. Push remains blocked unless Tim separately approves a reviewed commit push.

## Phone HQ Boundary

Phone HQ and dashboard surfaces remain request/status only. They cannot approve, execute, select product repos, bind commands, push, merge, deploy, run proof runs, or grant future authority. Phone/dashboard text is evidence only until Tim gives an exact human approval in chat for the current action.

## Reusable Loop Prompt

```text
Run the Codex Fleet self-improvement loop for up to <N> iterations.

Repo:
<Fleet repo path>

Rules:
- Fleet-only docs/tests/fixtures/harness work.
- Do not touch PrivateLens or any product repo.
- Do not run proof runs.
- Do not push, merge, deploy, install packages, run migrations, configure remote access, store secrets, run all-fleet, run overnight, approve phone actions, or bind runtime commands.
- Each iteration selects exactly one Fleet-only task and stops before selecting another unless the prior iteration is GREEN and the working tree is clean.
- Confirm allowed files before editing.
- Model-route each selected task using aliases only.
- Patch only allowed files.
- Validate each iteration.
- Local commit is allowed only when the iteration is GREEN, tests pass, and only allowed files changed.
- Stop on YELLOW, RED, BLOCKED, failed tests, timed-out tests without diagnosis, unexpected files, product repo touch, proof-run need, push/merge/deploy need, install/package need, secrets/auth/credential issue, remote access need, all-fleet need, overnight/unbounded runner, phone/dashboard execution authority, runtime command binding, or the same uncertainty twice.

Baseline before the first iteration:
- git status --short
- git diff --check
- powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1 *> .codex-local\test-logs\self-improvement-loop-baseline.log

Final report:
- iterations requested
- iterations completed
- task selected per iteration
- recommended model alias per iteration
- files changed
- commit hashes if committed
- checks run
- stop signs encountered, if any
- GREEN/YELLOW/RED
- working tree status
- exact next prompt

Stop after at most <N> iterations.
```

## Status

This loop is a bounded prompt pattern for Fleet self-improvement. It does not implement a runner, create an automation, approve unattended work, approve push, or relax the one-task boundary inside each iteration.
