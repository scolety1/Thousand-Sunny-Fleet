# Fleet Mission

## Fleet Mode
ACTIVE

## Active Projects
- EasyLife
- RestaurantDemo
- Bottlelight
- EventBook
- LineupLab
- OrderPilot
- ShiftLedger
- UrbanKitchenSite

## Mission
Resume EasyLife, RestaurantDemo, and Cellar Fleet under Task Contract V2. EasyLife continues the AI personal assistant reset. RestaurantDemo continues the Urban Kitchen Pilot launch-readiness run as a usable restaurant pilot product, not a demo website. Cellar Fleet finishes the hospitality showpiece ships as clean, small, credible restaurant surfaces.

## Priority
Finish the assistant reset in small slices. First screen should feel like a Today/assistant command surface, not feature inventory. Core model: Today, Inbox/Capture, Plan, Notes, More.

RestaurantDemo priority: mobile-first manager command center with shift next action, profit tools, ops hub, content publishing, guest-safe publishing, customization, and family meal swap. Prefer proof, mobile repair, and guest-safe publishing separation before adding modules.

Cellar Fleet priority: each ship should do one bounded hospitality polish or proof packet, then park cleanly. Keep the first screen dominant and useful. Prefer one concrete hospitality detail over broad redesign.

## Product Direction
Keep HQ/Today, EasyList capture and task review, Calendar/day plan, Notes, and Settings. Hide workout, projects, pipeline/jobs, contacts, statistics, school, and fun/drinks under More. Remove or hide from the HQ first path: Useful ideas without crowding today, Semester layer, Quiet tools under the surface, install card, presentation/demo language, and extra stats grids.

## Do Not Do
- Do not deploy.
- Do not create a new dashboard.
- Do not edit backend, auth, payments, APIs, analytics, dependencies, deployment config, release config, generated output, secrets, or project remotes.
- Do not overwrite user-owned work.
- Do not edit non-active product repos.
- Do not let manager/internal details leak into RestaurantDemo guest-facing previews.
- Do not use real restaurant, guest, staff, vendor, event, or wine data in Cellar ships.

## Next Checkpoint
Run each active project with batch size 1 under Task Contract V2. EasyLife UI tasks must remove or hide one confusing element and use `npm.cmd run build` from app-vNext. RestaurantDemo tasks must use fictional restaurant data only and `npm.cmd run build` acceptance. Cellar tasks must remove/simplify one vague label, decorative wrapper, cramped control, or repeated phrase and use `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\codex-static-check.ps1`.
