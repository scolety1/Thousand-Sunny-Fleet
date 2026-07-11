# Read This First — Durable Mission, Result, and Admission Contract V1

This packet adopts the durable operating boundary:

`TSF mission envelope -> native Chat, Work, or Codex execution -> TSF result envelope -> postflight validation -> admission decision`

The implementation is local, deterministic, foreground-only, and surface-neutral. It does not launch ChatGPT or Codex, call an API, build HQ Dispatch, install a plugin, expose MCP, start background work, or grant merge/production authority.

Included: policy fingerprinting, canonical schemas, mission/result validation, deterministic admission receipts, stable model aliases, three synthetic flows, and assertion-derived coverage.

The dedicated suite writes scratch evidence under `.codex-local` by default. Release evidence is refreshed only when an explicit `-EvidenceRoot` points to this packet.

Read `EXISTING_COMPONENT_REUSE_MAP.md` before proposing another format.
