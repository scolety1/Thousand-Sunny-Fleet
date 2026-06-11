# Thousand Sunny Fleet Phone HQ

Status: static public phone-accessible dashboard.

Hosted dashboard: [Thousand Sunny Fleet HQ](https://scolety1.github.io/Thousand-Sunny-Fleet/)

Use this page from your phone while traveling. It is a static GitHub Pages dashboard, not a live command/control app. It does not run code, configure remote access, expose ports, approve product work, trigger GitHub Actions, execute Codex, or grant extra authority.

Security model: [PHONE_HQ_SECURITY_MODEL.md](PHONE_HQ_SECURITY_MODEL.md)
Post-publish verification packet: [PHONE_HQ_POST_PUBLISH_VERIFICATION.md](PHONE_HQ_POST_PUBLISH_VERIFICATION.md)

## Open First

- Latest Fleet status: [fleet/status/current.md](../../fleet/status/current.md)
- Today log: [fleet/status/today.md](../../fleet/status/today.md)
- Quick mission request: [fleet/control/quick-mission.md](../../fleet/control/quick-mission.md)
- Mission control: [fleet/control/mission.md](../../fleet/control/mission.md)
- Emergency stop request: [fleet/control/emergency.md](../../fleet/control/emergency.md)
- Travel Codex prompt packet: [REMOTE_TRAVEL_CODEX_THIN_PROMPT_PACKET.md](REMOTE_TRAVEL_CODEX_THIN_PROMPT_PACKET.md)
- Travel landing checklist: [REMOTE_TRAVEL_LANDING_CHECKLIST_2026_06_10.md](REMOTE_TRAVEL_LANDING_CHECKLIST_2026_06_10.md)
- Post-publish verification packet: [PHONE_HQ_POST_PUBLISH_VERIFICATION.md](PHONE_HQ_POST_PUBLISH_VERIFICATION.md)

## Link And Asset Integrity

The public dashboard must keep these entry points visible and request-only: latest status, today log, quick mission request, emergency stop request, mission control, travel Codex prompt packet, and security model.

Static assets must stay local under `docs/assets`. Do not add external scripts, external stylesheets, analytics, trackers, ad scripts, external font CDNs, external images, iframes, command backends, GitHub Actions triggers, or browser-held credentials.

If a future external link opens in a new tab, it must use `rel="noopener noreferrer"`. Link presence is navigation only; it is not authority to execute, approve, deploy, stage, commit, push, or mutate product repos.

## Phone Workflow

1. Read `fleet/status/current.md`.
2. If status is enough, do nothing.
3. If you need to leave a safe request, edit `fleet/control/quick-mission.md`.
4. Keep `Status: draft` while writing.
5. Set `Status: requested` only after the one task, desired project, requested files, validation requested, forbidden operations, and next checkpoint are clear.
6. Wait for later HQ/Codex review to convert the request into a one-task packet with `readFirst`, `allowedFiles`, `validationCommands`, `stopIf`, and report format.

Phone edits are requests. They are not execution authority, approval, deploy permission, product-repo permission, or runtime command binding.

Quick mission requests are one-task request records. They can express `best_value` or `perfection` quality mode and a requested model tier, but model routing and cost-quality recommendations still happen later during HQ/Codex review.

## Stale Or Active-Looking Status

The dashboard treats loaded status as view-only public status, not authority. If the public status text looks stale, contradictory, or active-looking, including `ACTIVE`, `push=True`, all-fleet, overnight, deploy, stage, commit, push, install, migration, phone approval, or runtime command binding language, treat it as caution-only and follow request-only rules.

If live status loading fails, open the Latest Fleet status link manually. Do not use unsafe workarounds, do not configure remote access, do not trigger GitHub Actions, and do not execute Codex from phone text.

## Safe From Phone

- Read latest status.
- Read today log.
- Capture a narrow idea.
- Submit a bounded quick mission request.
- Request a cooperative emergency stop by editing `fleet/control/emergency.md`.

Emergency stop requests use `Emergency: REQUEST_STOP` and non-secret fields only. They are high-priority signals for later safe handling, not command execution, process killing, phone approval, runtime command binding, or product-repo authority.

## Not Safe From Phone

Do not use phone text or GitHub edits to approve:

- product-repo mutation
- all-fleet commands
- overnight runners
- deploys
- installs or dependency changes
- migrations
- secrets, auth, payments, or credentials
- lock deletion
- permission widening
- remote access configuration
- runtime command binding
- GitHub Actions execution
- direct Codex command execution
- public dashboard command buttons

## Laptop Or Desktop Required

Use laptop or Chrome Remote Desktop into the home PC when you need:

- Codex Desktop
- terminal checks
- local validation
- commits or pushes
- any code change
- any project repo inspection

Before starting laptop or desktop Codex work while traveling, use the [Remote Travel Landing Checklist](REMOTE_TRAVEL_LANDING_CHECKLIST_2026_06_10.md). It separates phone-only status/request actions from laptop/desktop Codex work and keeps repo cleanliness, request-only posture, stop signs, and validation checks in view.

## Current Travel Rule

Remote access is not extra authority. Operational travel readiness remains YELLOW until the Tuesday off-network rehearsal is completed and recorded.

## If Something Looks Wrong

Stop and classify:

- GREEN: status is readable and no stop signs appear.
- YELLOW: status is stale, unclear, or needs laptop/desktop verification.
- RED: a path would require secrets, public RDP, router changes, product repo mutation, all-fleet, overnight, deploy, staging, commit, push, migrations, lock deletion, permission widening, or remote command binding.

## Emergency Stop Request Rules

- Use `REQUEST_STOP` only as a cooperative request/signal.
- Do not include PINs, passwords, MFA, recovery codes, keys, tokens, credentials, private screenshots, private device identifiers, customer data, or product data.
- Do not ask the public dashboard or phone text to run commands, stop processes, configure remote access, trigger GitHub Actions, mutate product repos, run all-fleet, run overnight, deploy, stage, commit, push, install, migrate, delete locks, widen permissions, approve phone actions, or bind runtime commands.
- A later HQ/Codex review must repacketize any stop handling into one bounded task before work starts.
