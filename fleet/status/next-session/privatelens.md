# Next Session Card - PrivateLens

Short TSF Daily Driver card. Evidence only; not executable authority or approval.

## Open This First

- First after Fleet Console: this card, fleet/status/next-session/privatelens.md
- Then: fleet/status/return-review.md for the latest handoff context.
- Then: fleet/status/project-passports/privatelens.md for repo path, status, guardrails, blockers, and validation hints.
- Stop before product repo access until Tim explicitly approves read-only inspection for this selected project.

## Current Status

- Status: active
- TSF verdict: status UNKNOWN; branch unknown; clean unknown
- Latest note: Registered project is not available on this machine.

## What Needs Tim

- Decide whether to approve read-only repo inspection on this desktop. TSF-local status is UNKNOWN and says: Registered project is not available on this machine. Until Tim approves that inspection, stay inside TSF outputs.

## What Codex Can Do Next

- Codex can reconcile TSF-local status, return review, passport, triage, and inbox evidence, then draft the exact read-only inspection request. It must stop before opening the product repo.

## Suggested Work Order

~~~text
Project: PrivateLens
Repo path: C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-privatelens\outputs\privatelens
Goal: Use TSF-local Daily Driver files to explain why this project needs Tim, reconcile the unclear status, and draft the exact read-only repo-inspection approval request; do not open the product repo.
Files/artifacts: fleet/status/project-passports/privatelens.md; fleet/status/next-session/privatelens.md; optional C:\TSF_INBOX\PrivateLens\ files named by Tim
Product repo access: Stop before product repo access: Tim must explicitly approve read-only inspection of this selected repo path on this desktop.
Off-limits: product repo mutation unless a later bounded work order names exact allowed files, archived projects unless reactivated, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, command-running browser controls.
Autonomy/availability mode: here | busy | away
Stop conditions: need to inspect the product repo before Tim approves read-only inspection, need to mutate product files before exact allowed files are named, conflicting source truth, unsafe scope, failed validation that cannot be safely repaired, or any forbidden action.
Validation expectations: run only TSF-local checks unless Tim approves selected-project validation.
Final report format: verdict, what Tim needs to decide, files read, blockers, next safe action, safe-to-commit status.
~~~

## Stop Conditions

- Product repo inspection is required before Tim explicitly approves read-only inspection for this selected project.
- Product repo mutation is required before exact allowed files are named in a later bounded work order.
- Archived reactivation, push, deploy, install, migration, secrets, remote access, proof run, or all-fleet execution is requested.
- Validation fails and the repair is outside the approved TSF-local scope.

## What Can Wait

- Archived projects, broad proof runs, publication, deployment, installs, migrations, secrets, and remote access.
