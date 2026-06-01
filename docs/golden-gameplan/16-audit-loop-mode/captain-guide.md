# Audit Loop Mode Captain Guide

Audit Loop Mode is an optional, captain-approved workflow for projects where an external review loop is useful. It is not the default Codex Fleet path, and it should not replace normal scope, safety, state, budget, build, test, or taste gates.

## Phone-Readable Decision Guide

Use Audit Loop Mode when:

- You have a compact project or feature slice that benefits from an outside audit.
- You can provide metadata that names the project, surfaces, safe files, forbidden files, checks, and `maxTasks`.
- You want an external report converted into a short queue of bounded tasks.
- You are willing to mark accepted limitations so the loop does not keep rediscovering the same caveats.

Skip Audit Loop Mode when:

- You just need a normal single Codex task.
- The project has no clear checks or evidence.
- The findings are mostly subjective taste questions.
- The task would touch real product repos, secrets, auth, payments, deploy, migrations, package files, or locks without explicit approval.
- The loop is starting to produce repeated caveats instead of new actionable work.

Next captain action:

```text
If audit findings are actionable, run one generated task at a time.
If findings are accepted limitations, stop the loop.
If findings require taste, use the normal taste gate.
If scope is unsafe, reject the queue.
```

## How The Loop Works

1. Prepare project metadata.
2. Build a compact audit package with declared files only.
3. Send the package and prompt to an external reviewer.
4. Convert structured findings into a bounded queue.
5. Run exactly one task.
6. Record proof and tests.
7. Repeat only while new actionable issues remain.

## What Stays Manual

- Choosing whether this mode fits the project.
- Approving high-risk or product-specific scope.
- Deciding whether a caveat is an accepted limitation.
- Making final taste calls.
- Committing, pushing, deploying, or launching real product work.

## Accepted Limitations

Accepted limitations are known caveats that should not keep regenerating tasks. Add them to the project metadata under `acceptedLimitations`. The queue converter skips findings that match those limitations and records them as skipped.

Examples:

- `Fixture intentionally omits live external transport.`
- `Demo uses synthetic restaurant data only.`
- `Mobile delivery is request-only until a later integration stage.`

Accepted limitations are not excuses for broken build, failed checks, unsafe scope, missing evidence, or product-quality failures. They only prevent repeated non-blocking caveats from creating loop churn.

## Return To Normal Fleet Controls

Return to normal Codex Fleet controls when:

- the audit queue is empty,
- remaining findings are accepted limitations,
- the next action needs product taste,
- the project needs broader planning,
- or the task belongs in Post-Golden Gameplan Hardening.

The safe return prompt is:

```text
Start the next unfinished task from the Post-Golden Gameplan Hardening queue in docs/codex/TASK_QUEUE.md.
```

## Safety Summary

Audit Loop Mode is optional. It is captain-approved. It handles accepted limitations explicitly. It does not launch ships, does not touch real product repos by default, and does not make external reviewers executors.
