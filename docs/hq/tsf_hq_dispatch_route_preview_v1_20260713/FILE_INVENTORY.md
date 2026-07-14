# Exact Milestone 1 File Inventory

The intended change contains exactly 20 new files. No pre-existing file is modified.

## Versioned contracts and registries

| Path | Purpose |
| --- | --- |
| `fleet/control/hq-dispatch/hq-dispatch-route-preview-request.schema.v1.json` | Closed request schema accepting only `natural_request`. |
| `fleet/control/hq-dispatch/hq-dispatch-route-preview-response.schema.v1.json` | Closed preview response, explicit access proposal, 12-section source-bound explanation, artifact contract, and capability denials. |
| `fleet/control/hq-dispatch/hq-dispatch-skill-registry.schema.v1.json` | Versioned schema for the skill projection. |
| `fleet/control/hq-dispatch/hq-dispatch-skill-registry.v1.json` | Static map of 18 documented skills, distinguishing five local definitions and preserving source paths/hashes. |
| `fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.schema.v1.json` | Versioned schema for setup/action projections. |
| `fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.v1.json` | Projection of 71 service, console, and entrypoint actions; only route preview has `execution_enabled: true`. |

## Foreground server, wrapper, and browser shell

| Path | Purpose |
| --- | --- |
| `tools/hq-dispatch/v1/server.mjs` | Fixed loopback-only Node HTTP server, static registry projector, capability boundary validator, and sole child-process invocation site. |
| `tools/hq-dispatch/v1/Invoke-TsfHqDispatchRoutePreview.ps1` | Stdin-only fixed wrapper with canonical result bindings, recommendation-only access proposal, bounded explanation formatting, and exclusive create-new artifact persistence. |
| `tools/hq-dispatch/v1/public/index.html` | Operator shell with the non-dismissible banner, one Preview route control, explicit access proposal, source/reason details, and retention disclosure. |
| `tools/hq-dispatch/v1/public/styles.css` | Responsive presentation for the four-stage route and source-binding detail ledger. |
| `tools/hq-dispatch/v1/public/app.js` | Same-origin registry loading and safe text-only rendering of all explanation/access/source sections. |

## Validation

| Path | Purpose |
| --- | --- |
| `tests/test-tsf-hq-dispatch-route-preview-v1.mjs` | 188-assertion endpoint, browser-contract, source-binding, access, CRLF/newline, shell-text, persistence, plugin-free, and mutation-snapshot suite. |
| `tests/run-tsf-hq-dispatch-route-preview-v1-tests.ps1` | Focused schema-negative, semantic-binding, collision, cleanup, checksum, parser, plugin-baseline, protected-source, scope, and integration harness. |

## Audit packet

| Path | Purpose |
| --- | --- |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/READ_THIS_FIRST.md` | Milestone posture and operator entrypoint. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/FILE_INVENTORY.md` | This exact 20-file inventory. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/SOURCE_MAP.md` | Canonical and projection source trace. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/VALIDATION.md` | Human-readable commands, times, exits, assertion counts, result hashes, and legacy cleanup evidence without request contents. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/VALIDATION.json` | Machine-readable suite, staged-tree, source-binding, cleanup, and operation-absence evidence. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md` | Limitations and explicit later-milestone exclusions. |
| `docs/hq/tsf_hq_dispatch_route_preview_v1_20260713/SHA256SUMS.txt` | SHA-256 hashes of canonical LF-normalized UTF-8 content for the other 19 intended files; the checksum file does not hash itself. |

## Scope exclusions

No mission, result, admission, lifecycle, recovery, producer, queue, approval-ledger, Project Main Bot runtime, plugin catalog/risk, model policy, worker-role registry, enforcement-kernel, app-server adapter, product, package, dependency, deployment, or unrelated repository file is modified.
