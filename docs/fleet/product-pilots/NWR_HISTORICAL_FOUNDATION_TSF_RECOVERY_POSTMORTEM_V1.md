# NWR Historical Foundation TSF Recovery Postmortem V1

Prepared: 2026-07-03

Evidence only. This postmortem does not approve NWR mutation, model tuning,
ranking changes, app wiring, source-truth promotion, public data acquisition,
pushes, merges, deploys, installs, migrations, secrets/auth/payments work,
PrivateLens work, or all-fleet/background work.

## Original TSF Miss

The first TSF NWR historical foundation run was safe but shallow. It found only
2012, 2018, 2024, and 2025 because the generator hard-coded four local artifacts
and did not run a mandatory source discovery pass.

It did not search broader local/project paths, builder scripts, loader
functions, docs/provenance references, ignored-but-present outputs, cache/source
references, or the public nflverse-style source paths later proven necessary.

## What TSF Did Correctly

- Preserved the partial packet before cleanup.
- Validated the preserved zip before deleting the failed sandbox.
- Removed only the exact failed sandbox path after validation.
- Recreated work from a fresh duplicate baseline.
- Kept canonical NWR unchanged.
- Avoided model tuning, ranking changes, app wiring, source-truth promotion,
  push, merge, deploy, migration, secrets/auth/payments work, PrivateLens, and
  all-fleet/background work.

## What TSF Did Wrong

The first TSF run treated shallow artifact discovery as sufficient evidence of
missing coverage. It did not distinguish:

- data already built
- data buildable from local raw data
- data buildable from local cached/generated public data
- data buildable only with public download
- data blocked by install/auth/credential
- data truly missing

That created a partial packet that was safe, but under-discovered.

## Why NWR Found Full Coverage

The independent NWR packet used broader nflverse-style public sources:

- player_stats weekly data
- player_stats season data
- play-by-play data
- players/identity data
- roster data
- snap-count data
- a 2025 PBP plus roster/snap-count bridge path

Those sources supported seasons 2000 through 2025 for QB/RB/WR/TE historical
fantasy finish construction.

## How Recovery Fixed Discovery

The TSF recovery rerun created a 3,446-row provenance map and proved the root
cause. Under the no-download boundary, TSF still had partial coverage, but the
lane could now explain why:

- local/project artifacts covered only a small subset
- the broader parity path required public nflverse-style acquisition/import
- public download was not covered by the no-download approval

## Why Acquisition Approval Was Needed

Public data acquisition/import is a restricted gate. `Use local/project data`
does not automatically approve public downloads.

Tim later gave exact approval for a duplicate-only public nflverse-style
acquisition/import parity run. That approval allowed TSF to acquire the required
source class without mutating canonical NWR or promoting the result to source
truth.

## Final Parity Result

Successful parity result:

- Verdict:
  `GREEN_TSF_HISTORICAL_NFLVERSE_ACQUISITION_PARITY_BUILT_2000_2025_WITH_DOCUMENTED_CAVEATS`
- Packet:
  `C:\NWR_REVIEW\tsf_historical_nflverse_acquisition_parity_packet_20260703.zip`
- Report:
  `C:\NWR_REVIEW\TSF_HISTORICAL_NFLVERSE_ACQUISITION_PARITY_VS_NWR_REPORT_20260703.md`
- Baseline: `a2e81615f202a3c1ab00c4b176c810f80ca98555`
- Seasons: 2000-2025
- Positions: QB, RB, WR, TE
- Season raw rows: 16,478
- Weekly raw rows: 140,441
- Finish rows: 13,843
- Strict scoring rows: 13,843 / 13,843
- Available-component rows: 13,843 / 13,843
- Identity issues: 4,023
- Final parity provenance rows: 22
- Row-count parity with independent NWR packet: yes

## Remaining Caveats

- 2025 uses a PBP plus roster/snap-count bridge path and remains review-caveated.
- Matthew Stafford, 2010 week 8 appears as a duplicate player-week raw key,
  retained for parity and flagged for review before source-truth use.
- The packet is review/candidate evidence only.
- Any future model use, source-truth promotion, app wiring, ranking change, or
  formula change requires a separate exact gate.

## Guardrails Preserved

Canonical NWR remained unchanged. The lane did not tune a model, change
rankings, wire the app, promote source truth, push, merge, deploy, migrate,
access secrets/auth/payments, touch PrivateLens, or run all-fleet/background
work.

## Future Prompt Patch Language

Add this block to future historical/data foundation prompts:

```text
Before declaring coverage missing, run a mandatory source discovery pass.
Search generated artifacts, raw data directories, ignored-but-present local
outputs when safe, builder scripts, loader functions, docs/provenance paths,
fixtures, validation data, and local cache/source references without downloading.

Classify each source as already built, buildable from local raw data, buildable
from local cached/generated public data, buildable only with public download,
blocked by install/auth/credential, or missing.

If target coverage is 20+ seasons and discovered coverage is below 50%, do not
conclude missing coverage until a provenance map explains why broader source
paths cannot be used.

Public data acquisition/import requires exact Tim approval. Historical
foundation packets are review evidence only and do not approve model tuning,
source-truth promotion, ranking changes, formulas, hidden sort, recommendations,
or app wiring.
```

## Final Lesson

The right failure mode is not `found only four seasons, therefore the rest is
missing`. The right failure mode is `found only four seasons, therefore run
source discovery, classify the missing path, and stop at the exact acquisition
gate if public data is required`.
