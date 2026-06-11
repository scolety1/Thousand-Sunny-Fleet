# Phone HQ Post-Publish Verification Packet

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Purpose

Use this packet only after Tim separately and explicitly approves staging, committing, pushing, and checking the public GitHub Pages dashboard.

This packet is a checklist only. It does not itself approve staging, commit, push, deploy, GitHub Pages configuration, product work, command execution, phone approval, remote access configuration, all-fleet execution, overnight runner execution, installs, migrations, secrets, lock deletion, permission widening, or future authority.

The hosted Phone HQ remains a public static request/status cockpit, not a command/control backend.

## Expected Static Publish Set

The Phone HQ/security publish set is expected to contain only these Codex Fleet docs, static dashboard files, and local test coverage:

- `README.md`
- `docs/index.html`
- `docs/assets/phone-hq.css`
- `docs/assets/phone-hq.js`
- `docs/fleet/PHONE_HQ_DASHBOARD.md`
- `docs/fleet/PHONE_HQ_SECURITY_MODEL.md`
- `docs/fleet/MOBILE_CONTROL_PLANE_SECURITY_ARCHITECTURE.md`
- `docs/fleet/MOBILE_CONTROL_PLANE_THREAT_MODEL.md`
- `docs/fleet/MOBILE_CONTROL_PLANE_ROADMAP.md`
- `docs/fleet/MOBILE_CONTROL_PLANE_REQUEST_SCHEMA.md`
- `tests/run-fleet-tests.ps1`

If the publish set includes product repos, product data, secrets, credentials, private device identifiers, backend services, authentication code, GitHub Actions wiring, runner integration, dependency installs, migrations, deploy config, or files outside the intended Codex Fleet publish set, stop and request a new one-task review.

## Pre-Push Verification

Run these checks before any separately approved push:

```powershell
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

Confirm the dashboard is still static and public-safe:

- no secrets, tokens, PINs, passwords, MFA material, recovery codes, keys, credentials, private device identifiers, customer data, or product data
- no client-side GitHub personal access token
- no direct Codex command execution from the browser
- no GitHub Actions trigger
- no command backend
- no external scripts
- no external stylesheets
- no trackers, analytics, ad scripts, external font CDNs, external images, or iframes
- external new-tab links, if present, use `rel="noopener noreferrer"`
- phone links and dashboard buttons remain request-only, not approval or execution authority
- emergency stop remains a cooperative request/signal, not arbitrary command execution

## GitHub Pages URL Check

After a separately approved push, check the hosted dashboard URL:

- Hosted dashboard: <https://scolety1.github.io/Thousand-Sunny-Fleet/>

Expected result:

- page loads on phone and desktop
- security banner is visible
- status loading is view-only
- stale or active-looking status is caution-only
- latest status link works
- today log link works
- quick mission request link opens the request file
- emergency stop request link opens the request file
- travel Codex prompt packet link works
- security model link works

Do not sign in, paste secrets, approve work, trigger GitHub Actions, configure remote access, run Codex commands, or perform product-repo work from the public page.

## Phone Smoke Check

From a phone browser, verify:

- top-level status is readable without zooming
- request-only banner is clear
- Safe From Phone and Not Safe From Phone sections are easy to find
- quick mission request is framed as a request only
- emergency stop request is framed as a cooperative signal only
- travel prompt packet and landing checklist are reachable
- no UI text implies that phone taps execute Codex, approve deploys, approve product work, or grant extra authority

## Rollback Note

If the public page shows unsafe wording, broken essential links, secret exposure, command/execution wording, third-party script loading, or confusing approval language, stop using the hosted dashboard and prepare a separate bounded rollback or repair task.

Rollback or repair work still requires its own one-task packet with `readFirst`, `allowedFiles`, `validationCommands`, `stopIf`, and report format. This packet does not approve rollback, staging, commit, push, deploy, product work, remote access configuration, all-fleet execution, overnight runner execution, installs, migrations, secrets, lock deletion, permission widening, phone approval, runtime command binding, or future authority.

## GREEN / YELLOW / RED

GREEN means the separately approved publish completed, the hosted static dashboard loads, all essential links work, no secrets or external scripts appear, and phone actions remain request-only.

YELLOW means the local checks passed but the hosted page needs manual phone verification, has stale public status, or has minor non-security UX polish.

RED means any stop sign appears: secrets, credentials, command execution, GitHub Actions triggers, product-repo exposure, public dashboard approval language, unsafe remote access instructions, all-fleet execution, overnight runner execution, deploy authority, staging/commit/push authority from this packet alone, installs, migrations, lock deletion, permission widening, or phone approval.
