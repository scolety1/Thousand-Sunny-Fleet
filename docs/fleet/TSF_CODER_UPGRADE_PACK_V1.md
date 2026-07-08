# TSF Coder Upgrade Pack V1

Evidence only; not executable authority or approval.

## Purpose

TSF Coder Upgrade Pack V1 adds optional, local coding helpers for Tim's
multi-project Codex workflow. The pack helps Tim understand a repo quickly,
shape better Codex work orders, review risk before approval, learn from bugs,
split messy goals, and recover from stuck states without rebuilding context by
hand.

Repo onboarding uses the same discipline: source trace first, reusable assets
first, and no product-repo mutation until a review packet and exact approval
exist.

The tools are TSF-local generators. They read TSF registry/status files and
repo-local fixtures. They do not inspect product repos, mutate product repos,
push, deploy, install packages, run migrations, touch secrets, add remote
access, create browser command hooks, add executable UI controls, run all-fleet
commands, or start daemons.

## Outputs

- Repo X-Ray cards: `fleet/status/repo-xray/`
- Context packs: `fleet/status/context-packs/`
- Diff risk review: `fleet/status/diff-risk-review.md`
- Coding lessons journal: `fleet/status/coding-lessons/lessons-learned.md`
- Work-order splits: `fleet/status/work-order-splits/`
- Stuck-state playbooks: `fleet/status/stuck-playbooks/`
- Repo onboarding packets: `fleet/status/repo-onboarding/`

## Before Coding

1. Open Fleet Console.
2. Open Repo X-Ray for the project.
3. Open Context Pack.
4. For newly registered repos, open the Repo Onboarding Packet.
5. Copy one work order.

The Repo X-Ray explains what TSF knows about the project without opening the
product repo. The Context Pack keeps Codex from needing a giant pasted context
dump.

## During Coding

1. Use Spec-to-Work-Orders when the goal is messy.
2. Use Stuck-State Playbook when blocked.
3. Use Diff Risk Reviewer before commit or push approval.

The splitter should produce small, finishable tasks with acceptance criteria,
stop conditions, validation expectations, and a final report format. The
playbook keeps stuck states calm: identify the stuck type, try only safe local
checks, and ask Tim only when a real decision or forbidden action is required.

## After Coding

1. Add or update Bug Journal lesson.
2. Refresh Next Session Card.
3. Stop or continue with one bounded work order.

Lessons should stay short: problem, cause, fix, how to catch earlier, test/check
to add, and which projects/tools it applies to.

## Diff Risk Reviewer

Risk levels:

- `LOW`: docs, copy, tests, or fixtures only.
- `MEDIUM`: scripts, renderers, static console, or status generation.
- `HIGH`: core workflow, policy, guardrail, schema, or safety-boundary logic.
- `BLOCKED`: secrets, deploy, install, migration, remote access, push,
  product-repo mutation, archived reactivation, all-fleet, background daemon,
  or browser command hook risk.

`BLOCKED` means stop and repacketize before any commit approval.

## Regeneration

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-coder-upgrade-pack.ps1
```

Use project-specific wrappers when Tim wants one artifact:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-repo-xray.ps1 -ProjectName PrivateLens
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-context-packs.ps1 -ProjectName PrivateLens
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-work-order-splits.ps1 -ProjectName PrivateLens
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-stuck-playbooks.ps1 -ProjectName PrivateLens
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-diff-risk-review.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-coding-lessons.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-repo-onboarding-packet.ps1 -Repo C:\Dev\your-project -ProjectName YourProject -RequestedCapability "feature or workflow to trace" -OutDirectory .\fleet\status\repo-onboarding\your-project
```

These commands write TSF-local markdown/json-style evidence. They do not approve
runtime action.

## Guardrails

- TSF repo only.
- Do not inspect or mutate product repos.
- Do not reactivate archived projects.
- Do not push, deploy, install packages, run migrations, touch secrets, add
  remote access, add browser command hooks, add executable UI controls, run
  proof runs, run all-fleet commands, or start unbounded daemons.
- Generated prompts are optional copy/paste guidance only.
- Research, source-truth files, lessons, x-rays, risk reviews, playbooks, and
  splits are evidence, not authority.
