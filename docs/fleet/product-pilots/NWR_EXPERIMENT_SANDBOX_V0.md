# NWR Experiment Sandbox V0

## Purpose

This report records the TSF-approved NWR isolated duplicate/sandbox experiment
run on 2026-07-02. The goal was to create a clean NWR sandbox worktree from the
approved local `origin/work/hq-parallel-control` ref, perform bounded local-only
documentation experiments there, and report the result back to TSF without
modifying the active canonical NWR checkout.

This report is evidence only. It does not authorize canonical NWR mutation,
NWR pushes, TSF pushes, deployments, installs, migrations, secrets/auth/payments
work, proof runs, all-fleet commands, background runners, PrivateLens access,
external account work, production ranking changes, formula/model promotion,
source-truth promotion, hidden sort behavior, recommendations, or runtime
behavior changes.

## Exact Approval Used

```text
action: NWR isolated duplicate/sandbox experiment
repo name: Niners War Room / NWR
canonical repo path: C:\NWR\Niners-War-Room
approved source ref: origin/work/hq-parallel-control
sandbox path: C:\NWR\Niners-War-Room-tsf-experiment-sandbox-20260702
sandbox branch name: work/tsf-nwr-experiment-sandbox-20260702
allowed product-repo mutation: YES, but only inside the sandbox worktree path above
canonical checkout mutation: NO
NWR push: NO
TSF push: NO
installs/migrations/deploy/secrets/proof/all-fleet/background runners: NO
expires after: one sandbox experiment report
```

## Canonical Repo Validation Result

| Field | Result |
| --- | --- |
| Canonical repo path | `C:\NWR\Niners-War-Room` |
| `rev-parse --show-toplevel` | `C:/NWR/Niners-War-Room` |
| Origin remote | `https://github.com/scolety1/Niners-War-Room.git` |
| Canonical branch/status | `work/nfl-usage-target-backtest-v0...origin/work/nfl-usage-target-backtest-v0` |
| Approved local source ref | `origin/work/hq-parallel-control` |
| Approved source ref HEAD | `6f61445665061d6687ced7c29be65b101c4033cc` |
| Canonical cleanliness | Dirty before sandbox creation; left untouched |

The canonical checkout was valid and had an `origin` remote. It was dirty before
the sandbox experiment with modified DynastyProcess CSV evidence files under:

`docs/hq/parallel_lanes/dynastyprocess_market_baseline_20260622/`

The active canonical checkout was not modified.

## Sandbox Creation Result

The approved sandbox path did not exist before this run, and the approved
sandbox branch name was not present. The sandbox was created with:

```powershell
git -C C:\NWR\Niners-War-Room worktree add -b work/tsf-nwr-experiment-sandbox-20260702 C:\NWR\Niners-War-Room-tsf-experiment-sandbox-20260702 origin/work/hq-parallel-control
```

No fetch was performed.

## Sandbox Branch / Path / HEAD

| Field | Result |
| --- | --- |
| Sandbox path | `C:\NWR\Niners-War-Room-tsf-experiment-sandbox-20260702` |
| Sandbox branch | `work/tsf-nwr-experiment-sandbox-20260702` |
| Source ref | `origin/work/hq-parallel-control` |
| Start HEAD | `6f61445665061d6687ced7c29be65b101c4033cc` |
| Final sandbox HEAD | `d747ee265239cb29d21eb1e96d03910367eeb9a0` |
| Sandbox ahead/behind vs source ref | ahead 1, behind 0 |
| Final sandbox status | clean |

## Experiments Attempted

### 1. Sandbox Creation

Result: `GREEN`

The sandbox was created from the approved local source ref on the approved local
branch. The canonical checkout was not mutated.

### 2. Read-Only Surface Orientation

Result: `GREEN`

Read-only listing and targeted search in the sandbox identified:

- app pages and navigation surfaces,
- docs/status/HQ evidence areas,
- Development Lab surfaces,
- Evidence Review and Evidence Review Hub surfaces,
- Settings / Data Health surfaces,
- review-only labels and guardrails,
- ranking/model/formula/source-truth boundaries.

Searches avoided `.env`, secret/key/token-like paths, dependency folders,
generated build folders, and runtime/deploy/auth/payment private material.

### 3. Sandbox-Local Documentation Notes

Result: `GREEN`

Created two sandbox-only docs artifacts:

- `SANDBOX_EXPERIMENT_LOG.md`
- `docs/hq/sandbox/NWR_SANDBOX_ARTIFACT_SURFACE_MAP_20260702.md`

These notes document observed surfaces and future work-order candidates. They do
not wire app behavior, change production routes, alter rankings, promote
formulas/models/source truth, add hidden sort, add recommendations, or touch
runtime/deploy behavior.

## Files Changed In Sandbox

- `SANDBOX_EXPERIMENT_LOG.md`
- `docs/hq/sandbox/NWR_SANDBOX_ARTIFACT_SURFACE_MAP_20260702.md`

## Sandbox Commits Created

- `d747ee265239cb29d21eb1e96d03910367eeb9a0` -
  `docs: add TSF experiment sandbox notes`

This commit exists only on the local sandbox branch. It was not pushed.

## What Was Learned

- The isolated sandbox pattern can safely contain NWR documentation experiments
  even while the canonical checkout has unrelated dirty files.
- NWR has many app and evidence surfaces, so future product pilots should stay
  narrow and name one inspection target.
- Development Lab, Evidence Review Hub, Settings / Data Health, and NFL usage
  surfaces repeatedly distinguish evidence from production activation.
- Guardrail language consistently blocks source-truth promotion, formula/model
  promotion, rank/tier changes, hidden sort, recommendation behavior, and app
  default changes without separate gates.
- Sandbox-local documentation commits are useful for experiment notes, but they
  should not be treated as production-ready NWR changes.

## Safe Future NWR Work-Order Candidates

1. **NWR Artifact Map V1**
   - Produce a fuller read-only artifact index from `docs/hq/`, `docs/model_v4/`,
     `docs/outcome_probability/`, app navigation, and page names.
   - Output: TSF report or sandbox-only docs artifact.
   - No app changes, tests, installs, runtime work, or pushes.

2. **NWR Evidence Surface Boundary Review V1**
   - Compare Development Lab, Evidence Review Hub, Settings / Data Health, and
     NFL Usage Evidence Review boundaries.
   - Output: evidence-only versus authority-gated surface matrix.
   - No source-truth promotion or production behavior changes.

3. **NWR Current Board Gate Inventory V1**
   - Summarize current board candidate feature/scoring/shadow gate packets from
     docs/HQ evidence.
   - Output: TSF-local or sandbox-only review packet.
   - No ranking, formula, hidden sort, model, or recommendation changes.

4. **NWR Sandbox Retention Decision Packet**
   - Prepare a TSF-local packet asking whether to keep, delete, or reuse this
     sandbox for another documentation-only pass.
   - No deletion, push, merge, or promotion without exact Tim approval.

## What Remains Blocked

- canonical checkout mutation,
- NWR push,
- TSF push,
- merge/rebase/reset/restore/clean,
- installs or migrations,
- app/server/dev-server/runtime work,
- proof runs or tests,
- all-fleet commands,
- deployments,
- secrets/auth/payments,
- PrivateLens,
- external account work,
- production ranking changes,
- formula/model/source-truth promotion,
- hidden sort or recommendation behavior.

## Guardrails Confirmed

- Product mutation was limited to the approved sandbox worktree only.
- The active canonical checkout was not modified.
- The sandbox commit contains only documentation/report notes.
- No app page, source code, config, data fixture, model file, source registry,
  ranking behavior, hidden sort, recommendation behavior, runtime file, deploy
  file, auth/payment file, secret, or external-account material was changed.
- No NWR or TSF push was performed.

## Sandbox Retention Recommendation

Keep the sandbox temporarily if Tim wants one more documentation-only NWR
orientation pass. Do not promote, merge, push, or reuse the sandbox for
production work without exact Tim approval.

If Tim does not need another sandbox pass, prepare a separate cleanup approval
packet before deleting the worktree. This run does not approve deletion.

## TSF Validations Run

- Confirmed TSF branch was `main`.
- Confirmed TSF started clean and aligned with `origin/main`.
- Ran `git diff --check` on TSF report/log files.
- Parsed the structured TSF JSON log.
- Scanned TSF report/log wording for restricted-authority leaks.
- Confirmed TSF staged files were exact before commit.

## Final Recommendation

The sandbox experiment succeeded. NWR is suitable for additional exact-scope,
sandbox-only documentation experiments, but any real product mutation,
production integration, tests/proof runs, runtime work, push, source-truth
promotion, ranking/model/formula behavior, hidden sort, recommendation behavior,
deploy/install/migration, secrets/auth/payments, PrivateLens, or external
account work remains blocked until Tim gives exact approval.
