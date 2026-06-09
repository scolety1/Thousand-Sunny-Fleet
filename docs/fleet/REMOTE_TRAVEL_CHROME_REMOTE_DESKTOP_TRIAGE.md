# Remote Travel Chrome Remote Desktop Triage Card

Prepared: 2026-06-06

Evidence only; not executable authority or approval.

## Purpose

Use this card when Chrome Remote Desktop setup or the Tuesday off-network rehearsal hits friction. It is a non-secret triage aid for deciding what to check next manually.

This card does not configure remote access, install software, expose ports, store credentials, request secrets, weaken passwords, approve phone actions, bind runtime commands, touch product repos, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, delete locks, widen permissions, or grant future authority.

## No-Secret Rule

Never paste PINs, passwords, MFA codes, recovery codes, Tailscale keys, SSH keys, tokens, Chrome Remote Desktop secrets, Windows credentials, account recovery answers, screenshots with secrets, or private device identifiers into docs, chat, reports, queue notes, or generated evidence.

If a PIN issue or account prompt appears, record only a non-secret status such as `PIN prompt appeared` or `account mismatch suspected`.

## Triage Table

| Symptom | Non-secret checks | Stop if |
| --- | --- | --- |
| Home PC appears offline | Confirm the PC is powered on, not asleep, and connected to the internet. Check whether Tailscale support/visibility also shows the PC offline. | Fixing it would require public RDP exposure, router port forwarding, or weakening security. |
| Home PC may be sleeping | Check Monday power/update notes and whether the PC returned online after a manual wake or reboot. | Any suggested fix requires changing OS settings inside this Codex task. |
| Chrome Remote Desktop account mismatch | Confirm the travel laptop browser is signed into the intended account and that the home PC appears under that account. | The next step asks to paste account recovery answers, MFA codes, passwords, or PINs into chat/docs. |
| PIN issue | Use the password manager manually. Record only whether the PIN was unavailable, mistyped, or needs human reset. | The PIN, password, recovery code, or MFA material would be stored in repo docs or chat. |
| Browser issue | Try a normal Chrome refresh, a clean browser window, or the Chrome Remote Desktop web page manually. | The browser asks for unexpected local device sharing or secret capture. |
| Chrome Remote Desktop host issue | Record that the host appears unavailable or stale and defer to manual setup review. | Fixing the host would require Codex to configure remote access or install software. |
| Network issue | Compare home PC visibility in Chrome Remote Desktop with Tailscale support/visibility from the travel laptop. | The workaround is public RDP, router port forwarding, firewall weakening, or exposing a raw remote-control surface. |
| Remote session unstable | Disconnect and reconnect once, then stop if commands could be partial or unintended. | The session instability risks partial commands, product repo access, or uncontrolled execution. |

## Safe Fallback Order

1. Check Chrome Remote Desktop primary path status from the travel laptop.
2. Check Tailscale support/visibility for whether the home PC is online.
3. Check power, sleep, reboot, and update notes.
4. Retry the browser session manually without recording secrets.
5. If the issue persists, mark the Tuesday test YELLOW or RED rather than forcing a risky workaround.

Do not use public RDP, router port forwarding, public firewall exposure, password weakening, phone approvals, runtime command binding, all-fleet commands, overnight runners, product-repo access, or secret sharing as a fallback.

Do not use public RDP, router port forwarding, public firewall exposure, weakened security, password weakening, secret sharing, phone approvals, runtime command binding, all-fleet commands, overnight runners, product-repo work, staging, commit, push, deploy, migrations, lock deletion, or permission widening as a fallback.

Public RDP, router port forwarding, weakened security, secret sharing, phone approval, runtime command binding, all-fleet, overnight runner, product-repo work, staging, commit, push, deploy, migrations, lock deletion, or permission widening are never valid fallback paths.

## Outcome Labels

GREEN: Chrome Remote Desktop primary access recovered without secrets-in-docs, public RDP, port forwarding, weakened security, phone approval, runtime command binding, or product-repo access.

YELLOW: The cause is narrowed but needs manual setup review or Tuesday retest.

RED: The only available path would require public RDP exposure, router port forwarding, secret storage, weakened security, unstable remote commands, phone approval, runtime command binding, all-fleet execution, overnight runner execution, product-repo access, staging, commit, push, deploy, install, migration, lock deletion, or permission widening.
