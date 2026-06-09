# Remote Travel Saturday Setup Checklist

Prepared: 2026-06-06

Evidence only; not executable authority or approval.

## Purpose

This checklist records Saturday install/inventory status for the Windows 11 Home 25H2 travel setup. It is for non-secret evidence only.

Saturday is install and inventory only. A completed Saturday checklist does not prove travel readiness. Tuesday, 2026-06-09 remains the full off-network test-run day.

## Status Labels

Use only these labels:

- `done`
- `blocked`
- `needs Tuesday test`
- `not checked`

Do not record PINs, passwords, MFA codes, recovery codes, Tailscale keys, SSH keys, tokens, Chrome Remote Desktop secrets, Windows credentials, account recovery answers, or private device identifiers in this file.

## Saturday Checklist

| Area | Item | Status | Non-secret note |
| --- | --- | --- | --- |
| Chrome Remote Desktop | Chrome Remote Desktop installed or available on home PC | not checked |  |
| Chrome Remote Desktop | Remote access configured for home PC | not checked | Do not record PIN. |
| Chrome Remote Desktop | Home PC named with a recognizable non-secret name | not checked | Example: `Home-Codex-PC`; do not include account secrets. |
| Chrome Remote Desktop | Home PC appears from travel laptop | not checked |  |
| Chrome Remote Desktop | Initial same-network connection attempted | not checked | Full off-network proof waits until Tuesday. |
| Tailscale | Tailscale installed or available on home PC | not checked |  |
| Tailscale | Tailscale installed or available on travel laptop | not checked |  |
| Tailscale | Both devices appear in same tailnet | not checked | Do not record auth keys. |
| Tailscale | Tailscale used only as support/visibility for this Windows 11 Home plan | not checked | Not primary desktop control. |
| Repo | `C:\Dev\codex-fleet` exists on home PC | not checked |  |
| Codex | Codex Desktop opens on home PC | not checked |  |
| Power | Sleep/update posture noted for later Monday review | not checked | Do not change settings in this checklist. |
| Safety | No public RDP exposure or router port forwarding configured | not checked |  |
| Safety | No secrets, PINs, passwords, MFA material, or keys stored in repo docs | not checked |  |
| Safety | No phone approvals, runtime command binding, all-fleet execution, or overnight runner use | not checked |  |

## Saturday Pass Condition

Saturday is GREEN only when:

- Chrome Remote Desktop shows the home PC from the travel laptop.
- Tailscale shows both devices in the same tailnet.
- `C:\Dev\codex-fleet` exists on the home PC.
- No Microsoft RDP/public remote desktop dependency was introduced.
- No secrets were stored in repo docs or chat.
- No Codex execution authority changed.

Saturday is YELLOW when:

- Chrome Remote Desktop or Tailscale is partly installed but not visible from the laptop.
- Codex Desktop or the repo path was not checked.
- Power/update posture still needs Monday review.

Saturday is RED when:

- Public RDP exposure or router port forwarding was configured.
- A PIN, password, MFA code, recovery code, key, token, or credential was stored in repo docs or chat.
- Remote access setup required weakening security.

## Stop Signs

Stop and ask for a safer plan if Saturday work would require:

- public RDP exposure or router port forwarding
- storing or pasting secrets
- weakening Windows account security
- approving phone actions
- binding runtime commands
- touching product repos
- running all-fleet commands
- running an overnight runner
- staging, commit, push, deploy, install, migration, lock deletion, or permission widening

## Next Day

If Saturday is GREEN or YELLOW without a RED stop sign, the next planned day is Sunday, 2026-06-07: primary Chrome Remote Desktop path setup on a normal local/private connection.
