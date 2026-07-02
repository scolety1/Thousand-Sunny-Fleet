# TSF Read-Only Product Repo Pilot Approval Packet V0

Prepared: 2026-07-02

Draft only. This packet does not approve product repo access. A real
read-only product-repo pilot remains `TIM_REQUIRED` until Tim fills in and
approves exact repo, path, branch, scope, allowed commands, stop conditions,
and expiry.

## Purpose

This packet gives Tim a precise approval shape for the first future
read-only product-repo pilot. It lets TSF prepare the gate without inspecting
or mutating any product repo in this lane.

## Why This Packet Exists

The overnight-runner harness and JSON dry run proved that TSF can classify
runner candidates, log decisions, and stop at restricted gates. The next
runner expansion point is product-repo read-only inspection, but product repo
access is a true authority gate. This packet turns that gate into a single
approval-ready artifact instead of a chain of small questions.

## What The Previous Runner Dry Run Proved

The v0.1 JSON template dry run proved that the runner can represent:

- a selected safe TSF-local docs lane
- a skipped already-closed lane
- a deferred parked lane
- a `TIM_REQUIRED` product-repo pilot
- a `BLOCKED_UNSAFE` persistent runner request

It did not inspect a product repo, approve future product access, start a
persistent runner, run tests in another repo, or expand TSF authority.

## What Is Still Not Approved

The following remain not approved by this packet:

- product repo inspection or mutation
- PrivateLens inspection or mutation
- file edits in any product repo
- staging, local commits, or push in any product repo
- deploys, installs, migrations, secrets/auth/payments work, proof runs,
  all-fleet commands, external account work, spending, credential/account
  changes, archived project reactivation, history rewrite, or remote release
  changes
- persistent background, overnight, daemon, watcher, scheduled, service,
  cron, or Windows Task Scheduler work

Generated drafts, runner logs, queue entries, status files, and this packet
are evidence only. They do not authorize product repo access.

## Candidate Repo Selection Criteria

A first read-only pilot candidate should satisfy all of these criteria:

- Tim names exactly one repo and exact local path.
- The repo is not archived, or Tim explicitly reactivates the archived project
  with exact scope.
- The repo is not PrivateLens unless Tim gives exact PrivateLens approval.
- The approval names the branch and read-only scope.
- The pilot can answer useful onboarding/status questions without mutation.
- The pilot does not require installs, builds, dev servers, migrations,
  secrets, auth, payments, deploys, proof runs, all-fleet commands, external
  APIs, or background runners.
- The useful result can fit in one TSF-local report artifact and, optionally,
  one TSF-local JSON decision log.
- The allowed files are limited to safe metadata, README/docs, manifest files,
  and explicitly named source or config files that are not secret-bearing.

TSF-local status and draft files currently mention product candidates only as
unapproved evidence. `fleet/status/draft-queue/privatelens-read-only-inspection-approval.md`
mentions a PrivateLens path, but that draft is not approval and no PrivateLens
inspection is authorized here. `fleet/status/draft-queue/lane-7-product-access-approval.md`
is a general product-access template, not permission to inspect any repo.

## Recommended First Pilot Shape

Use the smallest useful pilot:

- one named repo only
- read-only inspection only
- current local branch only unless Tim names another branch
- no file mutation
- no staging, committing, or pushing
- no installs or dependency changes
- no tests that install packages, start services, require network access, or
  mutate state
- no secrets, auth, payments, deploy, migration, or credential material
- no network calls, remote fetch/pull, external APIs, or account access
- no background, watcher, daemon, scheduled, or persistent process
- one TSF-local report artifact only unless Tim also approves one structured
  JSON log

## Read-Only Allowed Command List

Tim must copy or edit the exact commands before approval. A minimal approved
pilot may allow only commands like these, with `<repo-path>` replaced by the
exact approved path:

```text
git -C <repo-path> status --short
git -C <repo-path> branch --show-current
git -C <repo-path> rev-parse HEAD
git -C <repo-path> rev-parse --verify origin/main
git -C <repo-path> log --oneline -5
git -C <repo-path> diff --stat
git -C <repo-path> diff --name-only
git -C <repo-path> ls-files
Get-ChildItem -LiteralPath <repo-path> -Name
Get-Content -LiteralPath <approved-file> -TotalCount <line-limit>
rg --files <repo-path> -g '!**/.git/**' -g '!**/.env*' -g '!**/*secret*' -g '!**/*key*' -g '!**/*token*'
```

If Tim does not approve a command explicitly, Codex must treat it as not
allowed. `origin/main` may be read only from the local git metadata; no
`git fetch`, `git pull`, remote API call, or network refresh is allowed unless
Tim separately approves it.

## Forbidden Command List

Unless Tim gives a separate exact approval, the pilot must not run:

- `git add`, `git commit`, `git push`, `git fetch`, `git pull`, `git checkout`,
  `git switch`, `git merge`, `git rebase`, `git reset`, `git clean`, or
  force/history rewrite commands in the product repo
- `Set-Content`, `Add-Content`, `Out-File`, `Remove-Item`, `Move-Item`,
  `Copy-Item`, formatters, code generators, or any command that writes inside
  the product repo
- package installs such as `npm install`, `pnpm install`, `yarn install`,
  `pip install`, `poetry install`, `bundle install`, `cargo install`, or
  similar dependency changes
- dev servers, watchers, daemons, scheduled jobs, background runners, or
  service starters
- migrations, deploys, seed scripts, payment/auth/secret tooling, external API
  calls, proof runs, all-fleet commands, or account-management commands
- commands that intentionally read `.env`, private keys, tokens, credentials,
  payment files, production deploy configs, or secret stores

## Stop Conditions

Stop before product inspection or continue no further if:

- Tim has not named exact repo, path, branch, scope, allowed commands, stop
  conditions, and expiry.
- The named path is missing, not a git repo, or does not match the approval.
- The repo appears archived or requires archived reactivation.
- The repo is PrivateLens and exact PrivateLens approval was not given.
- The useful next step requires mutation, staging, commit, push, install,
  migration, deploy, secrets/auth/payments work, proof run, all-fleet command,
  external account work, credential/account change, background runner, or
  network access.
- The pilot would need to inspect secret-bearing files or directories.
- The pilot would exceed max duration, max files read, max report artifacts,
  or the approved file/command scope.
- The product worktree is dirty and the approval does not say how to classify
  dirty files.
- A command output suggests unsafe ambiguity that cannot be resolved from the
  approved read-only scope.

## Expected Runner Decision-Log Fields

If Tim approves a structured log, use the v0.1 runner template fields:

- run ID
- date
- repo
- branch
- start HEAD
- origin/main baseline from local metadata if available
- approved scope
- forbidden scope
- candidate ID and name
- source artifact
- decision and decision subtype
- reason
- allowed scope
- forbidden scope
- artifact target
- validation expected
- stop condition checked
- result
- tuning signal

## Expected Final Report Format

Return one report with:

- verdict: `GREEN`, `YELLOW`, `RED`, or `TIM_REQUIRED`
- repo name and approved local path
- branch, `HEAD`, local status, and recent commits
- exact commands run
- files read, capped by the approved max file count
- output artifact path
- findings suitable for TSF-local planning
- blockers and true Tim decisions
- tuning signals for the runner
- whether any follow-up mutation would require a separate exact approval
- confirmation that no mutation, staging, commit, push, deploy, install,
  migration, secret, proof-run, all-fleet, background, PrivateLens, external
  account, spending, credential/account, archived-reactivation, or remote
  release work occurred unless separately approved

## Tuning Signals To Collect

Collect only runner-quality evidence:

- whether the approval fields were specific enough
- whether the allowed commands were sufficient and bounded
- whether any stop condition triggered
- whether max files read and max duration were appropriate
- whether the report artifact was useful for future TSF lane selection
- whether the runner overblocked, underblocked, or requested Tim for a normal
  strategy decision
- whether the JSON decision-log template needs a field change

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| A draft is mistaken for approval. | State repeatedly that this packet is not approval and requires filled exact Tim approval. |
| Product files are mutated accidentally. | Allow only read-only commands; forbid write, stage, commit, push, install, and generator commands. |
| Secrets are exposed. | Exclude `.env`, keys, tokens, credentials, payment, auth, deploy, and secret-store material. |
| Scope expands into product work. | Limit the first pilot to one report artifact and no implementation. |
| Remote/network state changes. | Forbid fetch, pull, deploy, APIs, external accounts, and network refresh unless separately approved. |
| PrivateLens is treated as generally approved. | Keep PrivateLens `TIM_REQUIRED` unless Tim names exact PrivateLens scope. |
| Archived projects are reactivated by implication. | Stop unless Tim explicitly reactivates the archived project. |

## TIM_EXACT_APPROVAL Block

Tim may copy, fill, and edit this block later. It must be complete before Codex
starts any real product-repo read-only pilot.

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
local commits in product repo: NO
push: NO
deploy/install/migration/secrets/auth/payments/proof-run/all-fleet/background/external accounts/spending/credential changes: NO
PrivateLens access: NO unless repo name/path above explicitly names PrivateLens and Tim intends that
archived project reactivation: NO unless explicitly named here
stop conditions:
expires after:
```

If any required field is blank, ambiguous, stale, or broader than the minimal
pilot shape, Codex must treat the pilot as not approved and return a
consolidated approval clarification instead of inspecting the repo.

## Final Recommendation

Do not run a product-repo pilot from this packet alone. The next safe step is
for Tim to review this packet and, only if wanted, fill the
`TIM_EXACT_APPROVAL` block with one exact repo, one exact local path, one
branch, bounded read-only commands, stop conditions, and expiry.
