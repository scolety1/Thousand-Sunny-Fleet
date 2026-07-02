# TSF Next-Session Cards V1

Prepared: 2026-07-02

Evidence only; routing cards only; not executable authority or restricted-action
approval.

## Purpose

TSF Next-Session Cards V1 gives Tim and Codex compact starting cards for the
next likely TSF sessions. The goal is to reduce return-time reconstruction:
each card names the trigger, safe scope, finish line, unblock artifact,
validation, stop conditions, and whether Tim is truly needed.

These cards do not approve product repo access, PrivateLens work, push, deploy,
installs, migrations, secrets/auth/payments work, proof runs, all-fleet
commands, background or overnight runners, external account changes, spending,
credential/account changes, archived project reactivation, history rewrite, or
remote release changes.

## How To Use These Cards

1. Verify live git state first: branch, `HEAD`, `origin/main`, ahead/behind,
   and `git status --short`.
2. Read `docs/fleet/TSF_CONTROL_PLANE_OVERVIEW_V1.md`.
3. Read `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`.
4. Pick one card that matches the current trigger.
5. If the card says `TIM_REQUIRED`, stop before execution and ask for exact
   approval using the named approval packet.
6. If the card is safe TSF-local docs/control-plane work, build the artifact,
   validate, and create a local commit only when staged files are exact.

## Card Legend

- `READY_SAFE_LOCAL`: Codex may run the card inside TSF docs/control-plane
  scope when live repo evidence matches.
- `PARKED`: do not run unless the trigger appears.
- `TIM_REQUIRED`: stop before execution until Tim approves exact scope.
- `CLOSED_REFERENCE`: use as context only; do not reopen without a defect.

## Card 1 - Master Return Snapshot

Status: `READY_SAFE_LOCAL`

Use when:

- Tim asks "where are we?"
- local commits or status files may have drifted
- a future session needs a calm TSF state answer before choosing work

Safe scope:

- TSF repo status/log/diff inspection
- TSF-local docs/status reading
- one status artifact or closeout note if needed

Real finish line:

- current branch, local `HEAD`, local `origin/main`, ahead/behind, worktree
  status, latest relevant commits, lane posture, and true Tim gates are reported
  in one concise answer or TSF-local status artifact

Unblock artifact:

- final response, or a TSF-local status artifact if the user asks for durable
  output

Validation:

- `git status --short`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git rev-parse --verify origin/main`
- `git rev-list --left-right --count origin/main...HEAD`

Stop if:

- product repo or PrivateLens access is needed
- dirty files cannot be classified from local TSF evidence
- push or another restricted gate is needed without exact approval

Needs Tim:

- only if a restricted gate or unsafe ambiguity appears

## Card 2 - Push Current TSF Commit

Status: `TIM_REQUIRED`

Use when:

- local TSF commits exist
- worktree is clean
- Tim wants the commits published

Safe scope before approval:

- push-readiness checks only
- no push

Real finish line:

- exact Tim approval names branch, remote, commit(s), expected baseline,
  ahead/behind, and stop conditions; push happens only after final checks match

Unblock artifact:

- `fleet/status/draft-queue/tsf-push-approval-packet.md`, or a fresh exact
  push approval prompt

Validation:

- `git status --short`
- `git log --oneline -5`
- `git diff --check origin/main..HEAD`
- full TSF suite only when safe and requested by the approval packet

Stop if:

- worktree is dirty
- expected local `HEAD` or `origin/main` does not match
- ahead/behind is not the approved value
- push would require force, rebase, merge, or conflict resolution

Needs Tim:

- yes, exact push approval is always required

## Card 3 - Read-Only Product Repo Pilot Approval Review

Status: `TIM_REQUIRED` for product access; `READY_SAFE_LOCAL` for reviewing the
approval packet only

Use when:

- Tim wants to decide whether TSF should run a first read-only product-repo
  pilot later
- no real product repo access has been approved yet

Safe scope:

- read and refine TSF-local approval packet text only
- do not inspect product repos
- do not inspect PrivateLens

Real finish line:

- Tim has a complete approval block naming one repo, one path, branch,
  read-only scope, allowed commands, max duration, max files read, output
  artifact, stop conditions, and expiry

Unblock artifact:

- `docs/fleet/overnight-runner/TSF_READ_ONLY_PRODUCT_REPO_PILOT_APPROVAL_PACKET_V0.md`

Validation:

- authority wording scan
- `git diff --check` if the packet changes
- `git status --short`

Stop if:

- the work would inspect a product repo
- the work would inspect PrivateLens
- the packet starts granting blanket product access

Needs Tim:

- yes, to fill and approve exact repo/path/scope before any product inspection

## Card 4 - Read-Only Product Repo Pilot Execution

Status: `TIM_REQUIRED`

Use when:

- Tim has already filled a complete `TIM_EXACT_APPROVAL` block for one named
  product repo

Safe scope after approval:

- only the exact repo/path/branch/commands/files/duration/report artifacts named
  in Tim's approval
- no mutation, staging, commits, push, installs, tests that mutate state,
  secrets, deploys, migrations, proof runs, all-fleet commands, background
  runners, PrivateLens, or external accounts unless separately approved

Real finish line:

- one TSF-local read-only pilot report, and optional structured decision log if
  Tim approved it

Unblock artifact:

- `fleet/runs/read-only-product-repo-pilot/<repo>-read-only-pilot-<date>.md`
  or the exact path Tim names

Validation:

- exact command list from Tim's approval
- no changed files inside the product repo
- final TSF report confirms no restricted action occurred

Stop if:

- any approval field is blank or ambiguous
- the repo/path/branch does not match
- any useful step requires forbidden work
- max duration, file count, or report count would be exceeded

Needs Tim:

- yes, exact approval before any execution

## Card 5 - Authority Boundary Scan

Status: `PARKED`

Use when:

- a TSF doc, prompt, status file, draft, UI label, runner log, or work order
  blurs evidence and authority
- Codex is unsure whether a source can guide safe TSF-local work

Safe scope:

- TSF-local docs/control-plane inspection
- one scan checklist or correction note

Real finish line:

- the ambiguous source is classified as authority, evidence, generated status,
  generated work order, UI-only, test fixture, historical, or restricted-gate
  packet

Unblock artifact:

- `docs/fleet/TSF_AUTHORITY_BOUNDARY_SCAN_CHECKLIST_V1.md` if a real ambiguity
  appears

Validation:

- `git diff --check` on changed files
- authority wording scan
- `git status --short`

Stop if:

- classification would require product repo or PrivateLens access
- the scan becomes broad policy prose without a concrete ambiguity

Needs Tim:

- only if the ambiguity hides a true restricted gate

## Card 6 - Status Freshness Refresh

Status: `READY_SAFE_LOCAL` only when current return files are stale enough to
mislead a returning session

Use when:

- `fleet/status/current.md` or `fleet/status/today.md` points to a stale
  baseline as current truth
- the freshness index says a file is current but live git evidence has moved

Safe scope:

- TSF-local status docs only
- no product repo truth claims

Real finish line:

- current return files state the latest verified TSF baseline, local posture,
  safe next action, and remaining Tim gates without pretending to approve
  restricted work

Unblock artifact:

- refreshed `fleet/status/current.md`
- refreshed `fleet/status/today.md`
- optional freshness-index row update if needed

Validation:

- live git checks
- `git diff --check` on changed status files
- authority wording scan
- `git status --short`

Stop if:

- status claims require product repo or PrivateLens inspection
- status would imply push, deploy, proof-run, all-fleet, or background approval

Needs Tim:

- no, unless the refresh exposes a true restricted gate

## Card 7 - Runner Template Tuning

Status: `PARKED`

Use when:

- two or more runner dry runs show the same decision-log weakness
- a future TSF-local runner session needs a template field that does not exist

Safe scope:

- TSF-local runner docs/templates/logs only
- no persistent runner
- no product repo pilot

Real finish line:

- one template/checklist patch that fixes the repeated runner decision failure
  without expanding runtime authority

Unblock artifact:

- patch to `docs/fleet/overnight-runner/TSF_OVERNIGHT_RUNNER_DECISION_LOG_TEMPLATE_V0_1.md`
- optional patch to `docs/fleet/overnight-runner/tsf_overnight_runner_decision_log_template_v0_1.json`

Validation:

- JSON parse if the template changes
- `git diff --check` on changed files
- authority wording scan
- full TSF suite if safe

Stop if:

- the patch would create a persistent runner
- the patch would approve product repo access
- the patch requires external APIs or background execution

Needs Tim:

- only if the change would cross a restricted gate

## Recommended Next Card

If no user-selected lane is active and the repo is clean, use this order:

1. Card 1 if Tim needs a return snapshot.
2. Card 6 if phone-facing current status is stale enough to mislead.
3. Card 3 if Tim wants to review the product-repo pilot approval shape.
4. Card 5 only if a real authority/evidence ambiguity appears.
5. Card 7 only if repeated runner dry-run evidence shows a template gap.

Card 2 and Card 4 always require exact Tim approval before execution.

## Final Note

These cards are routing evidence. They help Codex select one safe next session,
but they do not override the autonomy envelope, safe stop matrix, artifact
index, live git validation, or exact Tim approval gates.
