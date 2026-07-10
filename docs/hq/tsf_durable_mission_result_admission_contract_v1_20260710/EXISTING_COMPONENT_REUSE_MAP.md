# Existing Component Reuse Map

This inventory was completed before implementation. The durable contract layer extends the current TSF control plane; it does not introduce a second queue, approval ledger, worker registry, research importer, or context system.

| Existing component | Reuse decision | Durable-contract use |
|---|---|---|
| `tools/codex-fleet-enforcement-kernel.ps1` | Reuse | Canonical JSON IO, path canonicalization/containment, existing preflight and approval semantics. |
| Minimum viable mission packet schema | Extend, do not replace operationally | Existing packets remain valid for the current lifecycle; the durable envelope becomes the cross-surface admission boundary. |
| `role-aware-mission-extension.v1.json` | Reuse | Worker role, Project Main Bot, verifier, lane, and escalation linkage inform envelope fields. |
| Worker role registry and permission profiles | Reuse | Canonical role and permission policy files participate in the policy fingerprint. |
| Mission queue state policy | Reuse | Existing lifecycle remains the mission state machine; admission receipts are postflight evidence. |
| Approval ledger and kernel approval matcher | Reuse | Mission envelopes reference approval IDs and exact actions; returned prose never creates approval. |
| Lifecycle runner and queue foreground executor | Reuse later through adapter | No launcher changes in this lane. Result admission can wrap preservation output in a future bounded adapter. |
| Kernel preservation packet | Reuse pattern | Result envelopes and admission receipts use hashes, explicit next action, and machine-readable preservation. |
| Project context capsule | Reuse | Capsules remain compressed recovery context; durable envelopes remain authoritative mission/result records. |
| HQ choke-point adapter | Reuse boundary | Local packet preparation only; no API transport or authority expansion. |
| PR #11 research import/synthesis | Reuse pattern | Hash-preserved advisory reports, eligibility screening, provenance, and `grants_approval: false`. |
| Model-routing preflight | Extend by policy | Stable aliases live in one replaceable policy file; current model names are not embedded in schemas. |
| Existing PowerShell tests | Reuse style | Every reported PASS records expected and observed values from an executed assertion. |

The role-aware lifecycle test now binds its scratch copy of the Builder fixture to the active worktree instead of executing against a hard-coded checkout path. This preserves its intended semantics and makes required isolated-worktree validation truthful.

No new approval ledger, mission queue, launcher, transcript store, research format, HQ Dispatch UI, plugin, or MCP server is created.
