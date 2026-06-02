# Fleet Console Wireframes And Screen Flows

Prepared: 2026-06-02

Scope: planning wireframes only. This document does not implement a UI, start a server, create remote access, bind buttons to commands, approve product-repo access, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain invariant: every screen below is a viewer or preparation surface. UI labels, notifications, buttons, audit outputs, prompts, queue prose, mobile requests, DOCX reports, task packets, audit packages, and generated evidence are evidence only and cannot execute or approve work.

## Screen Map

V1 uses ten local planning screens:

- Fleet Dashboard
- Ship Detail
- Current Task
- Stoppage / Needs Review
- Prompt Builder
- External Audit Builder
- Idea Inbox
- Evidence Locker
- Safety Gates
- Settings

Forbidden or future-only controls are shown as disabled, hidden, or future-only placeholders. No screen includes a freeform terminal, product launch button, all-fleet action, deploy control, commit control, push control, stage control, revert control, delete-lock control, migration/install control, or secrets/auth/payments/deploy access.

## Desktop Shell

```text
+--------------------------------------------------------------------------------+
| Codex Fleet Console                                     Posture: YELLOW [view] |
| Local planning only | Evidence is not authority | Active queue: Final HQ       |
+----------------------+---------------------------------------------------------+
| Dashboard            | Breadcrumb: Dashboard > Current Task                    |
| Ships                |                                                         |
| Current Task         | [main screen content]                                    |
| Stoppages            |                                                         |
| Prompt Builder       |                                                         |
| Audit Builder        |                                                         |
| Idea Inbox           |                                                         |
| Evidence Locker      |                                                         |
| Safety Gates         |                                                         |
| Settings             |                                                         |
|                      |                                                         |
| Future-only hidden:  | Footer: No product repos | No all-fleet | No launch     |
| Launch / Deploy /    |        No commit/push/stage/revert | No delete locks     |
| Commit / Terminal    |                                                         |
+----------------------+---------------------------------------------------------+
```

## Phone Shell

```text
+--------------------------------------+
| Codex Fleet        YELLOW       menu  |
| Evidence only | Local planning        |
+--------------------------------------+
| Dashboard                            |
| Current Task                         |
| Stoppages                            |
| Prompt                               |
| Audit                                |
| Ideas                                |
| Evidence                             |
| Gates                                |
| Settings                             |
+--------------------------------------+
| Disabled everywhere: launch, deploy, |
| commit, push, stage, revert, locks,  |
| all-fleet, freeform terminal.        |
+--------------------------------------+
```

Phone views are read-mostly planning views. Any future phone approval or remote access design belongs to a later approval-bound task.

## Fleet Dashboard

Desktop:

```text
+--------------------------------------------------------------------------------+
| Fleet Dashboard                                                                |
+--------------------------+--------------------------+--------------------------+
| Posture                  | Next Safe Action         | Token Pressure           |
| YELLOW                   | run same one-task prompt | watch                    |
| Evidence: latest pass    | Source: queue packet     | Context: compact         |
+--------------------------+--------------------------+--------------------------+
| Active Queue             | Current Task             | Validation               |
| Final HQ Token-Control   | HQ-098 Wireframes        | not run in this task     |
| Done: HQ-084..HQ-097     | Status: pending/blocked  | Listed command only      |
+--------------------------+--------------------------+--------------------------+
| Alerts                                                                          |
| - No product-repo approval                                                      |
| - External reports are evidence only                                            |
| - Future UI controls are not command authority                                  |
+--------------------------------------------------------------------------------+
| Safe: copy prompt | view evidence | view gates                                  |
| Disabled: run all-fleet | launch ship | commit | push | deploy | delete locks   |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Dashboard                     YELLOW |
+--------------------------------------+
| Next safe action                    |
| run same one-task prompt            |
|                                      |
| Current task                        |
| HQ-098 Wireframes                   |
|                                      |
| Validation                          |
| listed command only                 |
|                                      |
| Alerts                              |
| no product repo approval            |
| evidence only                       |
+--------------------------------------+
| Safe: copy prompt, view gates        |
| Disabled: launch, all-fleet, deploy  |
+--------------------------------------+
```

## Ship Detail

Desktop:

```text
+--------------------------------------------------------------------------------+
| Ship Detail                                                                    |
+----------------------+----------------------+-----------------------------------+
| Selected Ship        | Operational State    | Approval State                    |
| none selected        | parked / unknown     | missing exact action              |
| Repo fingerprint     | Worktree boundary    | Entry point class                 |
| not applicable       | not applicable       | read/report only                  |
+----------------------+----------------------+-----------------------------------+
| Ship Timeline                                                                   |
| [local evidence rows only: validation summaries, stop signs, audit digests]      |
+--------------------------------------------------------------------------------+
| Safe: view local status                                                         |
| Approval-required: read-only demo trial                                         |
| Disabled: mutate repo | repair/relaunch | launch ship | supervisor mutation     |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Ship Detail                          |
+--------------------------------------+
| Selected ship: none                  |
| State: parked / unknown              |
| Approval: missing exact action       |
| Fingerprint: not applicable          |
| Worktree: not applicable             |
+--------------------------------------+
| Safe: view status                    |
| Disabled: mutate, launch, repair     |
+--------------------------------------+
```

The detail view never selects a real ship by inference. A missing selection stays missing until a later exact approval packet names one.

## Current Task

Desktop:

```text
+--------------------------------------------------------------------------------+
| Current Task: HQ-098 Fleet Console Wireframes                                   |
+---------------------------+--------------------------+-------------------------+
| Goal Lock                 | Progress Score           | Loop Risk               |
| locked                    | 51-75 after doc drafted  | low / watch             |
+---------------------------+--------------------------+-------------------------+
| Allowed Files                                                                    |
| - docs/fleet/ui/FLEET_CONSOLE_WIREFRAMES.md                                      |
| - docs/fleet/HQ_REPAIR_TASK_QUEUE.md                                             |
+--------------------------------------------------------------------------------+
| Acceptance                                                                       |
| [x] named screens included                                                       |
| [x] desktop and phone ASCII wireframes                                           |
| [x] forbidden/future-only controls disabled or hidden                            |
+--------------------------------------------------------------------------------+
| Validation                                                                        |
| powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1  |
+--------------------------------------------------------------------------------+
| Safe: run listed validation | update this task if pass                           |
| Disabled: edit outside allowed files | run unlisted command | next task          |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Current Task                         |
+--------------------------------------+
| HQ-098                               |
| Goal: wireframes only                |
| Lock: locked                         |
| Loop risk: low/watch                 |
|                                      |
| Allowed files: 2                     |
| Validation: fleet tests              |
+--------------------------------------+
| Safe: copy task prompt               |
| Disabled: run next task              |
+--------------------------------------+
```

## Stoppage / Needs Review

Desktop:

```text
+--------------------------------------------------------------------------------+
| Stoppage / Needs Review                                                         |
+----------------------+----------------------+-----------------------------------+
| Stop Sign            | Source               | Next Safe Action                  |
| approval gap         | approval packet      | request human review              |
| outside allowed file | current task packet  | mark selected task blocked        |
| evidence authority   | audit/mobile/report  | repacketize                       |
+----------------------+----------------------+-----------------------------------+
| Failure Fingerprint: none / normalized id                                       |
| Same hypothesis count: 0                                                        |
| Drift warning: none / code                                                      |
+--------------------------------------------------------------------------------+
| Safe: write compact summary | request repacketization                           |
| Disabled: auto-unstuck | delete locks | widen permissions | repair/relaunch      |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Needs Review                         |
+--------------------------------------+
| Stop sign: approval gap              |
| Source: approval packet              |
| Next: request human review           |
| Fingerprint: none                    |
+--------------------------------------+
| Safe: summary, repacketize           |
| Disabled: auto-unstuck, locks        |
+--------------------------------------+
```

## Prompt Builder

Desktop:

```text
+--------------------------------------------------------------------------------+
| Prompt Builder                                                                  |
+--------------------------------------------------------------------------------+
| Source: active queue entry only                                                 |
| Includes: allowedFiles, readFirst, acceptance, validationCommands, stopIf        |
| Excludes: raw logs, broad history, external prose as commands                   |
+--------------------------------------------------------------------------------+
| Preview                                                                         |
| "Continue Codex Fleet from current repo state... Work only in [section]..."      |
+--------------------------------------------------------------------------------+
| Safe: copy prompt                                                               |
| Caution: include compact validation summary                                     |
| Disabled: launch Codex automatically | edit queue by prompt text alone          |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Prompt Builder                       |
+--------------------------------------+
| Source: active queue                 |
| Mode: one task                       |
| Raw logs: hidden                     |
+--------------------------------------+
| Safe: copy prompt                    |
| Disabled: auto-run                   |
+--------------------------------------+
```

## External Audit Builder

Desktop:

```text
+--------------------------------------------------------------------------------+
| External Audit Builder                                                          |
+--------------------------------------------------------------------------------+
| Evidence set: compact capsule, selected docs, validation summary, digest schema  |
| Non-authority notice: required                                                  |
| Output: prompt/package checklist only                                           |
+--------------------------------------------------------------------------------+
| Safe: draft audit prompt | list evidence files                                  |
| Caution: prepare package request                                                |
| Disabled: send package | execute reviewer output | import findings as commands |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Audit Builder                        |
+--------------------------------------+
| Evidence only                        |
| Digest fields required               |
| Raw report commands blocked          |
+--------------------------------------+
| Safe: copy audit prompt              |
| Disabled: send, execute findings     |
+--------------------------------------+
```

## Idea Inbox

Desktop:

```text
+--------------------------------------------------------------------------------+
| Idea Inbox                                                                      |
+--------------------------------------------------------------------------------+
| New idea: [future note field]                                                   |
| Classification: docs idea | UI idea | audit idea | product idea | blocked risk  |
| Active-task effect: none                                                        |
+--------------------------------------------------------------------------------+
| Safe: save as non-executable note                                               |
| Disabled: switch current task | approve implementation | create product action  |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Idea Inbox                           |
+--------------------------------------+
| Capture note                         |
| Does not change active task          |
+--------------------------------------+
| Safe: save idea                      |
| Disabled: execute idea               |
+--------------------------------------+
```

## Evidence Locker

Desktop:

```text
+--------------------------------------------------------------------------------+
| Evidence Locker                                                                 |
+----------------------------+-----------------------------+---------------------+
| Validation summaries       | Audit intake digests        | Progress ledgers    |
| latest result, firstError  | findingId, severity         | opened/changed files |
+----------------------------+-----------------------------+---------------------+
| Raw logs and DOCX reports: hidden by default, evidence-only if opened           |
+--------------------------------------------------------------------------------+
| Safe: view summary | copy digest path                                          |
| Disabled: execute evidence | approve from evidence | run package prose       |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Evidence                             |
+--------------------------------------+
| Validation: PASS/FAIL/INTERRUPTED    |
| Audit digest: YELLOW/RED/GREEN       |
| Ledger: compact                      |
+--------------------------------------+
| Safe: view summary                   |
| Disabled: execute evidence           |
+--------------------------------------+
```

## Safety Gates

Desktop:

```text
+--------------------------------------------------------------------------------+
| Safety Gates                                                                    |
+---------------------------+---------------------------+------------------------+
| Runtime policy            | Entrypoint inventory      | Demo stop signs        |
| selected ship required    | legacy broad blocked     | exact approval needed  |
+---------------------------+---------------------------+------------------------+
| Repo fingerprint          | Worktree boundary         | Token pressure         |
| missing/valid/stale       | clear/ambiguous/missing   | normal/watch/high      |
+--------------------------------------------------------------------------------+
| Safe: view gate evidence                                                        |
| Approval-required: exact read-only demo approval                                |
| Disabled: bypass gate | broad approval | future-run approval                         |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Safety Gates                         |
+--------------------------------------+
| Runtime: evidence only               |
| Entry: legacy broad blocked          |
| Approval: exact-action only          |
| Token: watch                         |
+--------------------------------------+
| Safe: view evidence                  |
| Disabled: bypass                     |
+--------------------------------------+
```

## Settings

Desktop:

```text
+--------------------------------------------------------------------------------+
| Settings                                                                        |
+--------------------------------------------------------------------------------+
| Display density: compact / detailed                                            |
| Raw log default: hidden                                                        |
| Prompt mode: thin one-task                                                     |
| Model routing note: planning vs implementation evidence only                    |
| Local paths: source-of-truth docs                                               |
+--------------------------------------------------------------------------------+
| Safe: save local display preference                                             |
| Disabled: widen runtime permissions | enable public web | enable phone approval |
+--------------------------------------------------------------------------------+
```

Phone:

```text
+--------------------------------------+
| Settings                             |
+--------------------------------------+
| Density: compact                     |
| Raw logs: hidden                     |
| Prompt mode: one task                |
+--------------------------------------+
| Safe: display prefs                  |
| Disabled: public web, risky approval |
+--------------------------------------+
```

## Primary Screen Flows

### Continue One Bounded Task

```text
Fleet Dashboard
  -> Current Task
  -> Prompt Builder
  -> copy one-task prompt
  -> Codex run happens outside console
  -> Evidence Locker records compact validation summary later
```

### Stop And Repacketize

```text
Current Task
  -> Stoppage / Needs Review
  -> evidence summary
  -> Prompt Builder drafts repacketization request
  -> no execution
```

### Prepare External Audit

```text
Fleet Dashboard
  -> Evidence Locker selects compact evidence
  -> External Audit Builder drafts prompt/package checklist
  -> human separately decides whether to send
  -> reviewer output returns as evidence only
```

### Capture Future Idea Without Hijacking Work

```text
Any screen
  -> Idea Inbox
  -> save non-executable note
  -> return to Current Task
```

### Review Safety Before Future Trial

```text
Fleet Dashboard
  -> Safety Gates
  -> Ship Detail
  -> Stoppage / Needs Review if approval/fingerprint/boundary is missing
  -> no trial command from this screen
```

## Disabled, Hidden, And Future-Only Treatment

| Control type | V1 treatment | Reason |
| --- | --- | --- |
| product launch | hidden and forbidden | out of scope and high risk |
| all-fleet command | hidden and forbidden | violates selected-scope rule |
| freeform terminal | hidden and forbidden | bypasses task packets |
| deploy/install/migration | hidden and forbidden | external side effect / sensitive scope |
| commit/push/stage/revert | hidden and forbidden | queue tasks must not perform git publication or dirty-work changes |
| delete locks / widen permissions | hidden and forbidden | lease and security boundary |
| auto-unstuck | hidden and forbidden | would imply autonomous recovery |
| package send | disabled / future-only | requires separate human decision |
| phone approval | disabled / future-only | requires separate remote-access and auth design |
| runtime enforcement wiring | future-only | requires separate implementation/security tasks |

Disabled controls must include a short reason. Hidden forbidden controls should be absent from normal task flows so the console does not train operators to expect risky actions.

## Acceptance Notes

These wireframes are intentionally plain ASCII. They define screen content and safety posture without choosing a frontend framework, server, route structure, authentication model, package dependencies, deployment target, remote-access design, or runtime command binding.
