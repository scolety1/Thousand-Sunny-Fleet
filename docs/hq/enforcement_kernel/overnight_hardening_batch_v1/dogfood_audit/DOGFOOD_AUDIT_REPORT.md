# Dogfood Audit Report

Verdict: `GREEN_DOGFOOD_AUDIT_PASSED`

The V1 kernel was run against TSF-local fixture missions and a temporary fixture repo under `.codex-local`. No product repo, canonical NWR repo, normal NWR packet, runner, API bridge, or background process was used.

## Results

- Good mission preflight returned `GREEN`.
- Malformed mission failed closed as `RED`.
- Restricted action without active approval returned `TIM_REQUIRED`.
- Sample approval ledger was recognized but did not grant real authority.
- Worker adapter produced a foreground handoff stub with `STUB_READY_CODEX_CLI_BLOCKED`.
- Post-run verifier failed closed when required artifact was missing.
- Post-run verifier returned `GREEN` after the required fixture artifact existed.
- Preservation packet writer produced a durable handoff under `dogfood_preservation_packet_sample/`.

## Restricted-Action Confirmation

No background runner, all-fleet command, product repo mutation, canonical NWR mutation, normal NWR packet read, push, merge, deploy, install, migration, secrets access, PrivateLens access, network port, credential change, app wiring, ranking/formula/source-truth promotion, recommendation behavior, or hidden sort change occurred.
