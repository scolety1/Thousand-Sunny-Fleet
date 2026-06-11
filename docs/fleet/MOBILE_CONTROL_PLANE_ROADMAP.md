# Mobile Control Plane Roadmap

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Phase 0: Public Static HQ

Keep the GitHub Pages dashboard public, static, read-only, and request-only. It can link to public-safe status, public-safe docs, quick mission request files, emergency stop request files, and travel prompt packets.

## Phase 1: Polished Static Request Dashboard

Improve mobile layout, request-only wording, local assets, safe fallbacks, security model docs, and tests. Do not add authentication, backend services, command execution, GitHub Actions triggers, product-repo access, client-side secrets, or phone approval authority.

## Phase 2: Authenticated Request Intake

Add a separate authenticated service for private project views and request submission. Requests become structured records with requester, project, task summary, quality mode, files requested, forbidden operations, validation requested, approval requirements, status, and audit notes.

## Phase 3: Policy Gate And Model Router

Classify each request before execution. Require one-task boundary, allowedFiles, validationCommands, stopIf, model routing / cost-quality recommendation, and explicit approval requirements.

## Phase 4: Controlled Runner Integration

Connect policy-approved requests to a local or controlled runner that refuses missing contracts, forbidden operations, product repo access by default, all-fleet commands, overnight runners, deploys, staging, commits, pushes, installs, migrations, lock deletion, permission widening, runtime command binding, and secret handling.

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
