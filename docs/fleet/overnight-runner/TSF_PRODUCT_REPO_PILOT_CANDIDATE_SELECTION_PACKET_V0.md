# TSF Product Repo Pilot Candidate Selection Packet V0

Prepared: 2026-07-02

Draft only. Evidence only. This packet does not approve product repo access,
product repo mutation, PrivateLens access, archived project reactivation, push,
deploy, installs, migrations, secrets/auth/payments, proof runs, all-fleet
commands, background runners, external account changes, spending, credential
changes, or remote/history changes.

## Purpose

This packet selects, or refuses to select, the safest first read-only
product-repo pilot candidate from TSF-local evidence only.

## Why This Packet Exists

TSF now has a read-only product-repo pilot approval packet and structured runner
decision-log templates. The remaining question is whether TSF-local evidence is
strong enough to recommend one first repo for Tim to approve later.

This lane deliberately stops before product inspection. It prepares the
candidate decision and exact approval shape so Tim can approve, edit, deny, or
ignore it without Codex guessing.

## Evidence Sources Used

Only TSF-local docs/status/draft evidence was used:

- `fleet/status/current.md`
- `fleet/status/today.md`
- `fleet/status/projects.md`
- `fleet/status/projects.json`
- `fleet/status/project-passports/privatelens.md`
- `fleet/status/next-session/privatelens.md`
- `fleet/status/work-orders/privatelens-work-order.md`
- `fleet/status/work-order-splits/privatelens-split.md`
- `fleet/status/draft-queue/overnight-draft-batch-v1.md`
- `fleet/status/draft-queue/morning-decision-queue.md`
- `fleet/status/draft-queue/lane-7-product-access-approval.md`
- `fleet/status/draft-queue/privatelens-read-only-inspection-approval.md`
- `docs/fleet/TSF_CONTROL_PLANE_OVERVIEW_V1.md`
- `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`
- `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md`
- `docs/fleet/TSF_NEXT_SESSION_CARDS_V1.md`
- `docs/fleet/TSF_CONTROL_PLANE_ARTIFACT_INDEX_V1.md`
- `docs/fleet/TSF_STATUS_FRESHNESS_INDEX_V1.md`
- `docs/fleet/overnight-runner/TSF_READ_ONLY_PRODUCT_REPO_PILOT_APPROVAL_PACKET_V0.md`

No product repo, PrivateLens repo, archived project repo, external account,
secret store, deploy target, package manager, proof runner, all-fleet command,
or background runner was inspected.

## Candidate Selection Criteria

A safe first read-only product-repo pilot candidate should:

- be supported by current TSF-local status evidence
- be one named repo only
- have a clear local repo path from TSF-local evidence
- not be archived unless Tim explicitly reactivates it
- not be PrivateLens unless Tim explicitly names PrivateLens
- support a docs/status/readme-heavy inspection rather than runtime app work
- avoid installs, migrations, secrets, tests, dev servers, services, deploys,
  proof runs, all-fleet commands, external APIs, background runners, and account
  work
- fit into one TSF-local report artifact and optional structured decision log
- preserve read-only scope with no file mutation, staging, commit, or push

## Candidate Shortlist From TSF-Local Evidence Only

| Candidate | TSF-local evidence | Status | Selection decision |
| --- | --- | --- | --- |
| PrivateLens | Current status says PrivateLens remains the active project in TSF-local evidence; passport and next-session card name a repo path but also say status is `UNKNOWN` and the registered project is not available on this machine. A separate draft approval packet exists for PrivateLens. | Active/UNKNOWN, PrivateLens-gated | Not selected automatically. Avoid PrivateLens unless Tim explicitly names it. |
| Bottlelight, CursorPets, EasyLife, EventBook, FinanceDecisionLab, ForecastLab, LifeCapacity, LineupLab, NinersWarRoom, OrderPilot, RestaurantDemo, RestaurantProfitLab, ShiftLedger, ShiftPlate, Tree, UrbanKitchenSite | `fleet/status/projects.md` and `fleet/status/projects.json` list these projects as archived. | Archived | Excluded. Archived projects stay locked unless Tim explicitly reactivates one. |

## Recommended First Candidate

No safe candidate yet.

TSF-local evidence does not currently support selecting a first product-repo
pilot automatically. The only unarchived product signal is PrivateLens, and this
lane's selection criteria avoid PrivateLens unless Tim explicitly names it. All
other registry candidates are archived and require exact reactivation approval
before inspection.

## Why No Candidate Is Safest

Selecting no candidate is safest because:

- it obeys the active PrivateLens boundary instead of silently treating
  PrivateLens as the default
- it does not reactivate archived projects by implication
- it avoids using stale or generated status as product-repo approval
- it keeps product-repo access `TIM_REQUIRED`
- it gives Tim one clear decision: name the repo/path/scope or keep the pilot
  parked

## What Is Explicitly Not Approved Yet

This packet does not approve:

- product repo inspection or mutation
- PrivateLens inspection or mutation
- archived project reactivation
- opening, listing, reading, testing, building, staging, committing, or pushing
  inside any product repo
- deploys, installs, migrations, secrets/auth/payments work, proof runs,
  all-fleet commands, background runners, external account changes, spending,
  credential/account changes, or remote/history changes

Generated status, draft packets, work orders, next-session cards, and this
selection packet are evidence only.

## Proposed Read-Only Pilot Scope

If Tim wants to proceed later, the proposed pilot should be:

- one exact repo only
- one exact local path only
- current local branch only unless Tim names another branch
- read-only only
- no file mutation
- no staging, local commit, or push
- no installs, builds that install, tests that mutate state, migrations,
  deploys, services, dev servers, watchers, proof runs, all-fleet commands,
  external APIs, or background runners
- no secrets/auth/payments/deploy/credential material
- one TSF-local report artifact
- optional structured JSON decision log only if Tim approves it

## Allowed Read-Only Commands

Tim must approve exact commands before any pilot. A minimal command set could be:

```text
git -C <repo-path> status --short
git -C <repo-path> branch --show-current
git -C <repo-path> rev-parse HEAD
git -C <repo-path> rev-parse --verify origin/main
git -C <repo-path> log --oneline -5
git -C <repo-path> diff --stat
git -C <repo-path> diff --name-only
Get-ChildItem -LiteralPath <repo-path> -Name
Get-Content -LiteralPath <approved-doc-or-metadata-file> -TotalCount <line-limit>
```

No command is allowed unless Tim includes it in a complete exact approval block.

## Forbidden Commands / Actions

The pilot must not run or perform:

- `git add`, `git commit`, `git push`, `git fetch`, `git pull`, `git checkout`,
  `git switch`, `git merge`, `git rebase`, `git reset`, `git clean`, or force
  or history rewrite commands in the product repo
- `Set-Content`, `Add-Content`, `Out-File`, `Remove-Item`, `Move-Item`,
  `Copy-Item`, formatters, generators, or any command that writes inside the
  product repo
- package installs or dependency changes
- migrations, deploys, seed scripts, proof runs, all-fleet commands, dev
  servers, watchers, daemons, scheduled jobs, or background runners
- commands that intentionally read `.env`, keys, tokens, credentials, payment
  files, auth material, deploy configs, production configs, or secret stores
- PrivateLens access unless Tim explicitly names PrivateLens in the approval
- archived project access unless Tim explicitly reactivates the project

## Stop Conditions

Stop before inspection if:

- Tim has not named exact repo, path, branch, scope, allowed commands, max
  duration, max files read, output artifact, stop conditions, and expiry
- the named repo is PrivateLens and Tim did not explicitly name PrivateLens
- the named repo is archived and Tim did not explicitly reactivate it
- the path is missing, not a git repo, or does not match the approval
- any useful next step requires mutation, install, migration, deploy, secrets,
  auth, payments, proof run, all-fleet command, external account work,
  background runner, push, or network refresh
- the pilot would need to inspect secret-bearing files
- max duration, max files read, max report artifacts, or approved command scope
  would be exceeded
- product worktree dirtiness cannot be classified from the approved read-only
  scope

## Expected Output Artifacts

If Tim later approves a real pilot, expected TSF-local output is:

- `fleet/runs/read-only-product-repo-pilot/<repo>-read-only-pilot-<YYYY-MM-DD>.md`
- optional `fleet/runs/read-only-product-repo-pilot/<repo>-read-only-pilot-<YYYY-MM-DD>.json` only if Tim approves a structured log

The output should report branch, HEAD, local status, commands run, files read,
findings, blockers, tuning signals, and any exact Tim gate still needed.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| PrivateLens becomes the silent default. | Do not select it unless Tim explicitly names it. |
| Archived projects are reopened accidentally. | Exclude archived projects unless Tim explicitly reactivates one. |
| Stale TSF status is mistaken for live product truth. | Treat all TSF status as evidence and verify only after exact approval. |
| Read-only inspection drifts into implementation. | Limit to one report artifact and no mutation, staging, commit, or push. |
| Secret-bearing files are exposed. | Forbid `.env`, keys, tokens, credentials, payment, auth, deploy, production config, and secret-store material. |
| Scope grows into runtime work. | Forbid installs, services, tests that mutate state, proof runs, all-fleet commands, deploys, network refresh, and background runners. |

## TIM_EXACT_APPROVAL Block

Tim may copy and edit this block later. It must be complete before Codex
inspects any product repo.

```text
TIM_EXACT_APPROVAL:
action: run read-only product-repo pilot
repo name:
local repo path:
branch:
read-only scope:
allowed command(s):
forbidden command(s):
max duration:
max files read:
max report artifacts:
output artifact path:
structured JSON decision log: YES/NO
local commits in product repo: NO
push: NO
deploy/install/migration/secrets/auth/payments/proof-run/all-fleet/background/external accounts/spending/credential changes: NO
PrivateLens access: NO unless repo name/path above explicitly names PrivateLens and Tim intends that
archived project reactivation: NO unless explicitly named here
stop conditions:
expires after:
```

If any field is blank, ambiguous, stale, or broader than the minimal pilot
shape, Codex must treat the product-repo pilot as not approved.

## Final Recommendation

Do not run a product-repo pilot yet.

Tim's next decision is to either:

1. name and approve one exact non-archived, non-PrivateLens repo/path/scope for
   read-only inspection, or
2. explicitly name PrivateLens and approve the existing PrivateLens read-only
   inspection packet, or
3. explicitly reactivate one archived project with read-only inspection scope.

Until then, the safest candidate selection is `NO_SAFE_CANDIDATE_YET`.
