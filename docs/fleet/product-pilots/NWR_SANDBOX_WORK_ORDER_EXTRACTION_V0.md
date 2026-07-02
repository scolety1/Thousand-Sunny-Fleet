# NWR Sandbox Work-Order Extraction V0

## Purpose

This report records the TSF-approved NWR sandbox-only work-order extraction run
on 2026-07-02. The goal was to turn the existing NWR sandbox evidence into
bounded future work-order candidates and a gate map Tim can approve, edit,
deny, or ignore later.

This report is evidence only. It does not authorize canonical NWR mutation,
NWR pushes, TSF pushes, tests, proof runs, app/server/runtime work, installs,
migrations, deploys, secrets/auth/payments work, all-fleet commands, background
runners, PrivateLens work, external account work, production ranking changes,
formula/model/source-truth promotion, hidden sort behavior, recommendations, or
production app wiring.

## Exact Approval Used

```text
action: NWR sandbox-only work-order extraction
canonical repo path: C:\NWR\Niners-War-Room
sandbox path: C:\NWR\Niners-War-Room-tsf-experiment-sandbox-20260702
allowed product-repo mutation: YES, but only inside the existing sandbox worktree and only for sandbox docs/work-order notes
canonical checkout mutation: NO
NWR push: NO
TSF push: NO
installs/migrations/deploy/secrets/proof/all-fleet/background runners: NO
expires after: one sandbox work-order extraction report
```

## Sandbox Evidence Used

Sandbox evidence:

- `SANDBOX_EXPERIMENT_LOG.md`
- `docs/hq/sandbox/NWR_SANDBOX_ARTIFACT_SURFACE_MAP_20260702.md`
- `README.md`
- `app/navigation.py`
- targeted guardrail text search over `docs/`, `app/`, and top-level policy
  docs, excluding secrets and `.env` paths

TSF evidence:

- `docs/fleet/product-pilots/NWR_EXPERIMENT_SANDBOX_V0.md`
- `fleet/runs/product-pilots/nwr-experiment-sandbox-v0-2026-07-02.json`
- `docs/fleet/product-pilots/NWR_READ_ONLY_ISOLATED_WORKTREE_PILOT_V0.md`
- `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md`
- `docs/fleet/TSF_NEXT_SESSION_CARDS_V1.md`
- `docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md`
- `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md`

## Canonical NWR Status Before / After

Canonical repo path: `C:\NWR\Niners-War-Room`

Before and after this lane, the canonical checkout remained on:

`work/nfl-usage-target-backtest-v0...origin/work/nfl-usage-target-backtest-v0`

It was dirty before the run and remained dirty after the run with the same
DynastyProcess CSV evidence files under:

- `docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/dp_freshness_report.csv`
- `docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/dp_market_baseline_context.csv`
- `docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/dp_nwr_join_coverage.csv`
- `docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/dp_pick_value_context.csv`
- `docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/dp_playerid_crosswalk_audit.csv`

Canonical NWR was not modified.

## Sandbox Path / Branch / HEAD

| Field | Result |
| --- | --- |
| Sandbox path | `C:\NWR\Niners-War-Room-tsf-experiment-sandbox-20260702` |
| Sandbox branch | `work/tsf-nwr-experiment-sandbox-20260702` |
| Start HEAD for this lane | `d747ee265239cb29d21eb1e96d03910367eeb9a0` |
| Final sandbox HEAD | `5dbaf215d114ea7b679d77f3bacfa1bfedac7a02` |
| Sandbox tracking state | ahead 2, behind 6 versus local `origin/work/hq-parallel-control` |
| Final sandbox status | clean |

The sandbox branch is local-only. No fetch, merge, rebase, reset, restore,
clean, or push was performed. The behind count was not resolved in this lane
because synchronization was out of scope.

## Sandbox Artifacts Created / Updated

Created:

- `docs/hq/sandbox/NWR_SANDBOX_WORK_ORDER_CANDIDATES_20260702.md`
- `docs/hq/sandbox/NWR_SANDBOX_GATE_MAP_20260702.md`

Updated:

- `SANDBOX_EXPERIMENT_LOG.md`

## Sandbox Commit Created

- `5dbaf215d114ea7b679d77f3bacfa1bfedac7a02` -
  `docs: add NWR sandbox work-order candidates`

This commit is local-only on the sandbox branch and was not pushed.

## Top Future NWR Work-Order Candidates

### 1. NWR Artifact Map V1

- Purpose: build a fuller review-only map of NWR app pages, docs/HQ evidence,
  model/outcome docs, config boundaries, sample-data areas, and test areas.
- Exact artifact: `docs/hq/sandbox/NWR_ARTIFACT_MAP_V1_<date>.md` or a TSF
  product-pilot report.
- Allowed scope: read-only sandbox inspection and one report.
- Forbidden scope: canonical mutation, NWR push, tests/proof runs, runtime,
  installs, migrations, secrets, source registry changes, rankings/model/formula
  promotion, hidden sort, recommendations, PrivateLens, external accounts.
- Required inputs: sandbox log, sandbox surface map, README, navigation.
- Validation: `git diff --check`, authority wording scan, final status.
- Stop conditions: secrets, runtime/tests/install needs, or implementation
  drift.
- Tim gates: required for any mutation, tests, push, or sensitive path.

### 2. NWR Evidence Surface Boundary Review V1

- Purpose: classify Development Lab, Evidence Review Hub, Settings / Data
  Health, NFL Usage Evidence Review, Model Lab, and related HQ evidence surfaces
  as evidence-only, review-only, manual-only, authority-gated, or blocked.
- Exact artifact: `docs/hq/sandbox/NWR_EVIDENCE_SURFACE_BOUNDARY_REVIEW_V1_<date>.md`
  or a TSF product-pilot report.
- Allowed scope: read-only sandbox docs/app surface review and one matrix.
- Forbidden scope: app wiring, UI behavior changes, source-truth promotion,
  model/formula/ranking changes, hidden sort, recommendations, source/config/data
  mutation, tests, installs, runtime, migrations, deploys, secrets, pushes.
- Required inputs: navigation, Development Lab component, evidence/settings/NFL
  usage pages, evidence hub guardrail docs, sandbox surface map.
- Validation: diff check, authority scan, no production behavior changes.
- Stop conditions: secrets, runtime requirement, or production recommendations.
- Tim gates: required before any surface behavior, app wiring, or evidence
  promotion.

### 3. NWR Current Board Gate Inventory V1

- Purpose: summarize current-board candidate feature, scoring, and shadow-review
  gate packets so Tim can see what is review-only, complete, blocked, and
  approval-gated.
- Exact artifact: `docs/hq/sandbox/NWR_CURRENT_BOARD_GATE_INVENTORY_V1_<date>.md`
  or a TSF product-pilot report.
- Allowed scope: read-only docs/HQ gate inventory.
- Forbidden scope: production activation, Rankings integration, hidden sort,
  recommendations, formula/model promotion, source-truth promotion, app wiring,
  tests/proof runs, installs, runtime, migration, deploy, secrets, push.
- Required inputs: current-board, shadow, evidence hub, and historical formula
  gate packets.
- Validation: diff check, authority scan, blocked activation language.
- Stop conditions: needing code/tests or conflicting evidence.
- Tim gates: required before any production activation or app behavior.

### 4. NWR Sandbox Retention Decision Packet

- Purpose: prepare a TSF-local decision packet asking whether to keep, reuse, or
  later clean up the sandbox.
- Exact artifact: `docs/fleet/product-pilots/NWR_SANDBOX_RETENTION_DECISION_PACKET_<date>.md`
- Allowed scope: inspect sandbox/canonical git status and summarize options.
- Forbidden scope: deletion, `git worktree remove`, branch deletion, reset,
  restore, clean, NWR push, canonical mutation, tests, installs, runtime, deploy,
  secrets, proof runs, all-fleet/background work.
- Required inputs: sandbox status/log, TSF sandbox reports, canonical status.
- Validation: TSF diff check and authority scan.
- Stop conditions: cleanup needed without exact approval, ambiguous sandbox
  status, or dirty files outside known docs.
- Tim gates: exact approval required before deleting, promoting, merging,
  pushing, or reusing the sandbox beyond documentation extraction.

## Gate Map Summary

The sandbox gate map separates:

- read-only docs/status work: safe only with exact sandbox/read-only scope;
- sandbox-only docs/prototype notes: safe only inside the approved sandbox path;
- canonical NWR mutation: blocked until exact approval;
- tests/proof runs: blocked until exact approval;
- runtime/app/server work: blocked until exact approval;
- rankings/model/formula/source-truth promotion: blocked until exact approval;
- hidden sort/recommendation behavior: blocked until exact approval;
- installs/migrations/deploy/secrets/auth/payments/external accounts:
  blocked until exact approval;
- NWR push/remote changes: blocked until exact approval;
- sandbox cleanup/deletion: blocked until exact approval.

## Recommended Next NWR Lane

Recommended next lane: **NWR Evidence Surface Boundary Review V1**.

Reason: it is the safest useful next step because it stays documentation-only
and clarifies which NWR surfaces are evidence-only versus authority-gated before
Tim considers any future app, ranking, model, formula, source-truth, hidden-sort,
or recommendation work.

## Explicitly Blocked Lanes

Do not advance from this packet into:

- production ranking/formula/model changes;
- hidden sort or recommendations;
- app wiring or production route changes;
- source-truth promotion;
- tests or proof runs;
- installs, migrations, runtime, or deploy;
- secrets/auth/payments;
- all-fleet commands or background runners;
- NWR push;
- canonical checkout mutation;
- PrivateLens or external account work.

## Whether Sandbox Should Be Kept

Recommendation: keep the sandbox temporarily if Tim wants to run the recommended
Evidence Surface Boundary Review V1. Do not delete, promote, merge, push, rebase,
or sync it without exact approval.

## Validations Run

- Canonical NWR status before and after; unchanged.
- Sandbox `git status --short --branch`.
- Sandbox `git diff --check` on changed files.
- Sandbox staged-file exactness before sandbox commit.
- TSF `git status --short`.
- TSF `git diff --check` on changed TSF files.
- TSF JSON parse for structured log.
- Authority wording scan on new/changed sandbox and TSF docs.
- Full TSF suite.

## Final Recommendation

The extraction succeeded. Use **NWR Evidence Surface Boundary Review V1** as the
next safest NWR lane if Tim wants one more sandbox-only documentation pass.

TSF push is recommended only after exact Tim approval. NWR push is not
recommended and remains blocked.

No canonical NWR mutation, NWR push, TSF push, deploy/install/migration,
secret/auth/payment, proof-run, all-fleet, background, PrivateLens, or external
account work was performed.
