# NWR Read-Only Isolated Worktree Pilot V0

## Purpose

This report records the first TSF-controlled read-only product-repo pilot against
Niners War Room (NWR). The pilot tested whether TSF can validate a canonical
product repo, create or reuse an isolated worktree from an approved local ref,
perform bounded read-only orientation, and return TSF-local evidence without
modifying product files.

This report is evidence only. It does not authorize product repo mutation,
NWR commits, NWR pushes, tests, runtime work, source-truth promotion, model
promotion, formula changes, ranking changes, hidden sort behavior, deployments,
installs, migrations, secrets/auth/payments work, proof runs, all-fleet
commands, background runners, PrivateLens access, or external account work.

## Exact Approval Used

```text
action: read-only product-repo pilot
repo name: Niners War Room / NWR
canonical repo path: C:\NWR\Niners-War-Room
approved source branch/ref for isolated worktree: origin/work/hq-parallel-control
preferred isolated worktree path: C:\NWR\Niners-War-Room-tsf-readonly-pilot-20260702
scope:
- validate canonical repo identity
- do not modify canonical checkout
- create or use clean isolated worktree only if safe
- perform read-only inspection in isolated worktree
- write report artifacts only in TSF repo
expires after:
- one read-only pilot report
```

## Canonical Repo Identity

| Field | Result |
| --- | --- |
| Canonical path | `C:\NWR\Niners-War-Room` |
| `rev-parse --show-toplevel` | `C:/NWR/Niners-War-Room` |
| Origin remote | `https://github.com/scolety1/Niners-War-Room.git` |
| Canonical branch/status | `work/nfl-usage-target-backtest-v0...origin/work/nfl-usage-target-backtest-v0` |
| Canonical HEAD | `e7c1aa564040d9c1dad61907c9f48cfc47931702` |
| Approved local source ref | `origin/work/hq-parallel-control` |
| Approved source ref HEAD | `6f61445665061d6687ced7c29be65b101c4033cc` |
| Canonical cleanliness | Dirty before pilot; left untouched |

The canonical checkout was a valid git repo and had an `origin` remote. It was
dirty before the pilot with modified CSV evidence files under
`docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/`.

Canonical dirty files observed:

- `dp_freshness_report.csv`
- `dp_market_baseline_context.csv`
- `dp_nwr_join_coverage.csv`
- `dp_pick_value_context.csv`
- `dp_playerid_crosswalk_audit.csv`

Because the canonical checkout was dirty, no inspection work was performed in
the active checkout. The canonical checkout was not modified.

## Isolated Worktree

| Field | Result |
| --- | --- |
| Worktree action | Created |
| Worktree path | `C:\NWR\Niners-War-Room-tsf-readonly-pilot-20260702` |
| Source ref | `origin/work/hq-parallel-control` |
| Worktree HEAD | `6f61445665061d6687ced7c29be65b101c4033cc` |
| Branch mode | Detached HEAD |
| Worktree cleanliness | Clean after inspection |

The isolated worktree was created with:

```powershell
git -C C:\NWR\Niners-War-Room worktree add --detach C:\NWR\Niners-War-Room-tsf-readonly-pilot-20260702 origin/work/hq-parallel-control
```

No NWR files were modified in the isolated worktree.

## Product Repo Commands Run

Canonical repo identity commands:

```powershell
git -C C:\NWR\Niners-War-Room remote -v
git -C C:\NWR\Niners-War-Room status --short --branch
git -C C:\NWR\Niners-War-Room rev-parse --show-toplevel
git -C C:\NWR\Niners-War-Room rev-parse HEAD
git -C C:\NWR\Niners-War-Room rev-parse --verify origin/work/hq-parallel-control
git -C C:\NWR\Niners-War-Room worktree list
```

Approved worktree creation command:

```powershell
git -C C:\NWR\Niners-War-Room worktree add --detach C:\NWR\Niners-War-Room-tsf-readonly-pilot-20260702 origin/work/hq-parallel-control
```

Read-only isolated-worktree commands:

```powershell
git status --short --branch
git branch --show-current
git rev-parse HEAD
git log --oneline -10
Get-ChildItem
rg --files
Get-Content README.md
Get-Content pyproject.toml
Get-Content RUN_POLICY.md
Get-Content MISSION.md
Get-Content app\navigation.py
Get-Content docs\hq\MASTER_HQ_OUTCOME_V2_HISTORICAL_GATE_CLOSEOUT_20260630.md
rg "Development Lab|Evidence Review|Data Health|Settings|review-only|review only|guardrail|promotion|promote|ranking|formula|source truth|NFLVerse|shadow|candidate|TIM_REQUIRED|approval"
```

Searches excluded `.env`, secret/key/token-like paths, generated build folders,
and dependency folders. No secret/auth/payment files were opened.

## Read-Only Inspection Summary

### Top-Level Structure

The isolated NWR worktree appears to be a local-first Python/Streamlit fantasy
football decision-support workspace. Top-level areas observed:

- `app/` - Streamlit pages, navigation, components, and UI surfaces.
- `src/` - config, connectors, data, models, services, and utilities.
- `docs/` - HQ packets, integration evidence, model audits, model docs, and
  outcome probability material.
- `sample_data/` - committed fixtures and historical/sample model inputs.
- `config/` - source registry, API source permissions, and scoring rules.
- `scripts/` - local command scripts and generators.
- `tests/` - test area observed by listing only; tests were not run.
- `templates/` - empty/template input shapes for local workflows.

Metadata observed:

- `pyproject.toml` identifies the project as `niners-war-room` with Python
  dependencies including `streamlit`, `pandas`, `pydantic`, `numpy`, and
  `nflreadpy`.
- `RUN_POLICY.md` describes the project as local-first and says runtime must not
  depend on mandatory live API calls, web scraping, production deploys, or
  auth/payment/customer-data integrations.
- `README.md` describes setup, local data packs, draft workflows, trust labels,
  historical replay, and V1 guardrails.

### Major App, Docs, Data, And Test Areas Observed

Observed app surfaces include:

- Draft Cockpit
- Mock Drafts
- Dynasty Rankings
- Player Compare
- Trading Lab
- Draft Analyzer
- Development Lab
- Roster Weakness Tracker
- Future Pick Planning
- Upcoming Draft Prep
- Keeper Deadline Prep
- Drop Deadline Prep
- Trade Deadline Prep
- Future Tools
- Refresh Data
- Evidence Review
- Evidence Review Hub
- Settings / Data Health

Observed docs/evidence areas include:

- HQ closeouts and historical gate packets.
- Evidence integration registry and readiness artifacts.
- Model audit and Model V4 documentation.
- Outcome probability gate closeouts.
- NFL usage evidence review references.

Observed data/test areas:

- `sample_data/` includes rookie, veteran, historical replay, replacement
  baseline, and pre-declaration fixtures.
- `tests/` exists as a tracked test area, but no tests were executed.

### Key NWR Surfaces Suggested By Docs/Status

The docs and navigation suggest NWR is organized around:

- decision cockpit and draft surfaces,
- evidence review and evidence integration,
- Settings / Data Health,
- Development Lab review tooling,
- NFLVerse/player context display,
- shadow/review-only model and formula work,
- HQ gate closeouts for approval boundaries.

### Evidence / Review-Only Patterns Observed

The pilot found repeated review-only boundaries:

- README trust labels include `Review Only` for outputs that require human
  review because of coverage gaps, source issues, or diffs.
- README says placeholder model outputs are review-only and cannot drive final
  recommendations.
- README says public-source intake rows are review-only until normalized and the
  model is regenerated.
- Development Lab code includes repeated `not model input`, `not source truth`,
  `display-only`, `manual`, and no-promotion language.
- HQ closeout material uses review-only approval states and explicitly blocks
  current-player activation, app integration, source-truth promotion, hidden
  sort keys, rank changes, tier changes, protected artifact updates, and
  latest-candidate updates.

### Guardrails Observed

The inspected materials support the NWR context supplied by Tim:

- Local-first runtime posture.
- Frozen/data-pack workflows instead of hidden mutation.
- Review-only evidence surfaces.
- Development Lab tools that do not promote evidence into source truth.
- Explicit separation between calibration/evidence and production activation.
- Human review gates before model, ranking, source-truth, formula, or app
  behavior changes.

## What Was Intentionally Not Inspected

The pilot intentionally did not inspect:

- `.env` files or local secret files.
- credentials, tokens, keys, auth configs, payment configs, private account
  files, or external account data.
- runtime/deploy/auth/payment paths beyond safe top-level policy statements.
- product mutation paths.
- PrivateLens.
- tests, test runners, proof runs, services, dev servers, migrations, installs,
  or app execution.
- files for the purpose of changing ranking, model, formula, UI behavior,
  hidden sort, source truth, recommendations, or production logic.

## Safe Future Work-Order Candidates

These are TSF-local report/work-order candidates only. They do not authorize NWR
mutation.

1. **NWR Read-Only Artifact Map V0**
   - Build a TSF-local map of NWR docs/status/evidence areas from an isolated
     read-only worktree.
   - Output only a TSF report.
   - No app changes, tests, installs, or NWR commits.

2. **NWR Evidence Surface Orientation Packet V0**
   - Summarize Evidence Review Hub, Settings / Data Health, Development Lab,
     and HQ closeout patterns from read-only inspection.
   - Identify which surfaces are evidence-only versus authority gates.
   - No source-truth or model promotion.

3. **NWR Narrow Read-Only Pilot Work Order V1**
   - Prepare exact approval language for one future read-only inspection focus.
   - Include repo/path/ref/max files/commands/stop conditions.
   - No product mutation, tests, installs, or runtime work.

4. **NWR Product-Mutation Approval Packet Template**
   - Draft a future template for Tim if he ever wants NWR mutation.
   - Keep all mutation blocked unless Tim supplies exact repo/path/branch/scope.

## Restricted Future Gates

The following remain TIM_REQUIRED and were not performed:

- product repo mutation,
- NWR commits or pushes,
- tests, proof runs, or runners,
- installs or migrations,
- app/server/runtime work,
- deploys,
- secrets/auth/payments,
- external account changes,
- PrivateLens access,
- source-truth promotion,
- ranking/model/formula promotion,
- hidden sort or recommendation behavior,
- archived project reactivation,
- all-fleet commands,
- persistent background/overnight/daemon/watcher/scheduled runners.

## Tuning Signals For TSF Runner

- The isolated-worktree pattern worked even though the canonical checkout was
  dirty, because the pilot avoided active-checkout inspection.
- Future runner logs should cap `git worktree list` output or record only the
  relevant target path; large worktree fleets can flood logs.
- The product-pilot approval packet should require an approved local ref before
  worktree creation, because fetching is not part of read-only pilot approval.
- Read-only content searches need explicit secret/path exclusions even when the
  intended scope is docs/source orientation.
- Future product pilots should name one narrow inspection question so the
  report does not drift into general product analysis.

## Final Recommendation

NWR is safe for future read-only pilots when Tim provides exact repo, path, ref,
inspection focus, allowed commands, max files, and stop conditions.

NWR mutation remains blocked and TIM_REQUIRED. Any future mutation, commit,
push, test/proof run, install, migration, runtime/server work, source-truth
promotion, ranking/model/formula promotion, hidden sort/recommendation behavior,
secrets/auth/payments work, PrivateLens access, deploy, or external-account work
requires separate exact Tim approval.

Recommended next approval, if Tim wants to continue: approve one narrow
read-only NWR artifact-map pilot from the same isolated-worktree pattern, with a
fresh exact ref/path/scope block.

## Final Confirmation

- NWR canonical checkout was not modified.
- NWR isolated worktree was not modified.
- No NWR commit was created.
- No NWR push was performed.
- No deploy, install, migration, secret/auth/payment, proof-run, all-fleet,
  persistent background runner, PrivateLens, or external-account action was
  performed.
