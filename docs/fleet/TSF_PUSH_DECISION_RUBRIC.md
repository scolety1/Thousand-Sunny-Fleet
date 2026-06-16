# TSF Push Decision Rubric

Prepared: 2026-06-16

Evidence only; not executable authority or approval.

## Current Remote GREEN Baseline

Current remote GREEN baseline:

```text
b03def2a72049cc904c42170fc7ffb7727f7edc8
```

This rubric helps Tim decide whether to approve a push after Codex reports `Ready for Tim to decide whether to approve push.` It builds on `TSF_RUNWAY_HANDOFF_SYSTEM.md`, `TSF_BASELINE_LEDGER_AND_REPORT_INTAKE.md`, and `TSF_VALIDATION_TIMEOUT_AND_RERUN_POLICY.md`.

It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, permission widening, or static GitHub Pages command execution.

## Core Rule

A push decision is allowed only after a GREEN push-readiness review for the exact local commit. `Ready for Tim to decide` is not itself push approval.

Tim must explicitly approve pushing the exact reviewed commit before Codex may run `git push origin main`. A queue entry, Codex report, validation log, static dashboard, phone request, generated packet, or rubric recommendation cannot approve push by itself.

## Approval Helper Facts

Before recommending a decision, the approval helper must explain:

- commit hash
- commit purpose
- files changed
- current remote baseline
- new remote baseline after push
- whether changes are docs/tests/harness only
- whether product repos and PrivateLens remained untouched
- whether proof runs remained blocked
- whether full Fleet tests completed GREEN
- whether any YELLOW/RED caveats remain

If any fact is missing, stale, mismatched, or ambiguous, the helper must recommend `HOLD / VALIDATE AGAIN`, `DO NOT PUSH`, or `STOP AND ASK HQ`.

## Decision Labels

| Label | Meaning | Correct next action |
| --- | --- | --- |
| `APPROVE PUSH` | All review and validation gates are GREEN, the exact commit and baseline match, and Tim may explicitly approve the push. | Tim may send a push approval prompt for the exact commit. |
| `HOLD / VALIDATE AGAIN` | The change appears potentially safe, but validation evidence is incomplete, stale, timed out, old-log based, repeated, or ambiguous. | Run a validation-only rerun with a new log path. |
| `DO NOT PUSH` | A safety, validation, scope, or boundary problem is present. | Stop and request a bounded repair or review prompt. |
| `STOP AND ASK HQ` | The repo, path, baseline, report, target commit, or authority is unclear. | Ask Tim for a refreshed packet or exact decision. |

## Recommend `APPROVE PUSH` Only When

Recommend `APPROVE PUSH` only when all gates are true:

- commit content review is GREEN
- validation is GREEN
- working tree is clean
- HEAD matches reviewed commit
- remote baseline matches expected prior baseline
- no boundary was crossed
- changed files are Fleet-only and match the reviewed scope
- full Fleet tests completed GREEN in the current requested log path
- no YELLOW/RED caveats remain

Even then, Codex must wait for Tim's separate explicit push approval before pushing.

## Hold Or Stop Conditions

Recommend `HOLD / VALIDATE AGAIN` if:

- full suite timed out
- old logs were reused
- report is repeated or stale
- repo, path, or baseline mismatch exists
- local commit is not the reviewed commit
- dirty tree exists
- validation log lacks final `Codex Fleet tests passed.`
- any product, PrivateLens, proof-run, deploy, phone, remote-access, runtime-binding, all-fleet, overnight, install, migration, secret, merge, or push boundary is ambiguous

Recommend `DO NOT PUSH` if the review finds a real failed validation, changed files outside approved scope, product repo or PrivateLens touch, unauthorized proof run, widened authority, weakened tests, secret exposure, deploy/install/migration request, runtime command binding, or static GitHub Pages command-execution claim.

Recommend `STOP AND ASK HQ` if the input is wrong-project text, stale packet text, contradictory report evidence, missing baseline, missing commit hash, unclear decision owner, or a request to infer approval from a report.

## Standard "What Am I Pushing?" Answer

Use this template before Tim decides:

```text
You would be pushing:
- Commit: <commit hash> - <commit purpose>
- Files: <tracked files changed>
- Current remote baseline: <origin/main before push>
- New remote baseline after push: <commit hash>
- Scope: docs/tests/harness only? <yes/no>
- Product repos and PrivateLens untouched? <yes/no>
- Proof runs blocked? <yes/no>
- Full Fleet tests GREEN? <yes/no, log path>
- Caveats: <none or YELLOW/RED items>

Recommended decision: <APPROVE PUSH | HOLD / VALIDATE AGAIN | DO NOT PUSH | STOP AND ASK HQ>
```

This answer is decision support only. It does not approve or run the push.

## Standard Codex Push-Approval Prompt

Use this template only after Tim decides to approve:

```text
Tim explicitly approves pushing TSF commit <commit hash> to remote main.

Repo:
<TSF repo path>

Current remote GREEN baseline:
<expected prior origin/main hash>

This push is approved only for the already-reviewed TSF/Codex Fleet commit <commit hash>.

Do not patch files.
Do not create new commits.
Do not touch product repos or PrivateLens.
Do not run proof runs.
Do not install packages.
Do not run migrations.
Do not configure remote access.
Do not store secrets.
Do not approve phone actions.
Do not bind runtime commands.
Do not run all-fleet.
Do not run overnight.
Do not merge or deploy.

Before pushing, confirm:
- branch is main
- HEAD is <commit hash>
- working tree is clean
- git diff --check origin/main..HEAD passes
- the push-readiness review was GREEN

Then run:
- git push origin main

After pushing, verify:
- git status --short
- git ls-remote origin refs/heads/main
- remote main contains <commit hash>

Return:
- Push result
- Final remote baseline hash
- Final git status --short
- Confirmation boundaries remained preserved
- Overall verdict: GREEN, YELLOW, or RED
```

## Status

This document is a push decision aid. It does not implement a runner, queue executor, phone bridge, product adapter, proof-run pathway, push pathway, or static GitHub Pages command mechanism.
