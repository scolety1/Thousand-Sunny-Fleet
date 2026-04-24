# Project Setup

This setup treats chats as roles, not as an automation API.

## Control model

ChatGPT Pro controls direction through project plans and task queues.

Codex controls code edits only inside local repo guardrails.

PowerShell controls execution, builds, reports, commits, and stopping conditions.

```text
ChatGPT Pro project
  plans phases and writes safe tasks
        |
        v
repo docs/codex/TASK_QUEUE.md
        |
        v
PowerShell Codex loop
        |
        v
branch commits + NIGHTLY_REPORT.md
        |
        v
codex-fleet context bundle
        |
        v
ChatGPT Pro reviews and decides next tasks
```

## Chat roles

### EasyLife Product Lead

Use this for project direction and review only.

Responsibilities:
- review `fleet-brief.ps1` or EasyLife bundle output
- decide continue / revise / stop
- return small safe tasks for `docs/codex/TASK_QUEUE.md`
- protect product scope

Do not ask this chat to directly implement code.

### Restaurant Demo Lead

Use this for creative direction and sales-site review.

Responsibilities:
- review the site direction
- improve demo task ideas
- return small frontend-only tasks
- protect the no-backend/no-auth/no-payment scope

Do not ask this chat to add deployment, email sending, analytics, or real data unless you are ready for a manual review pass.

### Codex Local Worker

Use this for implementation through scripts.

Responsibilities:
- consume one unchecked task
- edit files
- review the diff
- let PowerShell run builds
- stop on guardrail/build failure

## Daily workflow

1. Check both projects:

```powershell
cd C:\Dev\codex-fleet
.\fleet-status.ps1
```

2. Generate context for ChatGPT Pro:

```powershell
.\make-context-bundles.ps1
```

3. Paste the relevant bundle into the matching ChatGPT Pro project.

4. Put ChatGPT Pro's returned tasks into the matching repo's `docs/codex/TASK_QUEUE.md`.

5. Run one project or the fleet:

```powershell
cd C:\Dev\easylifehq.github.io
powershell -ExecutionPolicy Bypass -File .\scripts\codex-night-loop.ps1 -Rounds 1
```

```powershell
cd C:\Dev\restaurant-automation-demo
powershell -ExecutionPolicy Bypass -File .\scripts\codex-night-loop.ps1 -Rounds 2
```

```powershell
cd C:\Dev\codex-fleet
.\run-fleet.ps1
```

6. Review commits before merging.

## What cannot be controlled directly

This setup does not directly control ChatGPT Pro browser chats or other Codex chats. That would require brittle UI automation.

Instead, the durable control surface is:
- markdown plans
- task queues
- guardrail scripts
- build output
- commits
- generated context bundles
