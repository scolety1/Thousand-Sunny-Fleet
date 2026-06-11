# Phone HQ Security Model

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Purpose

The hosted Thousand Sunny Fleet Phone HQ is a public static GitHub Pages dashboard. It is a cockpit for public-safe status and request links. It is not the engine room.

This public dashboard is request-only. It does not execute Codex, approve deployments, or grant authority.

## Static Public Boundary

GitHub Pages serves static files from this repository. The dashboard may display public-safe status, link to public-safe docs, and open GitHub edit screens for request files.

The dashboard must not contain or expose:

- secrets
- tokens
- PINs
- passwords
- MFA material
- recovery codes
- SSH keys
- private keys
- deploy keys
- credentials
- private device identifiers
- customer data
- product data

Loaded public status is view-only and never authority. If it appears stale, contradictory, or active-looking, the dashboard must show caution-only handling and point back to request-only rules instead of suggesting workarounds.

## Request-Only Actions

Phone edits and phone links are requests or signals only. They do not start Codex, approve work, run shell commands, trigger GitHub Actions, deploy software, commit changes, push branches, mutate product repos, run all-fleet commands, run overnight runners, bind runtime commands, or create future authority.

Emergency stop is a high-priority cooperative stop request. It must never become arbitrary command execution.

Emergency stop requests may contain only non-secret request fields. They must not request or reveal PINs, passwords, MFA material, recovery codes, keys, tokens, credentials, private screenshots, private device identifiers, customer data, or product data.

Emergency stop does not approve product-repo mutation, all-fleet execution, overnight runner execution, deploys, staging, commits, pushes, installs, migrations, lock deletion, permission widening, runtime command binding, phone approval, remote access configuration, process killing, or shell/Codex command execution.

## Browser Boundary

The browser must never store GitHub personal access tokens, Codex tokens, SSH keys, deploy keys, MFA codes, passwords, repo secrets, or runner credentials.

The browser must never directly execute shell commands, Codex commands, deploy commands, GitHub Actions workflows, product-repo tasks, or approval flows.

All scripts and styles for the static dashboard must be local files under `docs/assets`. Do not add analytics, trackers, ad scripts, external script CDNs, or external font CDNs.

The public dashboard must not load third-party scripts, third-party stylesheets, external images, iframes, trackers, analytics, ad scripts, or external font CDNs. Required Phone HQ links are navigation only and must remain static/read-only or request-only.

Dashboard JavaScript may read public-safe status only. It must not write to GitHub, trigger GitHub Actions, call a command backend, store credentials, execute shell/Codex commands, approve phone actions, or mutate product repos.

## Future Control Plane Boundary

A future mobile control plane must be separate from this public static dashboard. It must require authentication, request records, policy classification, allowed files, validation commands, stop conditions, runner-side execution gates, and audit logs before any executable task can be considered.

Remote access and phone access grant no extra authority. Product repo access must be separately scoped and explicitly approved per project and per task.

## GREEN / YELLOW / RED

GREEN means the public dashboard remains static, public-safe, request-only, free of secrets, and clear that it grants no authority.

YELLOW means wording or UX could confuse request-only actions with execution, or the status view needs a safer fallback, but no sensitive exposure is present.

RED means the dashboard exposes secrets, stores credentials, executes commands, triggers workflows, grants approval, exposes product/customer data, or implies phone actions can authorize work.
