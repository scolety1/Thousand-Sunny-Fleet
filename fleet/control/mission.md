# Fleet Mission

## Fleet Mode
ACTIVE

## Active Projects
- EasyLife

## Mission
Resume EasyLife under Task Contract V2. Rebuild EasyLife from separate app suite/dashboard into one clean AI personal assistant.

## Priority
Finish the assistant reset in small slices. First screen should feel like a Today/assistant command surface, not feature inventory. Core model: Today, Inbox/Capture, Plan, Notes, More.

## Product Direction
Keep HQ/Today, EasyList capture and task review, Calendar/day plan, Notes, and Settings. Hide workout, projects, pipeline/jobs, contacts, statistics, school, and fun/drinks under More. Remove or hide from the HQ first path: Useful ideas without crowding today, Semester layer, Quiet tools under the surface, install card, presentation/demo language, and extra stats grids.

## Do Not Do
- Do not deploy.
- Do not create a new dashboard.
- Do not edit backend, auth, payments, dependencies, release config, generated output, secrets, or project remotes.
- Do not overwrite user-owned work.
- Do not edit non-EasyLife product repos.

## Next Checkpoint
Run EasyLife only with batch size 1 under Task Contract V2. Every UI task must remove or hide one confusing element and use `npm.cmd run build` from app-vNext as acceptance.
