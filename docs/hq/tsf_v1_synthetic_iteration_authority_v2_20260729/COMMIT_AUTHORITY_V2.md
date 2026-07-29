# Commit Authority V2

`SYNTHETIC_TASK_COMMIT_AUTHORITY_V2` exists only after syntax, focused tests,
acceptance tests, diff checks, and an independent verifier are GREEN. It binds
the registration, task, authorization, verifier, exact changed path, exact
subject, clean unrelated state, zero remotes, no push, no amend, expiry, and a
zero-use counter.

The canonical committer stages only the task source path, re-inspects the staged
path set, creates one local commit with the exact subject, verifies the new
40-hex commit, and requires a clean worktree. The receipt consumes the authority
exactly once. Repeated use, commit-before-tests, extra staged files, wrong
subject, amend, push, or remote presence is rejected.

This authority never permits publication, merge, or product changes.
