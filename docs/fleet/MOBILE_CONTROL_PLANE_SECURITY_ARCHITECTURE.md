# Mobile Control Plane Security Architecture

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Purpose

This document designs the future secure mobile Fleet app. It does not implement authentication, a backend, command execution, GitHub Actions triggers, runner integration, product-repo access, or deployment.

The current GitHub Pages Phone HQ remains a public static dashboard. It can show public-safe status and request links only. The future authenticated control plane must be separate.

## Architecture Boundary

Safe future shape:

1. authenticated user
2. request object
3. policy classification
4. model routing / cost-quality recommendation
5. allowedFiles
6. validationCommands
7. stopIf
8. human/HQ approval where required
9. runner-side execution gate
10. audit log

Unsafe shape:

- public button to shell command
- public button to Codex command
- public button to GitHub Actions workflow
- phone approval as execution authority
- browser-held GitHub personal access token
- browser-held Codex token
- broad product-repo access from mobile

## Implementation Cutline

This architecture is not approval to begin authenticated request intake, backend services, GitHub Actions wiring, command execution, runner integration, product-repo access, staging, commit, push, deploy, installs, migrations, lock deletion, permission widening, or secret handling.

Before moving from the public static HQ to authenticated request intake, a separate one-task implementation packet must define and pass these preconditions:

- authentication design
- secret storage boundary
- request integrity and replay resistance
- policy gate
- one-task boundary
- allowedFiles
- validationCommands
- stopIf
- model routing / cost-quality recommendation
- runner refusal behavior
- audit logs
- human approval rules

If any precondition is missing, ambiguous, or untested, implementation remains YELLOW and must stop for HQ repacketization. Passing documentation tests for this architecture does not approve backend/auth/execution/GitHub Actions implementation.

## Browser Rules

The browser must never store GitHub PATs, Codex tokens, SSH keys, deploy keys, MFA codes, passwords, repo secrets, runner credentials, or project secrets.

The browser must never directly execute shell commands, Codex commands, deployment commands, GitHub Actions workflows, migrations, package installs, all-fleet commands, overnight runners, or product-repo mutations.

Mobile actions create signed or otherwise recorded requests. They are not execution authority.

## Control Plane Components

Public static dashboard:

- public-safe status only
- public-safe request links only
- no secrets
- no command execution
- no private project data

Authenticated request intake:

- real authentication before private project views or request submission
- separate approval packet before implementation
- no browser-held secrets or client-side GitHub tokens
- request schema validation
- request IDs and timestamps
- replay-resistant request handling
- clear status: requested, triaged, blocked, approved-for-runner, running, validation-failed, complete

Policy gate:

- classifies risk before execution
- requires one-task boundary
- requires allowedFiles
- requires validationCommands
- requires stopIf
- fails closed on missing scope
- separates product repo access by project and task

Model router:

- recommends best_value or perfection based on risk, cost, and quality needs
- records requested model tier and selected model tier
- does not weaken validation or safety boundaries

Controlled runner:

- receives only policy-approved request objects
- refuses missing allowedFiles, validationCommands, or stopIf
- refuses implementation packets that lack request integrity, model routing / cost-quality recommendation, audit logs, or human approval rules
- refuses product repos unless separately scoped and approved
- refuses public dashboard commands
- writes an audit log for every decision and run

## Product Repo Boundary

Product repo access is denied by default. Any product repo access must be separately scoped, explicitly approved per project and task, and limited to the selected task contract.

The mobile app must not grant broad repo access, all-fleet authority, deployment authority, migration authority, secret handling authority, lock deletion authority, permission widening authority, staging authority, commit authority, or push authority by default.

## Emergency Stop

Emergency stop is high-priority and safe. It may create a stop request, raise visibility, or ask a controlled runner to pause through a narrow audited stop path.

Emergency stop must never become arbitrary command execution, secret handling, product-repo mutation, deploy authority, all-fleet authority, or phone approval authority.

Emergency stop requests must carry only non-secret fields and must be repacketized before any runner-side behavior. They do not approve process killing, remote access configuration, runtime command binding, staging, commit, push, install, migration, lock deletion, permission widening, or broader authority.

## GREEN / YELLOW / RED

GREEN means request intake, policy gate, runner gate, and audit log all enforce one-task boundaries and least privilege.

YELLOW means private execution remains disabled or manual because authentication, policy, model routing, runner gates, or audit logs are incomplete.

RED means any browser path can execute commands, store secrets, approve phone actions, mutate product repos by default, trigger all-fleet or overnight runners, deploy, stage, commit, push, run migrations, delete locks, or widen permissions.
