# TSF Push Approval Packet

Prepared: 2026-07-02

Draft only; not push approval. Do not push from this packet unless Tim sends exact approval after final checks.

## Purpose

This packet gives Tim a clean prompt to publish the current TSF local stack after
final verification. It must verify the current HEAD dynamically and must not
treat any stale hash in this file as truth.

## Copyable Push Prompt

```text
Explicit approval: push current clean TSF main to origin/main.

Repo:
C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet

Task:
1. Verify current branch is main.
2. Verify git status --short is clean.
3. Verify current local HEAD dynamically with git rev-parse HEAD.
4. Verify origin/main dynamically with git rev-parse --verify origin/main.
5. Verify local main is ahead of origin/main by the expected commit count and behind 0.
6. Run:
   - git log --oneline -8
   - git diff --check origin/main..HEAD
   - powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
7. If GREEN and working tree is clean, push:
   - git push origin main
8. After push, run:
   - git status --short
   - git rev-parse HEAD
   - git rev-parse --verify origin/main
   - git rev-list --left-right --count origin/main...HEAD
   - git log --oneline -5

Stop if:
- branch is not main
- worktree is dirty
- behind is not 0
- diff check fails
- tests fail
- push would require force, rebase, merge, or conflict resolution

Final report:
- verdict
- push result
- local HEAD
- remote HEAD
- final git status
- tests run
- commits published
- confirmation no product repos, PrivateLens, deploy, install, migration, secrets/auth/payments, proof-run, all-fleet, background, external-account, spending, or archived reactivation work occurred
```

## Non-Authority Reminder

This draft does not push. It does not approve push. It is a prompt Tim may use
only when he wants to grant exact push approval.
