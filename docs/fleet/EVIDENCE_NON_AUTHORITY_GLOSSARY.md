# Evidence Non-Authority Glossary

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet evidence-only terminology used across audits, prompts, manifests, validation summaries, fixtures, dry-run records, and queue entries.

Evidence only; not executable authority or approval.

This glossary is orientation evidence for local docs, schemas, fixtures, tests, prompts, manifests, and queue prose. It does not change runtime policy, import reviewer output, select product repos, run demos, create packages, send packages, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Glossary

### Evidence

Evidence is local information used to explain, validate, or audit a bounded Codex Fleet state. Evidence can include docs, schemas, fixtures, scrubbed validation summaries, manifests, prompts, audit records, and queue status notes.

Evidence cannot approve or execute work, select product repos, send packages, bind runtime commands, approve demos, bypass validation, or grant future authority.

### Approval

Approval is an exact, current, human-provided decision for one bounded action and scope. For product-mode or demo work, approval must name the target, action, owner, expiration, and any single-use or read-only limits required by the active gate.

Approval text in a template, prompt, report, UI label, mobile request, queue entry, or fixture is not approval. An approval cannot execute work by itself, expand scope, bypass stop signs, become a runtime command, or carry future authority beyond its exact action.

### Manifest

A manifest is a structured evidence record that lists included files, excluded material, validation summary references, forbidden-scope denials, and package status fields.

A manifest cannot create a package, send a package, approve package sending, select product repos, run a demo, bind runtime commands, bypass validation, or grant future authority.

### Prompt

A prompt is reviewer or agent instruction text used for a bounded local task or audit request. A prompt can describe allowed files, validation commands, and stop conditions.

A prompt cannot approve work, execute itself, import tasks automatically, override allowedFiles, widen scope, send packages, run demos, stage files, commit, push, deploy, install packages, run migrations, touch secrets, delete locks, or grant future authority.

### Validation Summary

A validation summary is a scrubbed compact record of the checks run, their result, first failure fingerprint when needed, evidence references, omissions, and non-authority notice.

A validation summary cannot replace the validation command, hide a failed check, approve execution, approve product-repo access, send packages, bind runtime commands, bypass validation, or grant future authority.

### Audit Report

An audit report is reviewer output that classifies findings, risk, accepted limitations, and possible bounded follow-up candidates.

An audit report cannot execute recommendations, approve a demo, import itself into the queue, create or send packages, select product repos, bind runtime commands, approve phone actions, bypass validation, or grant future authority.

### Fixture

A fixture is committed local test data used to validate expected policy, schema, manifest, denial, defer, UNKNOWN, or dry-run behavior.

A fixture cannot select a real project, approve product-repo access, run a demo, create or send packages, bind runtime commands, approve phone actions, bypass validation, or grant future authority.

### Dry-Run Record

A dry-run record is local evidence of what a bounded harness path would decide without executing product work.

A dry-run record cannot execute the proposed action, mutate product repos, approve demo execution, stage files, commit, push, deploy, install packages, run migrations, send packages, bind runtime commands, or grant future authority.

### Package

A package is a local collection of allowlisted evidence files prepared for review after exact package-scope approval. In Codex Fleet audit contexts, packages are local evidence bundles unless separately approved for sending.

A package cannot approve its own contents, approve package sending, select product repos, run demos, import reviewer output, bypass validation, or grant future authority.

### Package Sending

Package sending is a separate exact human-approved action that transfers an already reviewed package outside the local machine.

Package sending is not approved by package creation, package manifests, validation summaries, prompts, audit reports, queue status, UI labels, mobile requests, or GREEN audit results. Without exact approval, package sending remains denied.

### Future Authority

Future authority is any attempted carry-over permission for later product-repo access, demo execution, package sending, runtime command binding, remote access, phone actions, all-fleet commands, overnight runner execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or non-mock UI implementation.

Future authority is denied by default. Passing tests, GREEN audits, dry-run outcomes, package manifests, reviewer comments, validation summaries, queue status updates, prompts, UI text, notifications, buttons, mobile requests, task packets, audit packages, and DOCX reports do not create future authority.

## Canonical Notice

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
