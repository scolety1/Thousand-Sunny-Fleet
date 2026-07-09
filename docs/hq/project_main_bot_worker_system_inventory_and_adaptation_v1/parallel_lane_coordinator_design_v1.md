# Parallel Lane Coordinator Design V1

## Purpose

The Parallel Lane Coordinator prevents multiple workers or lanes from colliding. It is a planning and validation role, not a runner.

No parallel runner, persistent process, worktree creation, merge, push, or background coordination is implemented by this design.

## Branch And Worktree Strategy

Default rule:

- one lane maps to one branch
- one worker mission maps to one bounded allowed-write set
- product repo lanes require exact Tim approval before read or mutation
- worktree creation or deletion requires exact approval

The coordinator may inspect local branch/status metadata and existing worktree boundary records. It may not create or delete worktrees in this lane.

## Lane Naming

Use names that encode:

- project or control-plane area
- lane purpose
- date
- bounded version if needed

Examples:

- `work/project-main-bot-worker-system-adaptation-20260709`
- `work/<project>-source-trace-v1-YYYYMMDD`
- `work/<project>-bounded-builder-v1-YYYYMMDD`

## Collision Detection

Before assigning workers, compare:

- mission allowed writes
- current dirty files
- recent lane files
- worktree boundary records
- protected paths
- review-only vs authority surfaces

Collision states:

- `NO_COLLISION`
- `SAME_LANE_OK`
- `ADAPTER_NEEDED`
- `SEQUENCE_REQUIRED`
- `TIM_REQUIRED_SCOPE_EXPANSION`
- `BLOCKED_CONFLICT`

## File Ownership

Each mission packet should name:

- owned files
- read-only evidence files
- forbidden files
- shared files that require sequencing
- preservation path

Shared files default to `SEQUENCE_REQUIRED` unless file-level patching is safe and verified.

## Worker Isolation

Workers should not route themselves. The Project Main Bot and Parallel Lane Coordinator decide assignment, then the TSF kernel enforces the packet.

Each worker receives:

- one mission
- one role
- one allowed write set
- one verifier contract
- one preservation requirement

## Checkpoint Timing

Checkpoint locally when:

- the lane has a coherent TSF-local docs/control-plane batch
- validation passes
- staged files are exact
- no restricted gate is crossed

Do not checkpoint when:

- dirty files are ambiguous
- worker output is incomplete
- validation failed
- the branch contains mixed unrelated lanes
- a push/merge would be implied

## Merge Recommendation Rules

The coordinator can recommend merge order, but cannot merge.

Recommend merge only when:

- dependency order is clear
- validation evidence exists
- changed-file scope matches the lane
- downstream lanes will benefit from the baseline

Hold merge when:

- stacked diffs hide scope
- current branch lacks needed predecessor commits
- protected paths are unclear
- Tim approval is missing

## Stop Conditions

Stop if coordination requires:

- creating or deleting worktrees
- product repo access
- canonical NWR inspection or mutation
- normal NWR packet reads
- push, merge, rebase, cherry-pick, force push, or branch deletion
- background or persistent runner
- all-fleet command
- install, deploy, migration, secrets, PrivateLens, or proof run

## Next Build Candidate

The safe next implementation would be a lane-collision validator that reads mission packets and git status, then writes a collision matrix. It should not create worktrees or run workers.
