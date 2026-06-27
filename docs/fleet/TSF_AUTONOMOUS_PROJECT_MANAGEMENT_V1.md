# TSF Autonomous Project Management V1

Prepared: 2026-06-27

Evidence only; not executable authority or approval.

## Purpose

TSF Autonomous Project Management V1 upgrades TSF from a one-task control
layer into a bounded project-management control layer. V1 accepts a project
brain, project inbox evidence, research/root files, a queue of tasks, and an
autonomy profile, then produces a Codex work guide and report.

V1 is a control and guidance layer. It does not execute product repo work by
itself. It does not push, deploy, install packages, run migrations, touch
secrets, configure remote access, run proof runs, run all-fleet, run unbounded
overnight runners, reactivate archived projects, approve phone actions, or bind
runtime commands.

## Project Brain And Intake

Each project brain may point at a local artifact intake folder:

```text
C:\TSF_INBOX\<project_name>\
```

The project name must be a single safe folder name. The intake folder should
contain `INTAKE.md` plus `MANIFEST.md` or `manifest.json`. Raw files stay under
the project inbox and remain evidence/reference only.

The project-management packet names:

- selected project
- selected track
- project section
- archived status
- inbox project name
- research files
- root files
- queue tasks
- autonomy profile
- approval records, if any

Research files are relative paths inside the project inbox. Root files are
relative paths inside the selected project root. Naming a file means Codex may
read it for context when the packet is otherwise eligible; it does not approve
mutation or broad search.

## Autonomy Profiles

V1 supports exactly these autonomy profiles:

| Profile | Patch authority | Batch behavior | Question behavior |
| --- | --- | --- | --- |
| `review_only` | none | inspect one selected review item | report questions |
| `bounded_implementation` | one eligible task | stop after the selected task validation | ask only true blockers |
| `batch_implementation` | bounded eligible queue slice | continue across up to five eligible tasks | batch nonurgent questions |
| `away_safe` | bounded low-risk eligible queue slice | continue across up to three eligible tasks | collect Tim Question Queue |

All profiles require one selected project, one selected track, explicit task
scope, validation commands, and stop conditions. A profile is not approval. It
only chooses how much already-eligible work can be grouped before reporting.

## Stop Conditions

Codex should pause only for real blockers, not every small step. V1 treats these
as real blockers:

- missing or ambiguous selected project, track, task, allowed files, validation,
  or `stopIf`
- archived, paused, finished, blocked, idea-only, out-of-focus, or unreactivated
  project/track
- product repo mutation without exact selected-project approval
- push, deploy, package install, migration, secrets/auth/payments/deploy, remote
  access, all-fleet, proof run, or overnight runner request without exact
  approval
- validation failure without a known-fix route inside allowed files
- same uncertainty, failure fingerprint, missing context, or scope question
  repeats twice
- scope expansion would be required to meet the definition of done

Nonurgent questions, optional polish choices, and ordinary task-to-task
bookkeeping are collected in the report when the selected profile allows
continuation.

## Batch Queue Terminal States

Every batch queue resolves to one terminal state:

| Terminal state | Meaning |
| --- | --- |
| `GREEN` | all queue items are complete with GREEN validation evidence |
| `YELLOW` | pending, in-progress, deferred, or not-yet-validated work remains |
| `RED` | at least one item failed validation or crossed a safety boundary |
| `BLOCKED` | at least one item needs Tim, repacketization, or a known-fix route |

`YELLOW` is not failure. It means work can be continued only if the profile,
batch cap, validation, and stop gates still allow it.

## Away-Mode Report Format

The `away_safe` report must use this shape:

```text
# TSF Away Mode Report

## Captain Summary
## Project / Track / Assignment
## Autonomy Profile And Batch Limits
## Batch Queue Status
## Completed / Blocked / Deferred / Skipped
## Validation Evidence
## Stop Conditions Encountered
## Tim Question Queue
## Boundaries Preserved
## Next Safe Action
```

The report must include terminal state, autonomy profile, selected tasks,
validation evidence, blockers, questions for Tim, final boundary confirmations,
and the next safe action. It must not hide failed validation behind a GREEN
summary.

## Guardrails Preserved

V1 preserves these hard guardrails:

- no product repo mutation unless the project is selected and exact approval is
  present
- no archived project mutation unless an exact reactivation record is present
- no push, deploy, package install, migration, secrets/auth/payments/deploy,
  remote access, all-fleet, proof run, or unbounded overnight work unless
  separately and exactly approved
- no phone/dashboard approval or execution authority
- no raw private intake commit unless explicitly approved for the exact file set
- no queue prose, report prose, validation summary, UI label, or generated file
  can approve execution or future authority

## Local Entrypoint

Use the local control command for dry guidance:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\invoke-project-management-control.ps1 `
  -PacketPath .\tests\fixtures\fleet\project-management\active-batch.packet.json `
  -InboxRoot .\.codex-local\fixtures\project-management\TSF_INBOX
```

The command writes JSON and Markdown reports under `out/project-management\`.
It sets `executesProductActions`, `mutatesProductRepos`, `nonExecutable`, and
`canApproveFutureRuns` so consumers cannot confuse the guide with authority.

## Status

This V1 is a Fleet-only control-plane implementation with docs, helper
functions, fixtures, and regression coverage.

It does not implement a product adapter, runner, proof-run pathway, phone bridge, push pathway, deploy path, or remote-access mechanism.
