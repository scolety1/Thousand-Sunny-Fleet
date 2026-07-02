# Lane 6 Authority/Evidence Ambiguity Trigger Packet

Prepared: 2026-07-02

Draft only; Lane 6 remains parked unless triggered by real ambiguity.

## Purpose

Lane 6 exists to create an Authority Boundary Scan Checklist only when TSF has a
concrete authority/evidence ambiguity. It should not be opened for normal
strategy, routine status drift, or curiosity.

## Real Triggers

Open Lane 6 only if one of these appears:

- a doc, queue, UI label, generated status, or work order seems to claim it can
  approve push, deploy, install, migration, secrets/auth/payments, proof run,
  all-fleet command, background runner, product repo access, PrivateLens work,
  external account change, spending, or archived reactivation
- two current TSF authority docs conflict about a restricted gate
- a generated work order appears to bypass exact Tim approval
- Fleet Console text implies an executable command hook or approval control
- a stale/historical artifact is being treated as current authority
- a product repo path in TSF docs is being treated as permission to inspect or
  mutate that repo

## Not Real Triggers

Do not open Lane 6 for:

- normal YELLOW review-only artifacts
- stale files already marked historical
- a typo that does not affect authority
- routine draft generation
- ordinary lane selection
- push-readiness when exact approval is clearly missing
- product repo access where the answer is simply Tim approval required

## Stop Conditions

Stop if:

- resolving ambiguity would require product repo or PrivateLens access
- the scan would require push, deploy, install, migration, secrets, proof run,
  all-fleet command, background runner, external account action, or archived
  reactivation
- the issue can be handled by the existing artifact index or safe stop matrix

## Tim Approval Requirement

Lane 6 itself is TSF-local docs/control-plane work and can be opened by Codex
only when a real ambiguity exists. Any restricted action discovered by Lane 6
still requires exact Tim approval before execution.

## Draft Work Order If Triggered

```text
Task:
Run TSF Lane 6 Authority Boundary Scan Checklist.

Goal:
Create docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md to resolve the specific authority/evidence ambiguity:
<describe ambiguity>

Allowed:
TSF-local docs/control-plane inspection and checklist creation.

Not allowed:
product repo access, PrivateLens access, push, deploy, installs, migrations, secrets/auth/payments, proof runs, all-fleet commands, background runners, external accounts, spending, archived reactivation.

Validation:
git status --short
git diff --check
authority wording scan
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1 if safe

Stop:
if the ambiguity requires a restricted action or cannot be classified from TSF-local evidence.
```
