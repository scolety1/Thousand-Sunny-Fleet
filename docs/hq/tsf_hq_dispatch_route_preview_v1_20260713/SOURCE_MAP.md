# Canonical Source and Projection Map

All paths and hashes below were read from the verified `origin/main` worktree basis at `7fe9c176177d5d2c613238d375fdb45e6fe783dc`.

## Route preview authority sources

| Source | SHA-256 | Used for | Boundary |
| --- | --- | --- | --- |
| `tools/New-TsfProjectMainBotMissionDraft.ps1` | `c6ef508177bcb57ee265e332c7fc19460a9e3f9b01aa6289c910fa306a28ba23` | Canonical request classification, fixed TSF project/lane packet projection, default worker-role proposal, reads/writes, forbidden actions, and stop conditions. | Invoked without `-OutFile`; no mission or queue record is created. |
| `tools/TsfDurableContract.Canonical.ps1` | `8a0fc9f9e95a43398e557c9dbd3a236e753a03d52baf8206715aa0bd4cf90540` | Existing `Resolve-TsfModelRouting` implementation and JSON contract validator. | Dot-sourced for functions only; no lifecycle, admission, result, recovery, or queue function is called. |
| `fleet/control/worker-role-registry.v1.json` | `81515eea94924b1fac9ba2df099def5d702226744d43fba54a62b636d871cad0` | Exact role name and purpose for the canonical default role ID. | Read-only; no permission or worker handoff occurs. |
| `fleet/control/model-routing-alias-policy.v1.json` | `d5765d66806e2cfee74aaf3bc61038774e875a6b3626b43eda8bc4fb4d0a69cb` | Legacy `standard_patch` to stable `BALANCED` resolution, model, effort, and `RECOMMENDED_ONLY` assurance. | Read by the canonical resolver; Node contains no model-routing logic. |

The wrapper hashes all four sources at preview time and emits them with `freshness: READ_AT_PREVIEW_TIME`.

## Skill projection sources

| Source | SHA-256 | Projection |
| --- | --- | --- |
| `docs/codex/FLEET_SKILL_MAP.md` | `aaec924be7dfac72e56e674f3901b3604f3d906cbe7e387123fa6e0bbdf552f6` | 18 documented skill IDs and phase/default mappings. |
| `skills/code-review-and-quality.md` | `136dd2d0c38095ced7ff6733ac273a6f0b235f9e023c335c2999f33505a8122d` | Local definition presence. |
| `skills/frontend-ui-engineering.md` | `52f94514b8eb2faae36033f35c96e045bb44cce347c2d7f0d9e2c32c53219200` | Local definition presence. |
| `skills/incremental-implementation.md` | `75b13510495b4407fac1e99293b20a0cbd2f86ef8c840e9d38f12d89edc86729` | Local definition presence. |
| `skills/planning-and-task-breakdown.md` | `0fe3232d331afb364ff080c86eba7c85217a85632625de2b9834ee7541aa9406` | Local definition presence. |
| `skills/shipping-and-launch.md` | `4da8a9b324501a397b4a8d741697b6b5498359cfb9f1e3abfcf239813f0c28b2` | Local definition presence. |

The API compares each stored source hash with the current hardcoded in-repository file. A mismatch is displayed as `SOURCE_HASH_MISMATCH`; no arbitrary registry path is resolved.

## Setup/action projection sources

| Source | SHA-256 | Projection |
| --- | --- | --- |
| `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md` | `1d409f1aa331b4db37249ef67b3ae5bab21f903cc30b00242f470dd7defdd0ef` | All 31 inventoried entrypoints and their existing safety classes. |
| `docs/fleet/ui/FLEET_CONSOLE_STATUS_AND_ACTION_MODEL.md` | `06eb1e976e24b375f4abbfd124f0853800931c514b09ce44491727567d5a121a` | Existing action-class and non-authority posture. |
| `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md` | `5064b0fecc20ca0faa926b04575d05b28d45d919787092c3b5847fe0b623ec22` | All 37 documented console actions and classes. |

The registry also declares the three service operations. Health and registry reads are available but `execution_enabled: false`; route preview is the sole `execution_enabled: true` action. Every action records class, source path/locator, availability, human gate, authority boundary, and execution state.

## Static plugin-reference sources

| Source | SHA-256 | Boundary |
| --- | --- | --- |
| `fleet/reference/plugin-catalog-risk-v1/plugin-catalog.v1.json` | `53068162e312a33f63303ecbae590a5e1d1e3417ba38a314ca2cf4040a190632` | Existing 36-record static catalog, projected unchanged. |
| `fleet/reference/plugin-catalog-risk-v1/plugin-packs-reference.v1.json` | `b254b1e4e63ac4cc0dcbb91708d4158828e5f39991fe908adf336285871b0a7a` | Existing reference packs; `runtime_resolver_input: false`. |
| `fleet/reference/plugin-catalog-risk-v1/plugin-review-priority.v1.json` | `e2c9080bf242f8e995940d51b5d0062ad4719a372a8b9b42c4ad89582206509b` | Existing non-authorizing review order. |
| `fleet/reference/plugin-catalog-risk-v1/plugin-risk-policy.v1.json` | `69c049451001cefc35991e2f9744f4064e62f75f7a9902596b8533fa0e81a4fe` | Existing `runtime_enforced: false` policy. |

The UI displays `REVIEW_ONLY_REFERENCE_NOT_RUNTIME_ENFORCED`. The server reads these four fixed repository files only. It does not load plugin code, inspect installed or enabled plugins, connect or authenticate, probe capabilities, resolve a plugin, or use the reference packs as runtime input.

## Node / PowerShell division

Node owns only fixed HTTP routing, static-file delivery, closed request-envelope checks, hardcoded source loading, hash comparison, and one `spawn` call to the fixed wrapper. PowerShell owns canonical classification and model resolution by calling the existing sources above. No role-classification, model-routing, approval, admission, or mission-schema logic is reproduced in JavaScript.
