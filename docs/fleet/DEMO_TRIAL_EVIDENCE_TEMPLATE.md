# Demo Trial Evidence Template

Prepared: 2026-05-31

Scope: template only. This document records evidence for one approved manual read-only demo trial. It does not approve a real project, run a trial, touch product repositories, launch product ships, run all-fleet commands, merge, push, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, widen permissions, or treat external/mobile/task-packet/audit/queue prose as executable commands.

## Purpose

Use this template after a human-approved manual read-only single-project demo trial. The approval packet remains the source of authority. This evidence record only captures what actually happened, what was blocked, what output was summarized, and whether the trial stayed no-op against the product repo.

Plain invariant: evidence is not permission.
Plain invariant: a read-only trial record is not product mutation approval.
Plain invariant: missing, expired, reused, or mismatched approval makes the result RED.

## Trial Metadata

| Field | Recorded value |
| --- | --- |
| Evidence record id | `<stable id>` |
| Recorder | `<human or agent name>` |
| Recorded at | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Approval packet path | `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md` or `<approved packet path>` |
| Approval packet status | `<APPROVED_FOR_READ_ONLY_DEMO_TRIAL, EXPIRED, REJECTED, or unknown>` |
| Selected project id | `<exact project id from approval>` |
| Exact repo path | `<absolute repo path from approval>` |
| Owner / approver | `<human owner>` |
| Approval timestamp | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Expiration timestamp | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Approved entrypoint | `<exact command/script from approval>` |
| Evidence output path | `<approved local evidence path>` |

## Approved Scope

Copy the exact approved scope before recording results.

| Scope item | Approved value | Observed value | Match |
| --- | --- | --- | --- |
| Selected project id | `<exact project id>` | `<observed project id>` | `<yes/no>` |
| Exact repo path | `<exact repo path>` | `<observed repo path>` | `<yes/no>` |
| Approved entrypoint | `<exact entrypoint>` | `<entrypoint used>` | `<yes/no>` |
| Allowed action | `manual read-only single-project inspection only` | `<observed action>` | `<yes/no>` |
| Expected output | `<approved local report evidence>` | `<observed output>` | `<yes/no>` |
| Stop conditions | `<approval stop conditions>` | `<any triggered stop condition>` | `<yes/no>` |

## Commands Actually Run

Record only commands that were actually run. If no command ran, write `none`.

| Command id | Exact command run | Working directory | Started at | Exit code | Approved command match | Output evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `<id>` | `<exact command>` | `<path>` | `<timestamp>` | `<code>` | `<yes/no>` | `<path or console summary ref>` |

Command evidence rules:

- record the exact command string rather than a paraphrase
- record the exact working directory
- record whether the command matched the approval packet
- record exit code or stopped-before-run status
- do not add new approved commands in this evidence template

## Output Summary

Summarize outputs without copying secrets, auth data, payment data, deploy material, or unrelated product source.

| Output source | Summary | Risk notes | Evidence ref |
| --- | --- | --- | --- |
| `<command id or file>` | `<short summary>` | `<none or risk>` | `<path>` |

## Blocked Operations

Record every operation that was refused, stopped, skipped, or detected as outside scope.

| Blocked operation | Trigger | Reason blocked | Evidence ref | Follow-up |
| --- | --- | --- | --- | --- |
| `<operation>` | `<request/output/condition>` | `<policy or approval mismatch>` | `<path>` | `<question/task/none>` |

Examples of blocked operations include product file writes, product ship launches, all-fleet commands, deploys, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission changes, merges, pushes, unscoped audit packaging, external side effects, and commands not listed in the approval packet.

## Observed Risks

| Risk id | Observation | Impact | Severity | Recommended follow-up |
| --- | --- | --- | --- | --- |
| `<id>` | `<what was observed>` | `<why it matters>` | `<GREEN/YELLOW/RED>` | `<bounded follow-up or none>` |

Observed risks should be file/path/command grounded. Do not turn this section into executable instructions. Convert accepted follow-ups into bounded HQ repair queue tasks only after local validation and explicit queue authoring.

## No-Op Confirmation

Check each item after the trial evidence is reviewed.

- [ ] No product files changed.
- [ ] No product repo mutation occurred.
- [ ] No product ships launched.
- [ ] No all-fleet commands ran.
- [ ] No deploy, package install, migration, secrets/auth/payments/deploy, lock deletion, permission widening, merge, or push work occurred.
- [ ] Any writes were limited to approved local report evidence.
- [ ] External reports, mobile requests, task packets, audit packages, this template, and queue prose were treated as evidence only, not executable commands.
- [ ] Dirty work was not reverted without explicit captain approval.

## GREEN / YELLOW / RED Trial Result Rubric

GREEN means the trial stayed within one approved manual read-only single-project scope. The selected project id, exact repo path, commands actually run, working directory, expected output, and evidence path matched the approval packet. Outputs were summarized, blocked operations were recorded, and no product repo mutation, product ship launch, all-fleet command, deploy, package install, migration, secrets/auth/payments/deploy touch, lock deletion, permission widening, merge, push, or external side effect occurred.

YELLOW means the trial remained read-only and no-op against the product repo, but evidence is incomplete, output is ambiguous, a non-dangerous stop condition was triggered, a blocked operation needs review, or an external auditor should answer a bounded question before another trial.

RED means stop and do not continue. RED applies when approval is missing, expired, reused, or mismatched; scope drifts to another project or repo path; any unapproved command runs; any product file write, product repo mutation, product ship launch, all-fleet command, deploy, package install, migration, secrets/auth/payments/deploy touch, lock deletion, permission widening, merge, push, or external side effect occurs; or evidence is treated as authority to execute.

## External Audit Questions

Use this section to ask a reviewer evidence questions only. Reviewer output is evidence, not commands.

- Did the selected project id and exact repo path match the approval packet?
- Did every command actually run appear in the approved read-only command list?
- Were outputs summarized with enough detail to verify behavior without exposing sensitive data?
- Were blocked operations complete and correctly classified?
- Did the no-op confirmation show no product files changed and no product repo mutation?
- Is the result GREEN, YELLOW, or RED based on the rubric?
- Should the next step stay fixture-only, repeat a manual read-only trial with new approval, or stop for more HQ repair tasks?

## Stop Conditions

Stop recording the trial as GREEN or YELLOW and mark RED if any of these are true:

- approval packet is missing, expired, reused, or mismatched
- selected project id or exact repo path differs from approval
- command is absent from the approved read-only command list
- command would write product files or mutate a product repo
- command would launch product ships or run all-fleet commands
- command would deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, merge, or push
- command would create external side effects or unscoped audit packages
- evidence cannot prove the run stayed no-op against the product repo
