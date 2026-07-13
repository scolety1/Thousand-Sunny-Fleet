# Executed Validation Coverage

Validation date: 2026-07-13

Repository basis: `origin/main = 7fe9c176177d5d2c613238d375fdb45e6fe783dc`

Branch: `work/tsf-hq-dispatch-route-preview-v1-20260713`

## Starting-point proof

- Read-only `git ls-remote origin refs/heads/main`: PASS.
- Required commit is the exact remotely observed `origin/main` head.
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
TSF_HQ_DISPATCH_VALIDATION_PASS assertions=226 actions=71 enabled_actions=1 external_integrations=disabled
```

Coverage:

- all six new JSON schemas/registries parse;
- all 19 non-manifest packet hashes match `SHA256SUMS.txt` after canonical LF normalization, so Windows checkout line-ending policy cannot invalidate the packet;
- request, skill, and setup/action schema validation;
- unknown request property rejection;
- 18 documented skills and five local definitions;
- current hashes for all skill and setup/action sources;
- all 71 actions declare class, source, availability, human gate, and authority boundary;
- route preview is the only action with `execution_enabled: true`;
- the server reads and projects no plugin registry and exposes fixed false-valued plugin access/projection fields;
- nine protected canonical/runtime files have the same Git blob as `origin/main`;
- Node and PowerShell syntax/parser checks;
- exactly one Node child-process invocation site, fixed to the wrapper;
- no wildcard listener, environment override, lifecycle, admission, queue, approval-ledger, or app-server invocation;
- fixed Milestone 1 restriction projection with plugin access/registry projection, credentials, live AI, external repositories, mission submission, and mission execution disabled;
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
NODE_INTEGRATION_PASS assertions=114
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
- route reasoning explains the classification, proposed role, model/effort resolution, and authority boundary;
- all projected registry hashes are current;
- no plugin object or plugin source appears in the registry response or browser UI, and the implementation contains no plugin-catalog path;
- health, registry, and preview responses explicitly deny credential access, live AI service access, plugin access, external repository access, mission submission, and mission execution;
- natural request text is used for in-memory classification but is neither echoed nor persisted in preview artifacts;
- browser HTML exposes exactly one button, Preview route, and none of the prohibited control labels;
- before/after snapshots prove no file changed under `fleet/missions`, `fleet/state`, or `.codex-local` outside the fixed preview root.

## Existing Project Main Bot regression

Command:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-project-main-bot-role-foundation-tests.ps1
```

Result: PASS — `Project Main Bot role foundation tests passed.`

This regression revalidated all 18 canonical role records/templates, permission profiles, mission-draft classifications, protected-path denial, unknown-role fail-closed behavior, translator/HQ fixtures, and parallel-lane collision behavior.

## Existing kernel and durable-contract regressions

Commands:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-minimum-viable-kernel-tests.ps1
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-tsf-durable-contract-tests.ps1 -EvidenceRoot .codex-local\hq-dispatch\final\durable-contract
```

Results:

- Minimum Viable TSF Kernel: PASS.
- Durable canonical contract: PASS, 33 assertions.

These regressions confirm the preview additions did not weaken mission preflight, verifier/preservation behavior, canonical durable contracts, result/admission schemas, or fail-closed approval handling.

## Plugin-free and external-integration boundary

Plugin registries and plugin runtime state are outside Milestone 1. The focused harness does not read plugin source files. It proves the server contains no plugin-catalog path, the registry response contains no plugin object or plugin source, the browser exposes no plugin-reference card, and `plugin_access_enabled` plus `plugin_registry_projected` remain fixed to `false`.

## Operation absence proof

No persistent server, background job, worker, app-server, lifecycle, admission, queue executor, approval mutation, plugin runtime operation, credential operation, external connection, external-repository inspection, mission submission, or mission execution was started. All server tests created and closed one ephemeral loopback listener inside the foreground test process. The only child process used by the surface was the bounded route-preview wrapper, and each invocation completed before the request returned.
