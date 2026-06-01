# Golden Gameplan Safety Rules

These rules apply to every Golden Gameplan phase and override individual phase
wording if there is a conflict.

## Hard Stops

Stop instead of acting when:

- the selected ship scope is missing or ambiguous
- a command would default to all ships
- the repo is dirty and ownership is unknown
- a lock, safe-stop file, or active PID is ambiguous
- deterministic build/test/runtime evidence is missing
- a task packet is stale, invalid, duplicated, or unvalidated
- a request touches secrets, auth, payments, deployment, migrations, package
  files, production data, or external API contracts without an explicit
  high-risk approval path
- remaining work is subjective taste rather than deterministic implementation
- model/rate budget is unknown and the requested action is model-heavy

## Never Automatic

The fleet must not automatically:

- merge, push, deploy, publish, or create pull requests
- delete user work or clean downstream repos
- manually delete locks or stop requests
- kill active processes outside an existing approved safe-stop process
- broaden scope from selected ships to all ships
- bypass Stage 4 task packet validation
- fabricate exact rate-limit percentages or reset times
- treat a parked ship as finished without evidence

## Safe Defaults

When in doubt, the default action is:

```text
WRITE_STATUS_REPORT
```

The report should explain:

- what was requested
- what evidence was available
- why the fleet did not act
- the safest next command the captain can approve

## Failure Classification Rule

During an unattended Golden Gameplan run, do not treat every failing assertion as
proof that the current phase failed. Classify failures before deciding whether to
continue:

- `phase-owned`: caused by files or behavior changed in the current phase
- `foundation-owned`: a nearby stability blocker that prevents the current phase
  from being trusted
- `unrelated-known`: an existing failure outside the current phase scope
- `unsafe`: any failure that could touch user work, broaden scope, lose evidence,
  or bypass a guardrail

Stop immediately for `phase-owned`, `foundation-owned`, or `unsafe` failures.
For `unrelated-known` failures, write the blocker clearly. If the current phase
acceptance tests pass and the stage plan allows continuing, the runner may
continue inside the same approved stage range instead of stalling forever.

## Fixture Rule

Stress tests, failure injection, rollback checks, and destructive reset tests
must use disposable fixtures unless the captain explicitly names a real repo and
approves the exact scope.

## Remote Command Rule

Mobile or remote commands are not execution authority by themselves. They create
requests that must pass local state, budget, scope, and safety validation before
any action happens.
