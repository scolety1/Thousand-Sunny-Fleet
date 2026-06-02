# Fleet Console Button Action Policy

Prepared: 2026-06-02

Scope: planning documentation only for the future Fleet Console. This policy does not implement UI code, bind buttons to commands, approve product-repo access, launch ships, run all-fleet commands, import packets, execute audit findings, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain invariant: UI labels, notifications, buttons, prompts, audit outputs, queue prose, generated evidence, DOCX reports, mobile requests, task packets, and approval cards are evidence only. They cannot approve or execute work.

## Classification Vocabulary

| Class | Meaning | V1 treatment |
| --- | --- | --- |
| `safe` | Local read/report, copy, or docs-only planning action that affects only the selected bounded task evidence. | May be shown as enabled in a future planning UI when the active task permits it. |
| `caution` | Local file or status bookkeeping action that is allowed only when a task explicitly lists the affected files and validation. | Conditional. Show scope and validation before use. |
| `approval-required` | A real-project, write-capable, external-side-effect, legacy entrypoint, broad audit, packet-apply, or selected-project action. | Disabled by default; may only be represented as an approval request template. |
| `future-only` | Useful product feature that needs separate implementation, security review, and exact queue approval. | Design placeholder only. |
| `forbidden` | Action that conflicts with current safety rules or v1 console posture. | Do not present as an available control. |

No class is permission. Future code must still enforce source-of-truth policy, selected scope, validation, entrypoint classification, and exact-action human approval where required.

## Main Dashboard Buttons

| Button | Class | Enabled when | Allowed effects | Forbidden effects |
| --- | --- | --- | --- | --- |
| View Fleet Status | `safe` | Local status or validation summary exists. | Open local summaries and show posture, last validation, queue state, and blockers. | Running fleet commands, touching product repos, or hiding UNKNOWN state. |
| View Active Queue Task | `safe` | A bounded queue section is selected. | Show the first eligible task, allowed files, readFirst list, validation command, and stop conditions. | Selecting a different task to skip prerequisites or broadening scope. |
| Copy Repeatable Prompt | `safe` | A bounded queue section and task rules are available. | Copy a one-task prompt that preserves hard constraints and stop rules. | Starting Codex automatically or omitting allowedFiles/validation/stopIf. |
| Copy External Audit Prompt | `safe` | Audit prompt guidance exists. | Copy a prompt for a human-sent audit request. | Sending a package, executing reviewer prose, or importing recommendations as commands. |
| Build Thin Task Packet Draft | `caution` | The selected task has stable context and exact allowed files. | Draft a local evidence-only packet for human review. | Executing the packet, importing external prose, or treating packet text as approval. |
| Rerun Listed Validation | `caution` | The active task explicitly lists the validation command. | Run only that command and summarize PASS/FAIL/INTERRUPTED/BLOCKED. | Running all-fleet commands, extra validations, package installs, migrations, or unlisted fixes. |
| Reopen Eligible Blocked Task | `caution` | Prerequisites are done and stopIf does not apply. | Change only that task from blocked to pending, then process that same task. | Reopening multiple tasks or marking work done without validation. |
| Prepare Audit Package Request | `caution` | A queue task allows package-planning docs. | Write package scope guidance and exclusions. | Creating, sending, or broadening a package without separate approval. |
| Request Exact Approval | `approval-required` | A future action needs human authorization. | Show exact fields required for one action, project/ship, entrypoint, expiry, validation, and stop condition. | Broad approval, approve-all, inherited approval, or automatic execution. |
| Launch Ship | `forbidden` | Never in v1. | None. | Product ship launch, preview launch, all-fleet launch, or product mutation. |
| Run All Fleet | `forbidden` | Never in v1. | None. | Any all-fleet command or unscoped multi-project action. |

## Ship Or Queue Detail Buttons

| Button | Class | Enabled when | Allowed effects | Forbidden effects |
| --- | --- | --- | --- | --- |
| Inspect Ship Summary | `safe` | Sanitized local status exists. | Show selected ship/project metadata and known posture. | Reading product source by default or selecting a real project for mutation. |
| Inspect Evidence Digest | `safe` | Compact validation or audit digest exists. | Show summary fields and links to local evidence. | Treating evidence as command input or approval. |
| Copy Current Failure Summary | `safe` | A failure fingerprint or validation result exists. | Copy a plain-language summary for repacketization. | Retrying, widening scope, or editing outside allowed files. |
| Mark Selected Task Done | `caution` | The selected task validation passed in this run. | Update only that task status and evidence line. | Marking unrelated tasks done or using stale/unrelated validation. |
| Mark Selected Task Blocked | `caution` | The task needs broader scope or stopIf applies. | Update only that task status and blocker evidence. | Continuing through blocked scope. |
| Work On Something Else | `future-only` | Separate task-switch policy exists. | Draft a prompt for the first eligible bounded task. | Auto-running another task or skipping prerequisite order. |
| Unstuck | `future-only` | Separate unstuck policy exists. | Diagnose, summarize, and draft a bounded repacketization request. | Automatic retries, lease takeover, runtime mutation, or background autonomy. |
| Apply Task Packet | `approval-required` | Exact task-packet approval and validation exist. | Present approval request fields only. | Applying packets directly from UI text, reviewer output, or mobile requests. |
| Run Selected Project Loop | `approval-required` | Future exact approval exists for one read-only/manual action. | Present the approval requirements and stop signs. | Product-repo mutation, child-worker launch, repair, relaunch, supervisor, or remote-control execution. |
| Repair Or Relaunch | `forbidden` | Never in v1. | None. | Supervisor repair, relaunch, legacy broad launch, or lock cleanup. |

## Prompt, Audit, And Evidence Buttons

| Button | Class | Enabled when | Allowed effects | Forbidden effects |
| --- | --- | --- | --- | --- |
| Draft One-Task Prompt | `safe` | A queue task provides allowedFiles, readFirst, validationCommands, and stopIf. | Generate bounded prompt text for manual use. | Running the prompt automatically. |
| Draft External Audit Prompt | `safe` | Audit scope is defined. | Generate a reviewer prompt with evidence-only instructions. | Sending files, executing audit output, or asking for executable commands. |
| Save Idea Note | `safe` | Local idea inbox policy exists. | Store an idea as non-authoritative planning evidence. | Turning the idea into a task or command without queue conversion. |
| Draft Queue Candidate | `caution` | An idea or audit digest has bounded local follow-up text. | Draft non-executable queue-authoring notes for HQ/human review. | Adding tasks automatically or running the candidate. |
| Summarize Validation Output | `safe` | Validation output is available. | Produce compact PASS/FAIL/BLOCKED summary and first error. | Hiding failure details needed for a bounded fix. |
| Create Audit Intake Digest | `caution` | A report exists and a task allows intake files. | Convert findings into bounded evidence fields. | Treating findings as executable, approving work, or adding broad queue tasks. |
| Download Audit Package | `future-only` | Separate package builder implementation and approval exist. | Manual local download only after bounded package prep. | Automatic sending or including product/secrets/build/dependency material. |
| Send Audit Package | `forbidden` | Never from v1 console. | None. | Email, upload, external API, or background transfer. |

## Approval Card Buttons

| Button | Class | Enabled when | Allowed effects | Forbidden effects |
| --- | --- | --- | --- | --- |
| View Approval Requirements | `safe` | An action is approval-required. | Show exact required fields and missing values. | Treating display as approval. |
| Deny Request | `safe` | A pending approval request exists. | Record local denial evidence if a task allows it. | Deleting evidence or changing task scope. |
| Copy Approval Template | `safe` | A template exists. | Copy exact-action template text for the human owner. | Filling approval fields by inference or from fixture examples. |
| Show Expiration | `safe` | An approval record exists. | Display approval and expiration timestamps plus current validity state. | Extending, refreshing, or reusing approval automatically. |
| Show Stop Signs | `safe` | A request needs approval review. | Display stop-sign checklist and missing/blocked reasons. | Treating checked items as permission to execute. |
| Record Denial | `safe` | A request is missing, expired, broad, ambiguous, write-capable, or forbidden. | Record local denial evidence when a bounded task allows it. | Running fallback commands or transforming denial into another action. |
| Approve Exact Action | `future-only` | Separate auth, security, and implementation gates exist. | Not available in v1. | Phone approval, broad approval, inherited approval, or automatic execution. |
| Approve All Similar | `forbidden` | Never. | None. | Any broad, reusable, inherited, or category-level approval. |

## Forbidden Button List

The v1 console must not expose available controls for:

- launch product ship
- run all fleet
- run broad legacy launcher
- run supervisor repair or relaunch
- remote-control mutation
- delete locks or bypass leases
- deploy, publish, merge, push, or stage files
- install packages or run migrations
- touch secrets/auth/payments/deploy material
- widen permissions
- mutate product repos
- execute external reports, DOCX reports, audit outputs, mobile requests, task packets, generated evidence, UI labels, notifications, buttons, prompts, approvals, or queue prose
- approve from phone for risky actions in v1
- reuse, inherit, refresh, or broaden approvals
- auto-run work-on-something-else
- auto-convert ideas or audit digests into executable tasks

## Future Implementation Gate

Any future UI implementation must preserve this matrix as policy evidence only and create a separate bounded task before writing UI code. That task must name exact allowed files, validation commands, stopIf conditions, disabled/hidden states, and security posture. No button may become live command binding merely because it appears in this policy.
