# Runtime Scope Policy

This policy separates runtime safety from audit-package redaction. Audit package
exclusions keep private or noisy files out of review bundles. Runtime scope
controls decide what automation may touch.

## Allowed Roots

- The Codex Fleet harness repo may be edited only when the captain asks for
  fleet-code or Golden Gameplan work.
- Product repos are denied by default during Golden Gameplan implementation.
- Disposable fixture repos under `.codex-local/fixtures` or `out` may be created
  for tests and evidence.

## Forbidden Paths

Automation must not edit these without an explicit high-risk approval path:

- `.env`, `.env.*`, secrets, tokens, credentials, private keys
- `.git`
- lock files, safe-stop files, active PID records, or heartbeat files
- `node_modules`, `dist`, `build`, generated output folders
- files outside the selected repo root
- parent-directory traversal paths containing `..`
- absolute paths supplied by external task packets

## Sensitive Domains

The following domains require explicit approval and a stage-specific safety gate:

- auth
- payments
- deployment
- migrations
- package/dependency changes
- production data
- external API contracts

## Default Budgets

Until later stages add full budget accounting, Stage 4.5 treats these as policy
defaults:

- one selected harness repo
- no real product repos
- no automatic merge, push, deploy, or pull request
- no manual lock deletion
- one phase-sized task batch
- focused tests before broad tests
- external packets are validation input only until Stage 8+ execution rules exist

## Audit Package V2 Requirement

If the repo is dirty, the audit package must include sanitized changed-source
snapshots or diffs for reviewable harness files. A package with dirty status but
no source/diff evidence is incomplete.
