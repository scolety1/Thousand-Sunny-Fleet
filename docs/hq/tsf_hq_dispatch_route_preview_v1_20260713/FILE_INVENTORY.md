# Exact Milestone 1 File Inventory

The intended change contains exactly 20 new files. No pre-existing file is modified.

## Versioned contracts and registries

| Path | Purpose |
| --- | --- |
| `fleet/control/hq-dispatch/hq-dispatch-route-preview-request.schema.v1.json` | Closed request schema accepting only `natural_request`. |
| `fleet/control/hq-dispatch/hq-dispatch-route-preview-response.schema.v1.json` | Closed preview response and artifact schema, including route reasoning and explicit capability denials. |
| `fleet/control/hq-dispatch/hq-dispatch-skill-registry.schema.v1.json` | Versioned schema for the skill projection. |
| `fleet/control/hq-dispatch/hq-dispatch-skill-registry.v1.json` | Static map of 18 documented skills, distinguishing five local definitions and preserving source paths/hashes. |
| `fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.schema.v1.json` | Versioned schema for setup/action projections. |
| `fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.v1.json` | Projection of 71 service, console, and entrypoint actions; only route preview has `execution_enabled: true`. |

## Foreground server, wrapper, and browser shell

| Path | Purpose |
| --- | --- |
| `tools/hq-dispatch/v1/server.mjs` | Fixed loopback-only Node HTTP server, static registry projector, capability boundary validator, and sole child-process invocation site. |
| `tools/hq-dispatch/v1/Invoke-TsfHqDispatchRoutePreview.ps1` | Stdin-only, no-argument canonical route-preview wrapper with fixed sources, route reasoning, explicit capability denials, and fixed output root. |
| `tools/hq-dispatch/v1/public/index.html` | Operator shell with the exact preview-only banner, one Preview route control, route reasoning, and no-external-integrations boundary. |
| `tools/hq-dispatch/v1/public/styles.css` | Responsive local operator presentation. |
| `tools/hq-dispatch/v1/public/app.js` | Same-origin registry loading and fixed route-preview request rendering. |

## Validation

| Path | Purpose |
| --- | --- |
| `tests/test-tsf-hq-dispatch-route-preview-v1.mjs` | 114-assertion foreground endpoint, injection, source-parity, UI-control, same-origin/XSS-sink, no-request-persistence, route-reasoning, capability-denial, and mutation-snapshot suite. |
| `tests/run-tsf-hq-dispatch-route-preview-v1-tests.ps1` | 226-assertion schema, checksum, source-hash, plugin-free boundary, parser, protected-source, scope, and integration harness. |

## Audit packet

| Path | Purpose |
| --- | --- |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/READ_THIS_FIRST.md` | Milestone posture and operator entrypoint. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/FILE_INVENTORY.md` | This exact 20-file inventory. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/SOURCE_MAP.md` | Canonical and projection source trace. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/VALIDATION.md` | Human-readable executed test coverage. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/VALIDATION.json` | Machine-readable validation result. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md` | Limitations and explicit later-milestone exclusions. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/SHA256SUMS.txt` | SHA-256 hashes of canonical LF-normalized UTF-8 content for the other 19 intended files; the checksum file does not hash itself. |

## Scope exclusions

No mission, result, admission, lifecycle, recovery, producer, queue, approval-ledger, Project Main Bot runtime, plugin catalog/risk, model policy, worker-role registry, enforcement-kernel, app-server adapter, product, package, dependency, deployment, or unrelated repository file is modified.
