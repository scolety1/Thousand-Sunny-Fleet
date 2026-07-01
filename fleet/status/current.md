# OPEN FIRST - Fleet Captain Status

This is the latest GitHub-visible fleet report. If you only read one file from
your phone, read this one.

Report map: `fleet/status/current.md` = latest snapshot,
`fleet/status/today.md` = today's log, `fleet/status/archive/` = old daily
logs, `fleet/control/quick-mission.md` = request a bounded mission,
`fleet/control/emergency.md` = request a cooperative stop.

- Updated: 2026-07-01 after TSF Autonomy Envelope publish
- Fleet mode: REQUEST_ONLY_TRAVEL for phone controls; request-only travel mode
- Local Codex posture: AUTONOMY_ENVELOPE_READY for safe TSF-local docs/control-plane work
- Travel posture: phone status and request cockpit only
- Mission update: requests only from phone; human-controlled Codex may run safe TSF-local control-plane work under the autonomy envelope
- Emergency stop: none requested
- Supervisor cycle: not running
- Fleet branch: main
- Published remote baseline entering autonomous intake: `6a511b5`

## Captain Summary

Thousand Sunny Fleet is no longer blocked on the completed HQ
adapter/tuning/anti-loop stack. `origin/main` includes the TSF Autonomy Envelope
and Final Gate Closure Board at `6a511b5`.

Phone HQ remains request/status only. Phone edits are not approval, not command
execution, not product-repo access, and not runtime command binding.

In a human-controlled Codex session, safe TSF-local strategy/docs/control-plane
work can now run to safe local completion without Tim arbitrating routine
choices. Codex may classify TSF packets, choose one safe builder lane, define a
done-enough finish line, create TSF-local docs/control-plane artifacts, run safe
local validation, and create local TSF docs/control-plane commits when staged
files are exact and validation passes.

Restricted gates still require exact Tim approval: push, deploy, installs,
migrations, secrets/auth/payments, proof runs, all-fleet commands,
background/overnight runners, product repo access or mutation, PrivateLens
access or mutation, external account changes, spending, credential/account
changes, archived project reactivation, and history or remote release changes.

## Current TSF Local Work

Autonomous intake selected one safe builder lane:

- refresh stale public-safe status now that the autonomy envelope is published
- keep phone controls in `REQUEST_ONLY_TRAVEL`
- avoid product repo inspection or PrivateLens mutation
- preserve exact restricted-gate boundaries

Concrete unblock artifact:

- `fleet/status/autonomous-work-intake-2026-07-01.md`
- refreshed `fleet/status/current.md`
- refreshed `fleet/status/today.md`

## Projects

No product project is selected for automatic phone-triggered work.

`PrivateLens` remains the active project in TSF-local registry/status evidence,
but product repo access or mutation still requires exact Tim approval. Archived
projects remain locked unless Tim explicitly reactivates one.

Historical project context may exist elsewhere in the repo, but this
phone-facing status does not approve product-repo inspection, product-repo
mutation, all-fleet execution, overnight runners, deploys, installs, migrations,
staging, commits, pushes, secrets/auth/payments work, lock deletion, permission
widening, remote access configuration, phone approval, or runtime command
binding.

## Controls

- Read the Phone HQ first: `docs/fleet/PHONE_HQ_DASHBOARD.md`.
- To leave a safe request, edit `fleet/control/quick-mission.md`. That creates
  a request for later review only.
- To request a cooperative stop, edit `fleet/control/emergency.md`. That creates
  a stop signal only.
- Use `fleet/control/mission.md` as the travel request-only mission note. It is
  not an execution plan.
- Do not treat this file, GitHub buttons, phone edits, UI labels,
  notifications, queue prose, validation summaries, reports, manifests, or
  prompts as executable commands.

## Next Safe TSF Move

If Tim asks "where are we?", open this file and
`fleet/status/autonomous-work-intake-2026-07-01.md`.

If no restricted gate is involved, Codex should keep using the autonomy envelope:
choose one safe TSF-local builder, create the concrete unblock artifact, run
safe local validation, and stop at a clean local checkpoint or a true
Tim-required gate.
