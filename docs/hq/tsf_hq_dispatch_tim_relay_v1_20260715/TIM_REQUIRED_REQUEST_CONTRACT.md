# TIM_REQUIRED Request Contract

`fleet/control/tim-required-request.schema.v1.json` is closed with `additionalProperties: false`. A canonical request binds mission ID and revision, run/result/request identities, repository/worktree, exact operation and paths, access, network scopes, model/surface where applicable, issue/expiry, usage/reuse, question/reason, response compatibility, and excluded authority.

The HTTP response contract accepts exactly:

- `mission_id`
- `mission_revision`
- `run_id`
- `result_id`
- `tim_required_request_id`
- `request_evidence_sha256`
- server-generated `response_id`
- `response_type`
- `operator_confirmation`
- bounded `response_payload`

Immediately before persistence, `Invoke-TsfHqDispatchTimResponse.ps1` reloads the canonical terminal result, verifies all five identities, verifies terminal `TIM_REQUIRED`, rehashes exact evidence bytes, verifies inactive original worker/app-server child, validates expiry/supersession/invalidation/answered state, checks kind/response compatibility, and compares repository, worktree, operation, exact paths, access, network, scope, expiry, usage, and excluded authority. Unknown or malformed request kinds fail closed.

The server repeats the exact binding and evidence checks at the session boundary. Caller-supplied ledger paths, queue/evidence roots, new mission IDs, envelopes, expiry, paths, access, network, model/effort, verifier/admission values, grants, commands, scripts, executables, or environment values are rejected by the closed object contract.

All state-changing HTTP calls retain Milestone 2A's current session identity, exact loopback Host/Origin, JSON-only media type, 8 KiB request ceiling, rate limit, and replay protections.
