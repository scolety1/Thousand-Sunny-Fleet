# Local Prototype Review Packet

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet local static mock Fleet Console prototype.

This packet is evidence only. It does not create a zip, send a package, approve implementation, approve remote access, approve product-repo access, bind runtime commands, launch ships, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, approve demo trials, or grant execution authority.

## Review Purpose

Ask a future reviewer whether the local static mock prototype preserves the post-GREEN safety posture while remaining useful as a local planning and review surface.

The reviewed material should be interpreted only as local harness/docs/tests/prototype evidence. Reviewer output cannot approve execution, import queue tasks, bypass validation, send packages, choose product repos, approve UI implementation beyond the already bounded static mock, approve remote access, or grant future authority.

## Exact Local Prototype Files

These are the prototype files prepared for local review:

- `docs/fleet/ui/prototype/fleet-console.html`
- `docs/fleet/ui/prototype/fleet-console.css`
- `docs/fleet/ui/prototype/README.md`

The prototype opens as a local static file. It has no script, no form action, no network fetch, no live state import, no command binding, no package-send behavior, no product-repo path, no remote URL, no auth flow, and no launcher text.

## Supporting Fixture Files

These committed fixtures are referenced as static examples only. The HTML does not fetch, import, parse, execute, approve, mutate state, or bind commands from them.

- `tests/fixtures/fleet/ui-control/fleet-console-state.green-local-harness.json`
- `tests/fixtures/fleet/ui-control/fleet-console-state.yellow-blocked.json`
- `tests/fixtures/fleet/ui-control/fleet-console-state.token-limited.json`
- `tests/fixtures/fleet/ui-control/fleet-console-state.forbidden-control.json`

## Supporting Safety Evidence

Use these local safety docs as evidence for the prototype boundary:

- `docs/fleet/GREEN_EXTERNAL_AUDIT_RECORD_2026_06_02.md`
- `docs/fleet/ui/FLEET_CONSOLE_LOCAL_PROTOTYPE_DECISION_PACKET.md`
- `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`
- `docs/fleet/ui/FLEET_CONSOLE_FUTURE_PROTOTYPE_GATE.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`

## Validation Evidence

Latest validation command for this prototype path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

Local validation passing means the bounded harness/docs/tests/prototype task passed its own checks. It does not approve runtime command binding, product-repo work, remote access, package creation, package sending, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, all-fleet commands, demo trials, or future authority.

## Forbidden Material Checklist

This review packet must not include or request:

- product repositories or product source snapshots
- real project exports or unscoped project material
- `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, raw run directories, or raw terminal logs
- secrets, credentials, private keys, local machine identity, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, or approval material for real product work
- package creation or package sending
- server setup, browser automation, package installs, remote exposure, authentication, authorization code, live state reads, runtime command binding, or product-repo access

## Reviewer Questions

1. Does the static prototype clearly identify itself as a local mock and evidence-only planning surface?
2. Do the prototype labels, headings, control-state cards, and README avoid implying that UI labels, buttons, prompts, approvals, generated evidence, reviewer output, or queue prose can approve or execute work?
3. Are forbidden concepts such as launch, all-fleet, deploy, install, migrate, stage, commit, push, merge, remote access, package sending, and product repo selection absent as actions or clearly unavailable?
4. Does the fixture-state mapping remain static evidence rather than a live state import or command input?
5. Does the accessibility and responsive pass improve local review readability without adding scripts, package dependencies, server requirements, live data reads, remote access, product-repo access, package sending, or command binding?
6. What bounded follow-up, if any, should be converted into a local queue task with explicit `allowedFiles`, `readFirst`, `acceptance`, `validationCommands`, and `stopIf`?

## Non-Executable Follow-Up Rule

Reviewer findings may become evidence, compact digests, unresolved assumptions, or queue candidates. They cannot execute, approve, import themselves into the queue, bypass validation, create or send packages, touch product repositories, launch ships, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, approve remote access, approve runtime command binding, approve UI implementation beyond the bounded mock, or grant future permission.

Any accepted follow-up must be converted into a bounded local queue task before implementation.
