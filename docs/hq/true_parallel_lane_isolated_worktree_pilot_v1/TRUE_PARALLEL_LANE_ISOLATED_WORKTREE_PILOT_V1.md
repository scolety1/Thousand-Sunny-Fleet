# True Parallel Lane Isolated Worktree Pilot V1

This packet defines the first TSF real lane-isolation pilot. It extends the existing Project Main Bot / Parallel Lane Coordinator dry-run foundation instead of creating a second orchestration system.

The pilot remains foreground-only and sequential. It may create two local worktrees and run at most two fixture-only Codex workers, one per lane. It must not push, merge, create PRs, call APIs, start background runners, mutate product repos, mutate canonical NWR, read normal NWR packets, or use broad parallel worker execution.

## Lanes

- Lane A: Builder Worker on `work/parallel-lane-pilot-builder-v1-20260709`.
- Lane B: Auditor Worker on `work/parallel-lane-pilot-auditor-v1-20260709`.

Each lane owns exactly one fixture artifact under `tests/fixtures/fleet/parallel-lanes/worker-output/`.

## Execution Contract

The coordinator creates and validates a lane plan, allocates isolated local worktrees, runs each lane sequentially, verifies the expected fixture artifact, preserves lane evidence, collects reports back on the coordinator branch, and stops before any merge.

## Caveat

This is not a background worker swarm. It proves local branch/worktree isolation and evidence collection only.
