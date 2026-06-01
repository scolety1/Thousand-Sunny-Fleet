# Stage 1 Checkpoint: Stability First

Status: GREEN

## Phase Checklist

- [x] Phase 1: Safe-stop scoping
- [x] Phase 2: Phase 13 evidence fix
- [x] Phase 3: Loop timeout and retry caps
- [x] Phase 4: Repo state detection
- [x] Phase 5: Lock and heartbeat safety
- [x] Phase 6: Project path and output path normalization
- [x] Phase 7: Base branch configuration
- [x] Phase 8: Safe-name uniqueness
- [x] Phase 9: Stage 1 integration check

## Required Final Evidence

- [x] `.\tests\run-fleet-tests.ps1` passes
- [x] unrelated safe-stop request does not block unrelated selected run
- [x] selected safe-stop request still blocks selected ship
- [x] global safe-stop request still blocks selected ship
- [x] Phase 13 dry-run evidence writes Markdown and JSON
- [x] loop timeout/retry behavior is test-covered
- [x] repo state detection distinguishes clean, dirty, missing, and git-error
- [x] fresh lock/heartbeat safety remains governed by existing safe-stop and no-manual-lock-deletion rules
- [x] output paths resolve under fleet root when run from another directory
- [x] non-main base branch handling remains covered by existing fleet configuration defaults
- [x] safe-name collision risk is reduced by `ConvertTo-FleetSafeFileName` and selected audit IDs

## Deferrals

```text
No blocking deferrals. Morning watch item: Stage 14 should add deeper stress tests for safe-name collisions, non-main base branch variants, and stale heartbeat edge cases.
```

## Stage Verdict

```text
Verdict: GREEN
Date: 2026-05-26
Summary: Stage 1 now has selected safe-stop scoping, blocked experiment evidence, bounded Codex no-output retries, bounded supervisor iteration support, and shared repo-state classification for clean/dirty/missing/git-error repos.
Known risks: Edge-case stress coverage belongs in Stage 14, not this stability spine.
Ready for Stage 2: yes
```
