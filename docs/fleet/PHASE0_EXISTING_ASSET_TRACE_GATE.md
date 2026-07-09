# Phase 0 Existing-Asset Trace Gate

Prepared: 2026-07-08

Scope: Thousand Sunny Fleet control-plane docs, schemas, task packets, validators, fixtures, and review packets. This adapter brings the external Phase 0 review packet into the local TSF control plane. It is evidence and protocol authority for TSF-local work; it is not permission to inspect canonical NWR, read normal NWR packets, mutate product repos, launch ships, run all-fleet commands, push, deploy, install packages, run migrations, touch secrets, or start background runners.

Standing rule: research first. Source trace first. Code second.

## Required Front Door

Before any future TSF/Codex build, design, report, implementation, adapter, packet, formula, schema, validator, review, or repo work starts, the task packet or lane packet must include a `phase0Gate` record.

The `phase0Gate` record must prove:

- lane scope declaration
- allowed search scope
- forbidden search scope
- existing-asset trace
- asset classification
- reuse, admission, adapter, null-fence, validation, stop, or new-build decision
- explicit explanation of why new build is or is not allowed
- stop behavior when a useful asset may exist only in forbidden scope

## Required Fields

Every `phase0Gate` must include:

- `laneScopeDeclaration`
- `existingAssetTrace`
- `reuseDecision`
- `buildPermission`
- `scopeExpansionRule`

TSF packet schemas use camelCase JSON field names. Validation and review packets may also reference the same required concepts with these control-plane aliases:

- `phase0`: the mandatory `phase0Gate` front-door record
- `lane_scope_declaration`: `laneScopeDeclaration`
- `allowed_search_scope`: `allowedSearchScope`
- `forbidden_search_scope`: `forbiddenSearchScope`
- `existing_asset_trace`: `existingAssetTrace`
- `reuse_decision`: `reuseDecision`
- `build_permission`: `buildPermission`

`laneScopeDeclaration` must include:

- `laneType`
- `allowedSearchScope`
- `forbiddenSearchScope`
- `canonicalRepoInspectionAllowed`
- `normalNwrPacketReadsAllowed`
- `crossLaneComparisonAllowed`
- `mutationAllowed`
- `timApprovalRequiredForScopeExpansion`

`existingAssetTrace` must include:

- `searchedLocations`
- `matchingFilesOrFolders`
- `relevantExistingArtifacts`
- `classification`
- `reuseDecision`
- `whyNewBuildIsOrIsNotAllowed`
- `restrictedScopeExclusions`

Allowed classification values are:

- `already_exists_admitted`
- `exists_display_only`
- `exists_review_only`
- `exists_not_joined`
- `exists_wrong_scope`
- `exists_stale`
- `exists_conflicting`
- `exists_duplicate`
- `not_found`

Allowed reuse decisions are:

- `REUSE`
- `ADMIT_OR_GATE`
- `ADAPTER_NEEDED`
- `NULL_FENCE_NEEDED`
- `VALIDATION_NEEDED`
- `NEW_BUILD_ALLOWED`
- `STOP`

## Scope Expansion Stop

If a useful existing asset may exist only outside the declared allowed scope, the task must stop before reading that scope and return:

```text
TIM_REQUIRED_SCOPE_EXPANSION
```

The task may not read the forbidden scope, compare across lanes, inspect canonical repos, or mutate product repos until Tim approves the exact scope.

## Build Permission Rule

New build work is blocked unless the trace proves one of:

- the requested asset is genuinely `not_found` inside a sufficient allowed scope
- the existing asset is wrong-scope and cannot be safely reused
- the existing asset is stale or conflicting and a bounded replacement is justified
- the next step is a specific adapter, admission, validation, documentation, or null-fence artifact

If the existing asset can be reused, needs admission or gating, needs an adapter, is review-only or display-only, or cannot be proven absent without forbidden reads, stop before building.

## Integration Points

- Full task packets must include `phase0Gate` and are rejected by `ingest-task-packet.ps1` when it is missing or incomplete.
- Thin task packets must include `phase0Gate` before they can be used as future one-task operating packets.
- Task Contract V2 treats Phase 0 as the front-door gate before implementation fields can become runnable.
- HQ repair queue tasks should come from a task packet or local lane packet that carries `phase0Gate`; legacy queue text remains historical evidence and does not grant permission to skip Phase 0.
- Blocker recovery and data-foundation lanes must classify found assets before writing new artifacts. Existing datasets, schemas, validators, field maps, sidecars, review packets, and status reports should be reused or adapted instead of duplicated.

## Restricted-Action Confirmation

Phase 0 does not authorize canonical NWR inspection or mutation, normal NWR packet reads, product repo mutation, app wiring, production ranking changes, formula promotion, source-truth promotion, recommendations, hidden sort, push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet commands, proof runs, or background runners.
