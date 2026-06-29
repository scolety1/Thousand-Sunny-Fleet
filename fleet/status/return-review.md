# Return Review

Generated from local TSF status. Short by design.

## Top recommendation

Review completed GREEN work first, then start the next safe completion run.

## Needs Tim

- Choose the next project.
- Choose availability: here, busy, or away.
- Decide any product direction, conflicting source truth, release/push/deploy approval, secrets/accounts/API keys, migration, archived reactivation, or off-limits file expansion.

## Ready to approve

- No push, release, deploy, install, migration, secrets, remote access, archived reactivation, or product-repo mutation is ready from this file.
- Local TSF console or handoff docs can be reviewed after tests pass, but this file does not approve anything by itself.

## Done while away

- Routine GREEN work and archived project noise can stay collapsed unless Tim wants details. 16 archived projects remain locked.
- Local status shows active/unarchived projects: PrivateLens. Archived projects stay locked.

## Blocked / unsafe

- Unsafe work remains blocked: product repos without selection, archived projects without reactivation, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, and command-running browser controls.

## Next best work session

Quick review, 5-10 minutes. Read Fleet Console first, skim this file if needed, then send one bounded work order.

## Suggested next Codex prompt

~~~text
Project: <project name>
Repo path: <repo path>
Goal: <plain English goal>
Files/artifacts: <files, folders, or C:\TSF_INBOX\<project_name>\ artifacts>
Off-limits: product repos unless selected, archived projects unless reactivated, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, command-running browser controls.
Autonomy/availability mode: here | busy | away | completion_first_sleep_run
Stop conditions: conflicting source truth, missing approval, unsafe file scope, failed validation that cannot be safely repaired, or any forbidden action.
Validation expectations: keep moving through safe next steps, run relevant local checks, and locally commit GREEN completed work when explicitly allowed.
Final report format: morning scoreboard by project: DONE, COMMIT, CHECKS, STATUS, TIM REVIEW.
~~~

## Safety notes

- Local status: request-only travel mode; supervisor not running; emergency none requested. Reports are proof of completed work, not the product. The desktop console has a completion cockpit and Work Order Library copy/paste prompts.
- Travel posture: phone status and request cockpit only.
- Based on local fleet status, console docs, project-management guidance, and safe fallback fixtures.
- Evidence only. No product repo inspection, no archived project reactivation, no proof run, no push, no deploy, no install, no migration, no secrets, no remote access, no hosted UI, and no command-running browser control.
