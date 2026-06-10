# Thousand Sunny Fleet Phone HQ

Status: first phone-accessible control surface.

Use this page from your phone while traveling. It is a GitHub-rendered dashboard, not a live web app. It does not run code, configure remote access, expose ports, approve product work, or grant extra authority.

## Open First

- Latest Fleet status: [fleet/status/current.md](../../fleet/status/current.md)
- Today log: [fleet/status/today.md](../../fleet/status/today.md)
- Quick mission request: [fleet/control/quick-mission.md](../../fleet/control/quick-mission.md)
- Mission control: [fleet/control/mission.md](../../fleet/control/mission.md)
- Emergency stop request: [fleet/control/emergency.md](../../fleet/control/emergency.md)
- Travel Codex prompt packet: [REMOTE_TRAVEL_CODEX_THIN_PROMPT_PACKET.md](REMOTE_TRAVEL_CODEX_THIN_PROMPT_PACKET.md)

## Phone Workflow

1. Read `fleet/status/current.md`.
2. If status is enough, do nothing.
3. If you need to leave a safe request, edit `fleet/control/quick-mission.md`.
4. Set `Status: SUBMIT` only after the goal, priority, target project, and next checkpoint are clear.
5. Wait for a desktop/local remote-control cycle to apply the request.

Phone edits are requests. They are not execution authority.

## Safe From Phone

- Read latest status.
- Read today log.
- Capture a narrow idea.
- Submit a bounded quick mission request.
- Request a cooperative emergency stop by editing `fleet/control/emergency.md`.

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

## Laptop Or Desktop Required

Use laptop or Chrome Remote Desktop into the home PC when you need:

- Codex Desktop
- terminal checks
- local validation
- commits or pushes
- any code change
- any project repo inspection

## Current Travel Rule

Remote access is not extra authority. Operational travel readiness remains YELLOW until the Tuesday off-network rehearsal is completed and recorded.

## If Something Looks Wrong

Stop and classify:

- GREEN: status is readable and no stop signs appear.
- YELLOW: status is stale, unclear, or needs laptop/desktop verification.
- RED: a path would require secrets, public RDP, router changes, product repo mutation, all-fleet, overnight, deploy, staging, commit, push, migrations, lock deletion, permission widening, or remote command binding.

