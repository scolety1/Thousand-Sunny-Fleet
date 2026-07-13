# Known Limitations and Explicit Milestone 2 Deferrals

## Known Milestone 1 limitations

- The production listener is intentionally fixed to IPv4 loopback `127.0.0.1` and port `4317`. There is no host, port, CLI, environment, or config-file override.
- The wrapper uses the existing Windows PowerShell runtime at a fixed system path. Cross-platform hosting is not part of this milestone.
- The proposed project and lane are fixed to `thousand-sunny-fleet` and `MASTER_TSF_CONTROL_PLANE`.
- The proposed role is the existing default of `New-TsfProjectMainBotMissionDraft.ps1`: `researcher_source_tracer_worker`. Adaptive role selection is not invented here.
- The model request uses the existing legacy alias `standard_patch`, which the canonical resolver projects to stable `BALANCED`, current CODEX resolution, and current effort. Adaptive model selection is not invented here.
- Preview artifacts accumulate beneath the ignored preview directory. The server provides no cleanup control, history view, or record-management endpoint.
- Skill and setup/action registries are versioned static projections. A source edit produces a visible hash mismatch; automatic regeneration is not performed.
- Plugin registries and runtime state are entirely out of scope. The UI displays only a fixed disabled capability posture and reads no plugin source.
- The browser shell displays the current preview response only. It has no durable result history.
- Loopback binding is the network boundary for this milestone. Authentication is intentionally absent because no remote listener or operational authority is provided.

## Explicit Milestone 2 or later deferrals

The following are not implemented, exposed, invoked, simulated as authority, or approved by Milestone 1:

- mission submission or canonical queue record creation;
- Codex invocation, Codex CLI invocation, or Codex app-server startup;
- worker launch, worker handoff, parallel execution, or background execution;
- lifecycle, admission, producer, verifier, preservation, or recovery invocation;
- approval relay, approval capture, approval-ledger mutation, approval authentication, or approve controls;
- result ingestion, result display, mission history, retry, resume, or recovery UI;
- startup automation, scheduled startup, service installation, daemonization, or watchdog behavior;
- authentication, credentials, secrets, identity, remote listener, remote console, or external API connection;
- plugin installation, enablement, connection, loading, capability observation, host-state inspection, or plugin resolution;
- Project Main Bot runtime routing changes or an alternate role/model authority;
- product-repository inspection or mutation;
- package installation, dependency changes, migrations, deploy, publish, stage, push, merge, or pull-request operations;
- demo execution or any command-capable demo surface;
- mobile, notification, authenticated remote, Work, Teams, Slack, email, calendar, or other connector integration.

Any later milestone must create a separately reviewed authority bridge rather than extending the preview endpoint or treating its artifacts, UI text, registry entries, classifications, approvals, or passing tests as execution authority.
