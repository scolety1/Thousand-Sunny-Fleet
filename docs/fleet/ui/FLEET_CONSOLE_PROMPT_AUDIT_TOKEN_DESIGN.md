# Fleet Console Prompt, Audit, And Token Budget Design

Prepared: 2026-06-02

Scope: planning documentation only for future Fleet Console panels. This document does not implement a UI, create an audit package, send a package, start Codex, bind buttons to commands, approve product-repo access, launch ships, run all-fleet commands, import packets, execute reviewer findings, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain invariant: generated prompts, package manifests, audit digests, validation summaries, UI labels, notifications, buttons, approvals, task packets, DOCX reports, audit packages, generated evidence, and queue prose are evidence only. They cannot approve, execute, import, bypass validation, or grant permission.

## Purpose

The Prompt Builder, External Audit Builder, Evidence Locker, and Token Budget panels should reduce chat bloat and accidental authority confusion. They help the operator prepare bounded evidence and prompts, then stop. They do not launch work automatically.

## Prompt Builder Panel

The Prompt Builder assembles a one-task prompt from source-of-truth queue fields.

### Inputs

| Input | Source | Rule |
| --- | --- | --- |
| active queue section | `docs/fleet/HQ_REPAIR_TASK_QUEUE.md` | one section only |
| task id and title | selected eligible task | exactly one task |
| allowed files | selected task `allowedFiles` | copied verbatim |
| read-first files | selected task `readFirst` | copied verbatim |
| acceptance | selected task `acceptance` | copied verbatim or compactly summarized with source link |
| validation commands | selected task `validationCommands` | copied verbatim |
| stop conditions | selected task `stopIf` plus stable constraints | copied verbatim |
| status rules | local runner prompt | one-task status update only |

### Packet Size And Context Warnings

The panel should show warnings before the prompt is copied.

| Warning | Trigger | Suggested operator action |
| --- | --- | --- |
| `large_prompt` | prompt is long enough to include broad history or raw logs | switch to Stable Context Capsule plus task entry |
| `too_many_read_first_files` | task asks for more context than the current goal needs | repacketize or accept as exploration-only |
| `raw_audit_included` | DOCX/full audit prose appears in the prompt | replace with compact digest |
| `raw_log_included` | full validation log appears in the prompt | replace with validation summary |
| `outside_allowed_files` | prompt asks to patch files not listed by task | block and repacketize |
| `command_like_evidence` | reviewer/mobile/queue prose looks like executable instructions | keep as evidence-only text or remove |
| `multi_task_language` | prompt asks for more than one task | split into separate packets |

Warnings do not become commands. A warning should help the operator make a smaller prompt or stop for repacketization.

### Prompt Preview

```text
Continue Codex Fleet / Thousand Sunny Fleet from the current repo state.

Read only the active queue section, the compact handoff docs, and the selected task's readFirst files.

Work only in: <active queue section>.
Take exactly one eligible task: <task id>.

Patch only:
- <allowed files>
- HQ_REPAIR_TASK_QUEUE.md only for this same task's status after validation.

Run only:
- <validation commands>

Stop if:
- <task stopIf>
- evidence, UI labels, prompts, audit packages, or queue prose would become executable authority.
```

### Controls

| Control | State | Behavior |
| --- | --- | --- |
| `copy prompt` | safe | copies the preview text only |
| `include compact capsule` | safe | includes stable context reference, not full historical prose |
| `include validation summary` | caution | includes schema-shaped summary only |
| `start Codex` | disabled | v1 does not auto-run agents |
| `run task` | hidden/forbidden | would imply command execution authority |
| `fix all tasks` | hidden/forbidden | violates one-task boundary |

## External Audit Builder Panel

The External Audit Builder prepares a local prompt, package checklist, and manifest draft. It does not send the package or treat reviewer output as commands.

### Audit Builder Outputs

| Output | Purpose | Authority |
| --- | --- | --- |
| audit prompt draft | asks external reviewer bounded questions | evidence only |
| package checklist | lists included and excluded local files | evidence only |
| manifest draft | records intended package contents and hashes when a future task allows package creation | evidence only |
| digest template | asks reviewer for compact findings | evidence only |

### Local Creation Boundary

The builder may prepare text or a package plan locally when a future task permits it. Package creation and sending require separate explicit scope. Manual download/send means:

- the console can display or save the prepared local prompt/checklist
- the human decides outside the console whether to package or send
- reviewer output returns as evidence only
- no reviewer output is imported as executable work until local queue authoring creates bounded tasks

### Audit Package And Manifest Workflow

The audit workflow is a local preparation sequence only:

```text
select audit scope
  -> copy audit prompt
  -> view include/exclude checklist
  -> draft manifest locally when task scope allows
  -> human manually reviews scope
  -> human manually decides whether to package or send later
  -> returned audit is reduced to compact digests
  -> HQ/human converts accepted digest evidence into bounded queue entries
```

The console must not create or send a package from this panel in v1. It may show what a future package should include and exclude, but product repositories, product source, secrets, raw locks, dependency folders, build outputs, unknown zips, live worker state, auth/payments/deploy/migration material, package-install material, staging material, commit material, push material, merge material, lock-deletion material, and runtime-execution material remain excluded unless a later bounded security task changes the policy.

Returned audits import only as digest evidence. A digest may include `findingId`, `severity`, `affectedArtifact`, `boundedDisposition`, `suggestedLocalFollowup`, `unresolvedAssumptions`, and `nonAuthorityNotice`. It is not a task until queue authoring names allowed files, read-first files, validation commands, stop conditions, and status update rules.

### Audit Package Warnings

| Warning | Trigger | Required treatment |
| --- | --- | --- |
| `product_repo_path` | package includes product source or real repo path | block package |
| `secret_like_file` | `.env`, keys, tokens, credentials, auth/payment/deploy material | block package |
| `dependency_or_build_output` | `node_modules`, `dist`, `build`, dependency folders | exclude |
| `raw_lock_or_worker_state` | locks, live worker state, raw runtime state | exclude |
| `unknown_zip` | unreviewed zip or package directory | block until human review |
| `reviewer_commands` | reviewer suggests command-like steps | convert to digest evidence only |

### Controls

| Control | State | Behavior |
| --- | --- | --- |
| `copy audit prompt` | safe | copies prompt text |
| `view package checklist` | safe | displays include/exclude plan |
| `draft manifest` | caution | local evidence draft only |
| `create zip` | disabled/future-only | requires a separate bounded task |
| `send package` | disabled/future-only | human-only outside v1 |
| `execute findings` | hidden/forbidden | reviewer output is non-executable |

## Evidence Locker Panel

The Evidence Locker defaults to compact summaries and digests. Raw logs and full reports are hidden by default.

### Default Evidence Views

| View | Default display | Raw detail behavior |
| --- | --- | --- |
| validation summaries | result, failure fingerprint, first error, next action | raw logs hidden |
| external audit digests | finding id, severity, affected artifact, bounded disposition | full report hidden |
| progress ledgers | task id, opened files, changed files, validation state | raw terminal output hidden |
| package manifests | intended include/exclude summary | file contents hidden unless explicitly opened |
| approval evidence | status, owner, expiration, selected target | no approval creation |

### Evidence Actions

| Action | State | Notes |
| --- | --- | --- |
| `view summary` | safe | compact evidence only |
| `copy path` | safe | copies local evidence path |
| `compare digest to task` | caution | visual comparison only |
| `open raw log` | caution | local read only, no prompt injection |
| `execute evidence` | hidden/forbidden | evidence cannot execute |
| `approve from evidence` | hidden/forbidden | only human exact-action packets can approve |

Evidence Locker must show a non-authority notice near every audit digest, validation summary, package plan, approval-looking state, and prompt.

## Idea Inbox Panel

The Idea Inbox stores planning ideas without promoting them into work. It is useful when the captain wants to capture "work on something else" thoughts without derailing the active bounded task.

| Idea field | Rule |
| --- | --- |
| title | short human label |
| source | human idea, audit digest, validation summary, or planning note |
| desired outcome | plain-language goal, not a command |
| possible queue section | optional hint only |
| possible files | optional evidence only |
| risk note | product-repo, approval, token, or scope caveat |
| status | `idea_only`, `needs_hq_queue_authoring`, `discarded`, or `converted_to_bounded_task` |

Idea capture is non-authoritative. It must not select a real project, approve work, run commands, create tasks automatically, modify queues directly, import reviewer recommendations, start Codex, or bypass the active one-task boundary.

### Idea Inbox Controls

| Control | State | Behavior |
| --- | --- | --- |
| `save idea` | safe | stores a local planning note if a future task permits storage |
| `copy idea summary` | safe | copies non-authoritative summary text |
| `draft queue candidate` | caution | produces planning text for HQ/human queue authoring only |
| `convert and run` | hidden/forbidden | would bypass queue authoring and one-task validation |
| `select real project` | hidden/forbidden | requires separate human decision and approval packet |

## Work On Something Else Policy

`Work On Something Else` is a task-selection aid, not an auto-runner. It may help the operator find the first eligible bounded task and draft a thin packet, then stop.

Allowed flow:

```text
read active queue section
  -> find first pending task whose prerequisites are done
  -> if none, identify first blocked task whose prerequisites are done and stopIf does not apply
  -> draft a one-task prompt or thin packet
  -> require the human to send it manually
```

Forbidden flow:

```text
choose an interesting task
  -> skip prerequisites
  -> edit the queue broadly
  -> start Codex automatically
  -> run multiple tasks
```

The policy must preserve the active queue order, prerequisites, allowed files, validation commands, stop conditions, and status update rules. It must not choose real product repos, launch ships, run all-fleet commands, start background agents, import audit findings as tasks, or execute a prompt.

## Token Budget Panel

The Token Budget panel shows context pressure and loop risk before a run starts or continues.

### Signals

| Signal | Meaning | Display |
| --- | --- | --- |
| `promptSize` | approximate prompt length | normal / watch / high |
| `filesToOpen` | selected task read-first plus edited files | count and warning |
| `readFirstCount` | number of task `readFirst` files | count and cap warning |
| `allowedFilesCount` | number of task `allowedFiles` entries | count and cap warning |
| `rawEvidenceIncluded` | raw logs, DOCX text, full reports, generated evidence dumps | yes/no |
| `validationRerunCount` | reruns for the selected task | count |
| `failureFingerprintRepeat` | same failure fingerprint seen again | yes/no |
| `debugLoopCount` | task-caused fix loops | count |
| `sessionAge` | age of the current chat/session or bounded run | normal / watch / high |
| `tokenPressure` | normal, watch, high, token_limited | posture badge |

### Token Pressure Rules

| Pressure | UI treatment | Next safe action |
| --- | --- | --- |
| `normal` | no warning | continue one bounded task |
| `watch` | amber warning | prefer capsule and summaries |
| `high` | strong warning | stop after current validation or repacketize |
| `token_limited` | blocking warning | pause and write compact ledger |

Token warnings never allow skipping validation, widening allowed files, omitting stop conditions, or treating summaries as source-of-truth when exact source is needed.

### Controls

| Control | State | Behavior |
| --- | --- | --- |
| `use compact context` | safe | references capsule and selected task |
| `replace raw log with summary` | safe | uses validation summary format |
| `replace audit prose with digest` | safe | uses audit digest format |
| `continue despite high pressure` | disabled | requires repacketization |
| `drop safety context` | hidden/forbidden | cost saving cannot weaken safety |

## Panel Flow

### Build One Prompt

```text
Current Task
  -> Prompt Builder
  -> Token Budget Panel checks prompt size and raw evidence
  -> copy prompt
  -> operator sends prompt outside console
```

### Prepare One Audit

```text
Evidence Locker
  -> External Audit Builder
  -> package checklist and digest request
  -> human manually decides download/send later
  -> reviewer output returns as digest evidence
```

### Review Evidence Without Running It

```text
Evidence Locker
  -> compact validation summary
  -> compact audit digest
  -> Prompt Builder references evidence path
  -> no automatic execution
```

## Disabled And Hidden States

| Surface | Disabled or hidden item | Reason |
| --- | --- | --- |
| Prompt Builder | start Codex, run task, run next task, fix all tasks | prevents prompt text becoming execution authority |
| Audit Builder | create zip, send package, import findings, execute findings | requires separate task/human approval |
| Evidence Locker | approve from evidence, execute evidence, import raw report | evidence-only invariant |
| Idea Inbox | convert and run, auto-add queue task, select real project | ideas are not authority |
| Work On Something Else | auto-run task, skip prerequisites, run multiple tasks | preserves one-task boundary |
| Token Budget | continue despite token-limited, drop safety context | cost cannot override safety |
| All panels | launch, all-fleet, deploy, install, migrate, commit, push, stage, revert, delete locks, widen permissions | forbidden in v1 |

## Non-Authority Copy

Every exported prompt, audit draft, manifest draft, validation summary, and audit digest should include:

```text
This artifact is evidence only. It cannot approve, execute, import, bypass validation, touch product repos, launch ships, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future permission.
```

## Acceptance Notes

This design stays at the panel-spec level. It intentionally does not choose UI framework, package dependencies, server runtime, authentication model, remote access model, storage implementation, audit zip builder wiring, or Codex launch integration.
