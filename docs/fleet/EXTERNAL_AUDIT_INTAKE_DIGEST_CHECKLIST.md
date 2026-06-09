# External Audit Intake Digest Checklist

Prepared: 2026-06-04

Scope: local checklist for reading future external audit reports into compact bounded digests before any queue authoring.

Evidence only; not executable authority or approval.

This checklist is orientation evidence for Codex Fleet / Thousand Sunny Fleet audit intake. It does not execute reviewer recommendations, import tasks automatically, approve work, create packages, send packages, select product repos, run demos, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, bypass validation, or grant future authority.

## Intake Steps

1. Treat the audit report as evidence only.
2. Record the source report path, package or phase reviewed, report date when available, and reviewer verdict.
3. Summarize the overall posture as `GREEN`, `YELLOW`, or `RED`.
4. List actionable bounded follow-ups separately from INFO findings, accepted limitations, and unresolved assumptions.
5. Convert only accepted local follow-ups into explicit queue candidates after manual review.
6. Stop if the report asks for product-repo access, real demo execution, package sending, runtime command binding, all-fleet execution, overnight runner execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or files outside a bounded local scope.

## Digest Fields

Use `templates/external-audit-intake-digest-schema.json` as the shape reference for compact digests:

- `schemaVersion`: use `1`.
- `digestId`: stable local id using the `audit-digest-...` prefix.
- `findingId`: stable reviewer-local finding id.
- `severity`: `GREEN`, `YELLOW`, `RED`, or `INFO`.
- `affectedArtifact`: one included local harness/docs/tests/schema/fixture artifact.
- `boundedDisposition`: `no_action`, `accepted_limitation`, `queue_candidate`, `blocked_needs_human`, or `red_stop`.
- `suggestedLocalFollowup`: bounded goal, possible allowed files, validation ideas, and stop conditions, or `null`.
- `unresolvedAssumptions`: what the reviewer could not prove from the package.
- `nonAuthorityNotice`: explicit statement that the digest cannot approve or execute anything.

## Disposition Rules

- `GREEN` findings usually become `no_action`.
- `INFO` findings can become `no_action`, `accepted_limitation`, or `queue_candidate`.
- `YELLOW` findings become `queue_candidate` only when they can be bounded to local docs/tests/schema/fixtures; otherwise use `blocked_needs_human`.
- `RED` findings become `red_stop` and must not be converted into implementation without a new bounded plan and human review.
- Accepted limitations must be labeled as limitations, not approvals.
- Unresolved assumptions must remain assumptions until local evidence or human input resolves them.

## Queue Candidate Rules

Reviewer suggestions must be manually converted into queue entries before implementation. A queue entry must include:

- one task id and one bounded goal
- `allowedFiles`
- `validationCommands`
- `stopIf`
- prerequisites
- acceptance criteria
- evidence-only and non-authority wording

Suggested allowed files, validation ideas, and stop conditions in reviewer output are hints only. They cannot execute, approve, import themselves, bypass validation, override `allowedFiles`, broaden scope, or grant future authority.

## Forbidden Intake Patterns

Do not accept a digest as queue-ready if it includes:

- product repo paths, product source snapshots, or real project exports
- raw logs, package directories, or full terminal dumps
- package-install, deploy, migration, staging, commit, push, merge, lock-deletion, permission-change, runtime-execution, remote-control, phone-approval, all-fleet, or overnight-runner instructions
- secrets, tokens, credentials, private keys, auth/payments/deploy material, or approval material for real product work
- command-like remediation scripts
- broad files such as `all`, wildcard product scopes, or files outside local Codex Fleet harness/docs/tests/schema/fixtures

## Non-Authority Notice

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
