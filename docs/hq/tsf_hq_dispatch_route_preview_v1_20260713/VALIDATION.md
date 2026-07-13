# Executed Validation Coverage

Validation date: 2026-07-13

Repository basis: `origin/main = 7fe9c176177d5d2c613238d375fdb45e6fe783dc`

Branch: `work/tsf-hq-dispatch-route-preview-v1-20260713`

## Starting-point proof

- Read-only `git fetch --prune origin main`: PASS.
- Required commit is an ancestor of `origin/main`: PASS; it is the exact fetched head.
- Canonical worktree clean before branch/worktree creation: PASS.
- Conflicting HQ Dispatch implementation scan at `origin/main`: PASS; only historical deferral text existed.
- Requested branch and worktree path were unused before creation: PASS.

## Focused Milestone 1 harness

Command:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-tsf-hq-dispatch-route-preview-v1-tests.ps1
```

Result:

```text
TSF_HQ_DISPATCH_VALIDATION_PASS assertions=216 actions=71 enabled_actions=1 plugin_runtime_observations=0
```

Coverage:

- all six new JSON schemas/registries parse;
- request, skill, and setup/action schema validation;
- unknown request property rejection;
- 18 documented skills and five local definitions;
- current hashes for all skill and setup/action sources;
- all 71 actions declare class, source, availability, human gate, and authority boundary;
- route preview is the only action with `execution_enabled: true`;
- static plugin reference stays at 36 entries, zero runtime observations, no authority grants, no resolver input, and no runtime enforcement;
- 13 protected canonical/runtime/plugin files have the same Git blob as `origin/main`;
- Node and PowerShell syntax/parser checks;
- exactly one Node child-process invocation site, fixed to the wrapper;
- no wildcard listener, environment override, lifecycle, admission, queue, approval-ledger, or app-server invocation;
- response artifact schema validation and explicit non-mission/non-queue identity;
- intended path-scope and forbidden-file-change checks;
- `git diff --check origin/main --`.

## Foreground endpoint and injection suite

Command:

```powershell
node .\tests\test-tsf-hq-dispatch-route-preview-v1.mjs
```

Result:

```text
NODE_INTEGRATION_PASS assertions=92
```

Coverage:

- listener address is exactly `127.0.0.1`;
- no cross-origin grant and same-origin browser security headers;
- all three versioned operations and the static UI;
- malformed JSON, arrays, missing/blank inputs, wrong media type, request-size overflow, query fields, GET bodies, wrong methods, unknown operations, and encoded path traversal;
- caller fields named `command`, `executable`, `script`, `path`, `environment`, `queue_root`, `output_root`, `runtime_arguments`, `host`, and `port` all reject as `UNKNOWN_FIELD`;
- server and wrapper runtime arguments reject before startup/preview;
- command-like natural language remains inert data and receives the canonical `NEEDS_TIM_APPROVAL` classification;
- a command-injection marker is not created;
- default worker role name/purpose match the current worker registry;
- stable alias, product resolution, effort, and assurance match the current canonical model policy;
- all projected registry hashes are current;
- plugin runtime inspection/code loading/capability observation remain false;
- browser HTML exposes exactly one button, Preview route, and none of the prohibited control labels;
- before/after snapshots prove no file changed under `fleet/missions`, `fleet/state`, or `.codex-local` outside the fixed preview root.

## Existing Project Main Bot regression

Command:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-project-main-bot-role-foundation-tests.ps1
```

Result: PASS — `Project Main Bot role foundation tests passed.`

This regression revalidated all 18 canonical role records/templates, permission profiles, mission-draft classifications, protected-path denial, unknown-role fail-closed behavior, translator/HQ fixtures, and parallel-lane collision behavior.

## Static plugin-reference regression handling

The pre-existing `run-tsf-plugin-catalog-risk-v1-static-validation.ps1` is intentionally scope-locked to the earlier plugin milestone and asserts that exactly its 17 plugin files are the only branch changes. Running it on a later milestone would produce a known false scope failure.

The focused harness therefore re-executes the relevant catalog, pack, review-priority, risk-policy, authority, and runtime-observation assertions and also proves all four plugin files retain their exact `origin/main` Git blobs. All focused plugin regression assertions passed.

## Operation absence proof

No persistent server, background job, worker, app-server, lifecycle, admission, queue executor, approval mutation, plugin operation, credential operation, external connection, mission submission, or mission execution was started. All server tests created and closed one ephemeral loopback listener inside the foreground test process. The only child process used by the surface was the bounded route-preview wrapper, and each invocation completed before the request returned.
