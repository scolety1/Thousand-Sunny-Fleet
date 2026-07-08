# TSF Runtime Next Steps After Overnight V1

## Must Do Before Operator Console

- Author a small set of real TSF-local mission packets for common Master TSF workflows.
- Decide whether the kernel must require `fleet/missions/drafted` as the only mission source.
- Add a mission index or queue summary that records current state without running a daemon.
- Add approval-ledger authoring guidance for exact Tim approval records.
- Add a review-only command that prints the next safe kernel action for one mission.

## Can Wait Until After Operator Console

- Rich lane dashboards.
- Bulk mission management.
- Multi-mission batch views.
- Historical analytics.
- UI affordances for approvals.
- Rendered report timelines.

## Requires Tim Approval

- Any Codex CLI execution beyond version detection.
- Product repo read or mutation missions.
- Canonical NWR inspection or mutation.
- Normal NWR packet comparison.
- Real approval ledger entries.
- Push, remote publication, merge, deploy, install, migration, secrets, PrivateLens, proof runs, all-fleet, or background/persistent runners.

## Requires API/ChatGPT HQ

- Automated HQ choke-point review.
- Promotion of review-only evidence to source truth.
- External strategic arbitration for model/ranking/formula decisions.
- Any workflow that sends local evidence outside the machine.

## Requires Codex CLI/App-Server/MCP Decision

- Whether the foreground worker adapter should use `codex exec`, Codex desktop handoff packets, an MCP adapter, or a local app-server bridge.
- Whether worker output should be machine-ingested from files, stdout, thread metadata, or a structured connector.
- How to prevent direct bypass when Codex is launched outside the kernel path.

## Should Not Build Yet

- Persistent runner.
- Overnight daemon.
- Watchdog or scheduler.
- All-fleet launcher integration.
- Product repo autopilot.
- Operator console command buttons.
- API bridge.
- App wiring.
- Ranking, formula, recommendation, hidden sort, or source-truth promotion paths.
