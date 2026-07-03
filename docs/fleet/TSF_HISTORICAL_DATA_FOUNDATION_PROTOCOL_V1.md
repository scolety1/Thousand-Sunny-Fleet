# TSF Historical Data Foundation Protocol V1

Prepared: 2026-07-03

Authority artifact for TSF-local control-plane behavior. This protocol does
not approve product repo mutation, model tuning, ranking changes, app wiring,
source-truth promotion, public data acquisition, installs, migrations, deploys,
secrets/auth/payments work, PrivateLens work, all-fleet commands, pushes, or
background runners.

## Purpose

TSF Historical Data Foundation Protocol V1 codifies the lesson from the NWR
historical foundation failure/recovery: data-foundation lanes must discover and
classify source availability before declaring coverage missing.

The first TSF NWR historical foundation run was safe but shallow. It found only
2012, 2018, 2024, and 2025 because its generator hard-coded four local artifacts
and had no mandatory source discovery pass. The recovery lane proved the missing
coverage path, and a later exact Tim-approved public nflverse-style acquisition
run reached parity with the independent NWR packet.

## Data Foundation Lane Definition

A lane is a data foundation lane when its purpose is to create, normalize,
centralize, score, join, compare, or audit base data that future review,
experiments, model evaluation, or product work may rely on.

Data foundation lanes are not:

- model tuning
- ranking or formula changes
- app/runtime wiring
- source-truth promotion
- recommendation behavior
- hidden sort behavior
- proof runs
- production data mutation

Data foundation output is review/candidate evidence until a separate model-use
or source-truth gate approves a later use.

## Mandatory Source Discovery Pass

Before declaring coverage missing, a data foundation lane must run and document
a source discovery pass.

The pass must search:

- existing generated artifacts
- raw data directories
- ignored-but-present local outputs when safe and in scope
- builder scripts
- data loader functions
- docs for source/provenance paths
- fixtures and validation data
- local cache/source references without downloading

Each discovered source must be classified as one of:

- `already_built`
- `buildable_from_local_raw_data`
- `buildable_from_local_cached_or_generated_public_data`
- `buildable_only_with_public_download`
- `blocked_by_install_auth_or_credential`
- `missing`

The lane must distinguish `not built yet` from `not available`.

## Suspicious-Low-Coverage Rule

If target coverage is 20 or more seasons and discovered coverage is below 50%,
Codex must not immediately conclude missing coverage.

Before reporting partial coverage, Codex must:

- produce a provenance map
- identify broader source paths it searched
- explain why broader source paths cannot be used
- classify whether missing coverage is local-buildable, download-gated,
  install/auth/credential-gated, or truly missing

Low coverage can still be the correct outcome, but only after the discovery
pass proves why.

## Public Data Acquisition Gate

Public data acquisition/import requires exact Tim approval.

Approval must name:

- source class or source family
- repo/sandbox boundary
- output location
- whether downloads are allowed
- whether installs are allowed
- whether production promotion is forbidden
- no model tuning
- no ranking/formula changes
- no app/runtime wiring
- no source-truth promotion
- stop conditions
- approval expiry

`Use local/project data` does not approve public downloads.

If a source is buildable only with public download and approval is missing,
Codex must stop with a consolidated approval packet or produce a partial
no-download foundation with explicit caveats.

## Provenance Map Requirement

Future data foundation lanes must produce a source provenance map before final
coverage claims.

Required fields:

- `source_name`
- `source_path`
- `source_type`
- `seasons_available`
- `row_count`
- `stat_groups`
- `player_id_fields`
- `requires_download`
- `requires_install`
- `used_in_build`
- `trust_status`
- `notes`

The provenance map is evidence. It does not approve source-truth promotion or
future model use by itself.

## Strict vs Available-Component Scoring Rule

Missing scoring inputs cannot be silently forced to zero.

Strict scoring requires every scoring component needed by the stated scoring
definition. If any required component is unavailable, strict scoring must be
null or flagged incomplete for that row/season.

Available-component scoring may count only confirmed available components. It
must be labeled as partial/review evidence unless every required scoring
component is present.

If older seasons lack a component, the lane must state the scoring impact
instead of pretending the score is exact.

## Parity / Comparison Rule

When TSF and product-lane results diverge, compare before choosing a foundation.

Required comparison dimensions:

- source path and source class
- row counts
- seasons covered
- positions/entities covered
- scoring completeness
- missing component caveats
- identity issue counts
- source provenance
- validation results
- known bridge paths or year-specific caveats

Independent product-lane outputs may be used as benchmarks and provenance clues.
They must not be copied into TSF outputs unless the lane explicitly allows that
copy as the artifact being preserved.

## No-Promotion Rule

Historical foundation packets are review/candidate evidence only until a
separate model-use or source-truth gate approves later use.

They must not:

- tune or promote a production model
- change rankings
- change formulas
- add hidden sort
- create recommendations
- wire app behavior
- promote source truth
- bypass product repo gates

## Required Final Report Additions

Data foundation final reports must include:

- discovery method
- provenance map path and row count
- coverage target and actual coverage
- suspicious-low-coverage result if applicable
- public acquisition approval used, or explicit no-download boundary
- strict vs available-component scoring posture
- parity/comparison result when a benchmark exists
- remaining caveats
- guardrails preserved

## NWR Historical Foundation Lesson

The NWR recovery showed the correct sequence:

1. Preserve the partial packet before cleanup.
2. Delete only the exact failed sandbox after preservation validation.
3. Rerun from a fresh duplicate baseline.
4. Add a mandatory source discovery pass.
5. Produce a provenance map before declaring gaps.
6. Compare against independent product-lane evidence.
7. Stop at the public acquisition gate when no-download coverage remains
   partial.
8. Proceed with public acquisition only after exact Tim approval.
9. Preserve caveats even when parity is reached.

## Final Rule

Data foundation lanes should be conservative about authority and aggressive
about discovery. They should not say `missing` when the truth is `not discovered
yet`, `not built yet`, or `requires explicit public acquisition approval`.
