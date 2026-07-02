# PrivateLens First Work Session Draft

Prepared: 2026-07-02

Draft only; NOT APPROVED. Use only after PrivateLens read-only inspection is completed and Tim gives exact approval for a bounded work session.

## Inspection Findings Placeholder

Fill this section after read-only inspection:

- repo path inspected:
- branch:
- HEAD:
- working tree:
- test/build commands discovered:
- safest candidate files:
- blockers:
- recommended first task:

## Likely Goals

Possible first safe work session goals, depending on inspection evidence:

- fix one small visible bug or UI/documentation issue
- add one missing local validation guard
- update one README or product-local handoff doc
- create one bounded task list from real repo evidence

## Bounded Task Format

```text
Project: PrivateLens
Mode: bounded_implementation or review_only
Inspection evidence: <paste inspection summary>
Goal: <one concrete task>
Allowed files: <exact files>
Forbidden files: secrets, auth, payments, deploy config, migrations, unrelated product files
Validation: <exact safe local command(s), no installs unless separately approved>
Stop conditions: dirty ambiguity, need to widen files, failed validation after one safe repair, secret/auth/payment/deploy/migration/proof-run/push/all-fleet/background/external-account action needed
Final report: changed files, validation, commit status, remaining blockers, next safe action
```

## Validation Expectations

- Prefer existing local scripts already present in the repo.
- Do not install dependencies.
- Do not run migrations.
- Do not run proof runs.
- Do not push.
- Do not touch secrets/auth/payments/deploy material.
- If validation cannot run safely, report why and stop.

## Stop Conditions

Stop if:

- read-only inspection has not been approved and completed
- exact allowed files are not named
- mutation would touch secrets/auth/payments/deploy/migration areas
- product direction is unclear
- archived project reactivation is implied
- validation requires install, migration, proof run, all-fleet command,
  background runner, external account, or push

## Non-Authority Reminder

This is a follow-up draft only. It does not approve PrivateLens mutation, repo
inspection, staging, commit, push, deploy, install, migration, proof run, or
secret/auth/payment work.
