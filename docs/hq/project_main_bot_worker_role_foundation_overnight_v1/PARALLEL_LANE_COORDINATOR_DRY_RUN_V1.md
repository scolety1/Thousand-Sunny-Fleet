# Parallel Lane Coordinator Dry Run V1

This policy and checker are dry-run only. They may inspect a lane plan and report collision risk, but they must not create branches, create worktrees, spawn workers, merge, push, or start background processes.

The checker should fail closed on overlapping file ownership, missing lane names, missing branch names, unsafe worktree paths, protected paths, or requested execution side effects.
