# Remote Travel Power And Update Safety Card

Prepared: 2026-06-06

Evidence only; not executable authority or approval.

## Purpose

Use this card to review whether the home PC is likely to stay reachable during the trip. It is a manual safety checklist and does not change OS settings.

This card is manual-review only. Codex must not change power settings, Windows Update settings, OS settings, router/firewall settings, RDP settings, Tailscale settings, or Chrome Remote Desktop settings from this card.

This card does not configure remote access, install software, expose ports, store credentials, weaken security, approve phone actions, bind runtime commands, touch product repos, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, delete locks, widen permissions, or grant future authority.

## Manual Review Areas

| Area | What to verify manually | Safe note |
| --- | --- | --- |
| Sleep | The home PC will not sleep in a way that makes Chrome Remote Desktop unreachable during the trip. | Record only `checked`, `needs change`, or `not checked`; do not change settings from this Codex task. |
| Reboot recovery | After a reboot, the PC returns online and Chrome Remote Desktop becomes available again. | Tuesday off-network rehearsal should prove this. |
| Windows Update timing | Updates are completed or safely paused before departure, with no surprise reboot expected during travel work. | Do not disable security protections or use registry hacks. |
| Power loss | The PC power cable, outlet, and any power strip are stable enough for a week away. | Record only non-secret physical setup notes. |
| Monitor/lock expectations | The remote session can reach the locked PC and the monitor state does not block normal remote control. | Do not record Windows credentials. |
| Chrome Remote Desktop | Primary desktop-control path still appears online from the travel laptop. | Do not record PINs. |
| Tailscale | Support/visibility path still shows both devices online. | Do not record auth keys or private secrets. |
| Codex | Codex Desktop opens after reboot and a terminal can reach `C:\Dev\codex-fleet`. | Do not touch product repos. |

## Before Departure

GREEN before Wednesday, 2026-06-10 when:

- Sleep posture is known.
- Reboot recovery has been tested.
- Windows Update timing is known and not expected to interrupt travel work.
- Power loss risk has been reviewed.
- Monitor and lock expectations are known.
- Chrome Remote Desktop primary access works.
- Tailscale support/visibility works.
- Codex Desktop and `C:\Dev\codex-fleet` are reachable after reboot.
- No registry hacks, permission widening, public RDP exposure, router port forwarding, secret storage, phone approval, runtime command binding, all-fleet execution, overnight runner execution, product-repo access, staging, commit, push, deploy, install, migration, lock deletion, or weakened security was required.

YELLOW when:

- One item needs manual review but no RED stop sign occurred.
- Reboot recovery, Windows Update timing, monitor behavior, or power posture has not been fully proven.
- Chrome Remote Desktop works but Tailscale support/visibility still needs confirmation.

RED when:

- The PC may sleep or reboot into an unreachable state.
- Windows Update timing is unknown or likely to interrupt travel work.
- Power posture is unreliable.
- Public RDP exposure, router port forwarding, registry hacks, permission widening, weakened security, secret storage, phone approval, runtime command binding, all-fleet execution, overnight runner execution, product-repo access, staging, commit, push, deploy, install, migration, or lock deletion would be required.

## Avoid

Do not use:

- registry hacks
- permission widening
- public RDP exposure
- router port forwarding
- firewall weakening
- password weakening
- secret sharing in docs or chat
- phone approvals
- runtime command binding
- all-fleet commands
- overnight runners
- product-repo access
- staging, commit, push, deploy, install, migration, lock deletion, or permission widening

## Stop Signs

Stop and mark YELLOW or RED instead of forcing the setup if keeping the PC reachable would require changing OS settings directly from Codex, configuring remote access from Codex, storing credentials, weakening security, approving phone actions, binding runtime commands, touching product repos, running all-fleet commands, running an overnight runner, staging, committing, pushing, deploying, installing packages, running migrations, deleting locks, widening permissions, or using files outside the selected task's allowedFiles.
