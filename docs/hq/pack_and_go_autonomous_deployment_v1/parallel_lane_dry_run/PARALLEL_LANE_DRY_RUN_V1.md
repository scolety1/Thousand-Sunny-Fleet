# Parallel Lane Dry-Run V1

## Purpose

This packet defines true TSF lanes as isolated branch/worktree/Codex-agent plans. The checker remains dry-run only and does not create branches, create worktrees, spawn workers, push, or merge.

## True Lane Requirements

- each lane has a unique `lane_id`
- each lane has a unique `codex_agent_id`
- each lane has a unique `worktree_path`
- each lane has a dated `work/*` branch name
- file ownership must not collide
- protected worktree paths such as canonical NWR and product repos are blocked

## Tool

`tools/Test-TsfParallelLanePlan.ps1` now supports `require_true_lanes = true` plans.

## Result

The checker can validate safe lane plans and block collisions using fixtures only. It does not launch parallel workers.
