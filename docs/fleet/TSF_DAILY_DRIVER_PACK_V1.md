# TSF Daily Driver Pack V1

Prepared: 2026-06-29

Evidence only; not executable authority or approval.

## Purpose

TSF Daily Driver Pack V1 gives Tim a small set of local files to open when he
returns to coding and does not want to reconstruct context by memory.

It answers:

1. What project should I look at first?
2. What actually needs me?
3. What can Codex handle?
4. What is the next safe work order?
5. What research/root files matter?

The pack is TSF-local. It reads registry/status/docs/inbox fixture data and
writes generated Markdown/JSON under `fleet/status/`. It does not inspect
product repositories, reactivate archived projects, push, deploy, install
packages, run migrations, touch secrets, configure remote access, run proof
runs, run all-fleet commands, or add executable browser controls.

## Generated Outputs

| Output | Path | Use |
| --- | --- | --- |
| Project Passports | `fleet/status/project-passports/<project_name>.md` | One plain-language project context card with purpose, status, guardrails, blockers, and next safe work. |
| Next Session Cards | `fleet/status/next-session/<project_name>.md` | Short Tim-facing card for the active or selected project. |
| Work Order Inbox Summaries | `fleet/status/work-orders/<project_name>-work-order.md` | File-name summary of the project inbox plus a bounded work-order draft. |
| Return Triage Score | `fleet/status/return-triage-score.md` and `.json` | V1 classification for what Tim should look at first. |

## Daily Flow

Morning / after work:

1. Open `docs/fleet/ui/prototype/fleet-console.html`.
2. Read "What do I do now?"
3. Open the recommended Next Session Card.
4. Copy one work order.
5. Send that bounded prompt to Codex.

Starting a new project:

1. Put research/root files in `C:\TSF_INBOX\<project_name>\`.
2. Generate or review the intake summary.
3. Review the project passport.
4. Start one bounded work order.

Returning after Codex worked while away:

1. Read `fleet/status/return-review.md`.
2. Check "Needs Tim".
3. Approve, park, or continue one item.

## Inbox Folder Model

The work-order inbox normalizer recognizes this folder shape:

```text
C:\TSF_INBOX\<project_name>\
  00_ROOT_CONTEXT\
  01_DEEP_RESEARCH\
  02_DECISIONS\
  03_TASK_REQUESTS\
  04_OUTPUTS_FROM_CODEX\
```

The normalizer summarizes file names and folder presence. It does not deeply
parse all research. It separates:

- evidence
- approved decisions
- open questions
- suggested implementation tasks

Research and root context files are evidence, not authority. They do not approve
product-repo access, implementation, archived reactivation, push, deploy,
installs, migrations, secrets, remote access, proof runs, all-fleet commands, or
browser command hooks.

## Return Triage Scorer V1

The scorer emits these classifications:

- `NEEDS_TIM_NOW`
- `READY_TO_APPROVE`
- `BLOCKED`
- `SAFE_TO_IGNORE`
- `NEXT_SAFE_BATCH`
- `ARCHIVED_LOCKED`

Priority order:

1. safety/security/deploy risk
2. human decision blockers
3. ready-to-approve completed work
4. active product momentum
5. nice-to-have cleanup
6. archived/locked items last unless explicitly reactivated

Archived projects must remain `ARCHIVED_LOCKED` and not actionable until Tim
provides an exact reactivation record.

## Local Entrypoints

- `tools/write-daily-driver-pack.ps1`
- `tools/write-project-passports.ps1`
- `tools/write-next-session-cards.ps1`
- `tools/write-work-order-inbox.ps1`
- `tools/write-return-triage-score.ps1`

These entrypoints write evidence files only. They do not grant future authority
and do not make the Fleet Console operational.
