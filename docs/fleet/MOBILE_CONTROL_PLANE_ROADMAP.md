# Mobile Control Plane Roadmap

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Phase 0: Public Static HQ

Keep the GitHub Pages dashboard public, static, read-only, and request-only. It can link to public-safe status, public-safe docs, quick mission request files, emergency stop request files, and travel prompt packets.

## Phase 1: Polished Static Request Dashboard

Improve mobile layout, request-only wording, local assets, safe fallbacks, security model docs, and tests. Do not add authentication, backend services, command execution, GitHub Actions triggers, product-repo access, client-side secrets, or phone approval authority.

Phase 1 may include generated public-safe project status snapshots from local evidence. Those snapshots can show safe project names, GREEN/YELLOW/RED/UNKNOWN status, branch, clean/dirty state, checkpoint/build evidence, pending task count, and next recommended action. They must omit local absolute paths, secrets, credentials, tokens, private device identifiers, product/customer data, and any execution authority.

Snapshot status can be stale until regenerated and separately published. Stale status does not approve Codex execution or product-repo work.

## Phase 1.5: One-Project Proof-Run Workflow

Make the successful PrivateLens proof path repeatable as a local Fleet workflow before authenticated control-plane work begins.

Phase 1.5 requires exactly one registered project, exactly one selected task, launch gate before Codex, Codex CLI/service_tier compatibility preflight, known repo clean/dirty state, task queue presence, build/validation command presence, checkpoint review after Codex edits, and human review before merge, push, deploy, or any second task.

The workflow remains local and evidence-only until a separate exact task packet approves an actual project run. Phone/dashboard controls remain request-only and cannot execute Codex, approve product work, merge, push, deploy, run all-fleet, run overnight, or grant broader authority.

## Phase 2: Authenticated Request Intake

Add a separate authenticated service for private project views and request submission. Requests become structured records with requester, project, task summary, quality mode, files requested, forbidden operations, validation requested, approval requirements, status, and audit notes.

Phase 2 cannot start from roadmap language alone. Before implementation, HQ must issue a separate one-task packet that defines authentication design, secret storage boundary, request integrity, policy gate, allowedFiles, validationCommands, stopIf, model routing / cost-quality recommendation, runner refusal behavior, audit logs, and human approval rules.

Until that packet exists and passes validation, Phase 2 remains YELLOW: designed, not approved for backend/auth/execution work.

## Phase 3: Policy Gate And Model Router

Classify each request before execution. Require one-task boundary, allowedFiles, validationCommands, stopIf, model routing / cost-quality recommendation, and explicit approval requirements.

Phase 3 model routing starts as an alias-only policy specification. Use `fast_readonly`, `standard_patch`, `deep_reasoning`, and `premium_audit` as advisory aliases for `best_value` and `perfection` quality modes. Do not hardcode current model names, claim current pricing, call model APIs, or wire routing into live execution until a separate implementation packet approves and validates a runner-side policy gate.

A local preflight helper may read a single task packet and produce a public-safe
recommendation report, but it remains read-only and advisory. Helper output
does not execute Codex, mutate task packets, change Codex config, approve
product-repo access, or bypass one-task `allowedFiles`, `validationCommands`,
and `stopIf` contracts.

## Phase 4: Controlled Runner Integration

Connect policy-approved requests to a local or controlled runner that refuses missing contracts, forbidden operations, product repo access by default, all-fleet commands, overnight runners, deploys, staging, commits, pushes, installs, migrations, lock deletion, permission widening, runtime command binding, and secret handling.

Runner integration requires its own later exact implementation packet. This roadmap does not approve a runner, GitHub Actions trigger, shell command path, Codex execution path, product-repo path, or unattended automation.

## Phase 5: Audited Project Control

Allow carefully scoped project work only after authentication, request records, policy gates, runner gates, validation, and audit logs are proven. Product repo access remains separately approved per project and task.

## Non-Goals

- no public command buttons
- no client-side secrets
- no broad repo access
- no phone approval as execution authority
- no all-fleet from mobile
- no overnight runner from mobile
- no deploys from public dashboard
- no GitHub Actions triggers from public dashboard
- no product/customer data on public pages
- no authentication or backend implementation in this architecture task
- no backend/auth/execution/GitHub Actions implementation approved by architecture docs alone
- no runner integration until runner refusal behavior and audit logs are separately validated
