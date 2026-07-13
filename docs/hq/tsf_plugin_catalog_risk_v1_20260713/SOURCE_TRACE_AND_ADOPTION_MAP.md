# Source Trace and Adoption Map

## Gate evidence

- Known foundation: `5e90c9d52e23c50092965dbca01176725fb0970f`.
- Fetched `origin/main`: `5e90c9d52e23c50092965dbca01176725fb0970f`.
- Parked research branch: `work/plugin-discovery-capability-selection-v1-20260711`.
- Parked HEAD inspected read-only: `cd104765b8ab04275f7c77ed9614d484293ac650`.
- The parked branch is not canonical and must not be used as runtime authority.
- User directive dated 2026-07-13 is the controlling source for the reduced scope and decisive audit disposition.

No item was adopted without a source and disposition. No directory or commit was copied. Safe items were independently reconstructed into the isolated reference format and revalidated.

## Item-level adoption map

| Possible item | Exact traced source | Source object | Disposition | V1 treatment |
|---|---|---:|---|---|
| 36 plugin IDs and display names | `fleet/control/plugin-catalog.v1.json`; `INSTALLED_AVAILABLE_QUARANTINE_MATRIX.csv`; user directive | blobs `d7c86ccd41e8521062cb9f561f9ccec15c54e810`, `7aa4be8c13c498193cb8d6bbdf2807fe6ce00bab` | SAFE_STATIC_CATALOG | Independently reconstructed as unverified seed records. |
| Reported 8 AVAILABLE / NOT_INSTALLED and 28 DISCOVERED / UNKNOWN states | same catalog and matrix; user directive | same blobs | SAFE_STATIC_CATALOG | Preserved as reported states only, never host observations. |
| Alpaca plus five opaque IDs | same catalog and matrix; user directive | same blobs | SAFE_STATIC_CATALOG | Six records quarantined pending identity. |
| Unknown publisher, version, manifest, permission, auth, connection, network, host, enablement, and probe facts | parked catalog/schema; user directive | blobs `d7c86ccd41e8521062cb9f561f9ccec15c54e810`, `dacd8cd95452d3dc3bc1c11352ffdb106265a767` | SAFE_STATIC_CATALOG | Preserved as `null` or `UNKNOWN`; never guessed. |
| `USER_SUPPLIED_UNVERIFIED` confidence | parked catalog/schema and matrix; user directive | same catalog/schema/matrix blobs | SAFE_STATIC_CATALOG | Required on every record as source quality and confidence. |
| Candidate classification vocabulary | parked registry schema, `PLUGIN_CATALOG.md`, user directive | blobs `dacd8cd95452d3dc3bc1c11352ffdb106265a767`, `eaea21a03bb3f2b6fdf02ca985739ab899f27892` | SAFE_STATIC_CLASSIFICATION | Reconstructed with `*_CANDIDATE` names where operational necessity is unproven. |
| Likely capability category labels | parked catalog | blob `d7c86ccd41e8521062cb9f561f9ccec15c54e810` | SAFE_STATIC_CLASSIFICATION | Retained only as likely static review labels. |
| `BROWSER_CONTROL` and `ARTIFACT_DESIGN` overlap labels | parked catalog | blob `d7c86ccd41e8521062cb9f561f9ccec15c54e810` | SAFE_STATIC_CLASSIFICATION | Retained as manual overlap-review hints. |
| Five pack IDs and static member pools | parked `plugin-packs.v1.json`, `PLUGIN_PACKS.md`, user directive | blobs `7192757a90e6f36042cd00e336cf140a3005f097`, `957efedf6537e9217fc5097c4ed558a771587af2` | SAFE_STATIC_PACK_METADATA | Rebuilt with all auto/runtime/approval flags false. Sensitive pool includes Google Drive only for connected-account review per user directive. |
| Initial review order 1–10 | parked `PLUGIN_CATALOG.md`; user directive | blob `eaea21a03bb3f2b6fdf02ca985739ab899f27892` | SAFE_DOCUMENTATION | Used only as manual metadata-investigation order. |
| Static authority denials | parked `PLUGIN_AUTHORITY_BOUNDARY.md`; user directive | blob `dc8d4be248d701b6aaec98d479d77580e4c1ff69` | SAFE_DOCUMENTATION | Narrowed to descriptive, non-authoritative statements. |
| Descriptive state/risk distinctions | parked `PLUGIN_RISK_POLICY.md`; user directive | blob `2680fad18db9f6b3cd0aadaf41cfc40f3a8639b7` | SAFE_DOCUMENTATION | Retained only as human review cautions; runtime eligibility rules rejected. |
| Ten risk consideration areas and fail-closed phrase | user directive | request text | SAFE_DOCUMENTATION | Recorded in static policy with no matcher or enforcement. |
| Decisive audit blockers and parked disposition | user directive; parked `AUDIT_FINDING_DISPOSITION.md` for historical trace | request text; blob `b7ef51e66897ae1c629f0e2f355ea6d53d0d19a3` | SAFE_DOCUMENTATION | Recorded as reasons to exclude runtime work, not as defects to repair. |
| `tools/TsfPluginCapability.ps1` selection and eligibility logic | parked path | parked commit tree | UNSAFE_RUNTIME_RESOLVER | Rejected; no logic imported. |
| `tools/Resolve-TsfMissionPlugins.ps1` | parked path | parked commit tree | UNSAFE_RUNTIME_RESOLVER | Rejected; file not copied or recreated. |
| Exact branch-and-bound set cover and selection limits | parked capability tool and `plugin-selection-limits.v1.json` | blob `90f85f790787d49484e75ef83a4559cbd5ecf299` plus parked tool | UNSAFE_RUNTIME_RESOLVER | Rejected; not needed for human reference. |
| `tools/TsfPluginEvidenceBinding.ps1` | parked path | parked commit tree | UNSAFE_RUNTIME_EVIDENCE | Rejected; no evidence-binding system imported. |
| Plugin capability observation schema | `fleet/control/plugin-capability-observation.schema.v1.json` | parked commit tree | UNSAFE_RUNTIME_EVIDENCE | Rejected; catalog has an empty non-runtime observation array only. |
| Native capability evidence schema and native observation authority | `fleet/control/native-capability-evidence.schema.v1.json`; `NATIVE_CAPABILITY_EVIDENCE.md` | parked commit tree | UNSAFE_RUNTIME_EVIDENCE | Rejected. |
| Producer evidence registry changes | `fleet/control/producer-evidence-registry.schema.v1.json` and related evidence docs | parked diff | UNSAFE_RUNTIME_EVIDENCE | Rejected. |
| Mission and result plugin evidence fields | `mission-envelope.schema.v1.json`, `result-envelope.schema.v1.json` | parked diff | UNSAFE_ADMISSION_INTEGRATION | Rejected; runtime schemas untouched. |
| Canonical admission and durable contract changes | `tools/TsfDurableContract.Canonical.ps1`, `tools/TsfDurableContract.psm1` | parked diff | UNSAFE_ADMISSION_INTEGRATION | Rejected; no admission integration. |
| Enforcement-kernel plugin policy changes | `tools/codex-fleet-enforcement-kernel.ps1`, policy manifest | parked diff | UNSAFE_ADMISSION_INTEGRATION | Rejected. |
| Approval ledger schema and approval-runtime integration | approval ledger schema, approval tests, plugin approval contract | parked diff | UNSAFE_ADMISSION_INTEGRATION | Rejected; no approval matcher or ledger change. |
| Project Main Bot plugin route input and durable route | `plugin-route-input.schema.v1.json`, `PROJECT_MAIN_BOT_PLUGIN_ROUTE_CONTRACT.md`, `Invoke-TsfProjectMainBotDryRun.ps1` changes | parked diff | UNSAFE_MAIN_BOT_INTEGRATION | Rejected; Main Bot untouched. |
| Parked runtime/admission/approval/Main Bot tests | parked `tests/run-tsf-plugin-*.ps1` and helper | parked diff | NOT_NEEDED | Not copied; V1 has one isolated static validator. |
| Parked validation logs and runtime evidence assertions | parked validation logs and `validation_artifacts/` | parked diff | NOT_NEEDED | Historical outputs not adopted or claimed. |
| Adapter/plugin evidence contract and exact-minimum evidence documentation | parked advanced documentation | parked diff | UNSAFE_RUNTIME_EVIDENCE | Rejected from this lane. |
| Runtime pilot, live probe, install, enable, connect, authenticate, load, invoke, or action procedures | NOT_FOUND in safe static scope | user directive / trace result | NOT_FOUND | No procedure created. |

## Independent reconstruction notes

- The new schema uses `STATIC_NON_OPERATIONAL_NON_AUTHORITATIVE_HUMAN_DECISION_SUPPORT_ONLY`, not the parked selection authority boundary.
- Core and project classifications are explicitly candidates.
- Packs have explicit false values for selection, installation, enablement, loading, runtime enforcement, and approval.
- No parked schema, implementation file, test helper, log, or complete directory was copied.
