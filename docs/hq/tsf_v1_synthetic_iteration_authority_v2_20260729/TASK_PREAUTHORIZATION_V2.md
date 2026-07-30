# Task Preauthorization V2

Each `SYNTHETIC_TASK_PREAUTHORIZATION_V2` is derived only from the static
authority and the observed clean predecessor commit. It includes the exact
goal, repository, branch, source and test paths, command templates, focused and
acceptance tests, acceptance criteria, three-attempt limit, required commit
subject, expiry, and advance-reviewed authorization provenance.

`PREAUTHORIZED_TASK_BINDING_V2` re-derives and byte-compares that template. The
binding explicitly records that no mission, path, command, test, acceptance, or
iteration authority was added or weakened. Caller-supplied approval fields,
cross-task bindings, changed goals, added paths, removed tests, changed commands,
different repositories or branches, increased limits, and changed subjects fail
with `TIM_REQUIRED` before a Builder is launched.

Baseline chaining is strict:

1. Task 1: setup commit.
2. Task 2: accepted Task 1 commit.
3. Task 3: accepted Task 2 commit.
