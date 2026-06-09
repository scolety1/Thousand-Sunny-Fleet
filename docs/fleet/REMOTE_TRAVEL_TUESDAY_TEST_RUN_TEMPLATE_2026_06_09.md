# Remote Travel Tuesday Test Run Template

Prepared: 2026-06-06

Target test day: Tuesday, 2026-06-09

Evidence only; not executable authority or approval.

## Purpose

Use this template to record the Tuesday off-network rehearsal from a phone hotspot or other non-home network. It is a non-secret worksheet for proving the travel workflow before departure.

Tuesday is the full test-run day. Filling this out does not approve remote command execution, product-repo access, all-fleet execution, overnight runner execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

## No-Secret Evidence Rule

Do not paste or store PINs, passwords, MFA codes, recovery codes, Tailscale keys, SSH keys, tokens, Chrome Remote Desktop secrets, Windows credentials, account recovery answers, private device identifiers, screenshots that show secrets, or clipboard contents with secrets in this file, docs, chat, reports, or generated evidence.

If screenshot evidence is useful, capture only non-secret status surfaces. Do not include account recovery prompts, password manager views, MFA prompts, PIN screens, tokens, private IP details that are not needed, or customer/product data.

## Status Labels

Use only these labels:

- `pass`
- `blocked`
- `needs retest`
- `not checked`

## Before Starting

- Confirm this is the actual Tuesday, 2026-06-09 off-network rehearsal, not a Codex tabletop task.
- Confirm the home PC is expected to be powered on and reachable.
- Confirm the travel laptop has the needed browser, password manager, and MFA device available.
- Confirm you are ready to use Chrome Remote Desktop as the primary desktop-control path.
- Confirm Tailscale is support/visibility only and not the primary desktop-control path.
- Confirm no product repo, product data, customer data, or real ship work is part of this rehearsal.
- Confirm no PINs, passwords, MFA material, recovery codes, keys, tokens, private screenshots, private device identifiers, or customer/product data will be recorded.

## Tuesday Step Order

Use this order during the manual off-network rehearsal.

1. Non-home network setup: connect the travel laptop to a phone hotspot or other non-home network.
2. Reboot recovery: reboot the home PC manually or use a previously planned safe manual reboot path, then wait for it to return online.
3. Chrome Remote Desktop primary path: confirm Chrome Remote Desktop sees the home PC online and connect from the travel laptop.
4. Tailscale support/visibility path: confirm Tailscale shows the home PC and travel laptop online for support/visibility only.
5. Windows unlock: unlock the intended Windows account through Chrome Remote Desktop without recording credentials.
6. Codex Desktop open: open Codex Desktop and confirm it is usable in the remote session.
7. Terminal in `C:\Dev\codex-fleet`: open a terminal and change only to the local Codex Fleet repo path.
8. Safe token projection command: run the safe local token projection command below from `C:\Dev\codex-fleet`.
9. Disconnect/reconnect: disconnect Chrome Remote Desktop, reconnect once, and confirm Codex Desktop is still usable.
10. Evidence collection: fill only non-secret statuses and short notes in the rehearsal record.
11. Final GREEN/YELLOW/RED classification: classify the travel posture using the outcome rules below.

## What To Do If Blocked

If any step is blocked, use `docs/fleet/REMOTE_TRAVEL_CHROME_REMOTE_DESKTOP_TRIAGE.md` as the next manual triage card. Do not invent unsafe workarounds.

Blocked means stop or mark `blocked` / `needs retest` if the next step would require public RDP, router port forwarding, weakened security, secret sharing, phone approval, runtime command binding, all-fleet execution, overnight runner execution, product-repo work, staging, commit, push, deploy, migrations, lock deletion, or permission widening.

If the power, sleep, reboot, or Windows Update posture is unclear, use `docs/fleet/REMOTE_TRAVEL_POWER_UPDATE_SAFETY.md` for manual review only. Codex must not change power, update, OS, router, firewall, RDP, Tailscale, or Chrome Remote Desktop settings.

## Rehearsal Record

| Area | Check | Status | Non-secret note |
| --- | --- | --- | --- |
| Network | Travel laptop is on phone hotspot or another non-home network | not checked | Do not record phone account details. |
| Reboot recovery | Home PC was rebooted before the off-network connection attempt | not checked | Record only whether it came back online. |
| Chrome Remote Desktop | Chrome Remote Desktop sees the home PC online | not checked | Primary desktop-control path. Do not record PIN. |
| Chrome Remote Desktop | Chrome Remote Desktop connects from the off-network laptop | not checked | Do not capture PIN/password screens. |
| Tailscale | Tailscale shows the home PC online for support/visibility | not checked | Support/visibility only, not primary desktop control. |
| Tailscale | Tailscale shows the travel laptop online in the same tailnet | not checked | Do not record auth keys or secrets. |
| Windows | Intended Windows account can unlock the home PC through Chrome Remote Desktop | not checked | Do not record Windows credentials. |
| Codex Desktop | Codex Desktop opens and is usable in the remote session | not checked | Manual use only. |
| Terminal | Terminal opens in `C:\Dev\codex-fleet` | not checked | Do not touch product repos. |
| Safe command | Token projection travel check ran successfully | not checked | Use the command below only if already inside the safe local repo. |
| Reconnect | Chrome Remote Desktop disconnect and reconnect worked | not checked | Confirms session recovery. |
| Evidence | Non-secret evidence was collected for each step | not checked | Do not include private screenshots or private device identifiers. |
| Final classification | GREEN/YELLOW/RED classification was recorded | not checked | GREEN requires the Tuesday off-network test to actually pass. |
| Safety | No public RDP exposure, router port forwarding, phone approval, runtime command binding, all-fleet command, or overnight runner was used | not checked |  |
| Safety | No secrets, screenshots with secrets, credentials, PINs, MFA material, keys, or tokens were stored in repo docs or chat | not checked |  |

## Safe Local Command

Run this only from `C:\Dev\codex-fleet` during the manual Tuesday rehearsal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\codex-fleet-token-projection.ps1 -PromptText "Travel readiness check" -ReadFiles docs\fleet\REMOTE_TRAVEL_READINESS_2026_06_10.md -ExpectedPatchTokens 0
```

This command is local evidence only. It does not call model APIs, configure remote access, approve product work, or prove billing/model availability.

## Tuesday Outcome

GREEN when:

- Chrome Remote Desktop primary access works from a non-home network after reboot.
- Tailscale support/visibility shows both devices online from the non-home network.
- Codex Desktop and terminal are usable remotely.
- The safe local token projection command runs in `C:\Dev\codex-fleet`.
- Disconnect and reconnect works.
- No public RDP exposure, router port forwarding, secrets-in-docs, phone approval, runtime command binding, all-fleet command, overnight runner, product-repo access, staging, commit, push, deploy, install, migration, lock deletion, or permission widening occurred.

YELLOW when:

- Chrome Remote Desktop works but Tailscale support/visibility is unproven.
- Tailscale support/visibility works but Chrome Remote Desktop is flaky.
- Reboot recovery, reconnect, Codex Desktop, terminal, or the safe local command needs retest.
- Evidence is incomplete but no RED stop sign occurred.

RED when:

- Chrome Remote Desktop cannot reach the home PC from a non-home network.
- Reboot recovery fails or the PC becomes unreachable.
- Public RDP exposure, router port forwarding, weakened security, phone approval, runtime command binding, all-fleet execution, overnight runner execution, product-repo access, or secret storage was required.
- Remote session instability creates a risk of partial or unintended commands.

## Stop Signs

Stop and do not continue the rehearsal if it would require:

- configuring remote access inside this Codex task
- installing software inside this Codex task
- exposing ports or using public RDP as a fallback
- storing or pasting secrets
- capturing screenshots with secrets
- approving phone actions
- binding runtime commands
- touching product repos
- running all-fleet commands
- running an overnight runner
- staging, commit, push, deploy, install, migration, lock deletion, or permission widening

## Wednesday Use

Use this filled template as evidence for the Wednesday, 2026-06-10 go/no-go decision. It is evidence only and does not grant future authority.
