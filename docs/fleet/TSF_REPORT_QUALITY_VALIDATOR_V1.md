# TSF Report Quality Validator V1

Prepared: 2026-07-01

Evidence only; not executable authority or approval.

## Purpose

TSF Report Quality Validator V1 is a reusable checklist and classifier for
Codex final reports produced under the TSF Autonomy Envelope.

Its job is to make final reports easier to trust without making Tim reconstruct
repo state by hand. It checks whether Codex reported the work selected, the
artifact produced, validations, commits, current git state, exclusions, and
remaining Tim gates with enough precision for HQ or Tim to decide what happens
next.

This validator is not a script, runner, background process, proof run,
all-fleet command, release gate, or push pathway.

## When To Use

Use this validator before a final response when Codex has done safe TSF-local
docs/control-plane work and may have created a local commit.

Also use it when reviewing a Codex final report after:

- autonomous intake
- dirty-work reconciliation
- local checkpoint packaging
- final gate closure
- HQ adapter or tuning work
- push-readiness review without push
- exact push after Tim approval
- data foundation lanes that build, compare, or acquire historical/source data
- blocker recovery lanes or any lane that encountered a blocker

Do not use this validator as approval for restricted actions. It only checks
report quality.

## Required Final Report Fields

A GREEN report must include:

- verdict: GREEN, YELLOW, RED, or TIM_REQUIRED
- work selected and why
- real finish line or done-enough condition
- concrete unblock artifact created or used
- files changed
- local commit hash and message if a commit was created
- validation commands run and results
- current branch
- current local HEAD
- local `origin/main` or remote baseline when available
- ahead/behind result when available
- final `git status --short`
- intentionally excluded scope
- true Tim gates remaining, if any
- push posture: recommended, not recommended, or Tim approval needed
- explicit restricted-boundary confirmation

If a field is not applicable, the report should say why.

## GREEN/YELLOW/RED/TIM_REQUIRED Classifier

| Classification | Use When | Required Next Action |
| --- | --- | --- |
| `GREEN` | Work is complete, validation passed, scope stayed TSF-local, staged files were exact, final status is clean, and any commit hash is reported. | Tim or HQ can review the result and decide whether a separate restricted gate is needed. |
| `YELLOW` | Work is safe but incomplete, validation was skipped with a clear reason, a non-blocking uncertainty remains, or push-readiness still needs a final check. | Report the exact remaining check or artifact; do not invent a Tim gate for normal strategy. |
| `RED` | Validation failed, scope became unsafe, staged files were not exact, repo state is ambiguous, or a report hides material facts. | Stop and repair or repacketize before any commit, push, or next lane. |
| `TIM_REQUIRED` | A true restricted gate is needed. | Produce one exact approval packet naming action, repo/path, branch, allowed command, max scope, stop conditions, and expiry. |

## Report Quality Scorecard

Score a report on a 20 point scale.

| Category | 2 Points | 1 Point | 0 Points |
| --- | --- | --- | --- |
| Verdict accuracy | Verdict matches the actual outcome and repo evidence. | Verdict is usable but underspecified. | Verdict contradicts checks, git state, or scope. |
| Work selection | Report names the chosen lane and why it was highest value. | Lane is named but the reason is thin. | Work selected is missing or vague. |
| Finish line | Done-enough condition is narrow and artifact-based. | Finish line is broad but understandable. | Finish line is missing or demands total proof. |
| Artifact clarity | Concrete file/artifact paths are listed. | Artifacts are named but paths are incomplete. | Artifact is vague or only a blocker note. |
| Validation evidence | Commands and results are listed. | Checks are summarized but not concrete. | Validation is missing or hidden. |
| Git truth | Branch, HEAD, ahead/behind, status, and commit hash are reported when relevant. | Some git facts are present. | Git state is missing or inconsistent. |
| Exact staging | Report confirms exact staged files before commit when a commit occurred. | Staging is implied but not proven. | Commit happened without staging evidence. |
| Boundary safety | Exclusions and restricted gates are explicit. | Boundaries are mostly present. | Report blurs evidence and restricted action. |
| Next action | Report gives one useful next action or says no safe work remains. | Next action exists but is broad. | Next action asks Tim to arbitrate normal strategy. |
| Brevity and usability | Report is compact enough to act on without losing key facts. | Report is long but scannable. | Report buries the outcome in low-value detail. |

Suggested result:

- 18-20: GREEN report quality
- 14-17: YELLOW report quality
- 10-13: RED report quality
- below 10: report should be rewritten before handoff

Any missed true restricted gate is RED no matter the score.

## Mandatory Boundary Checks

The final report must explicitly confirm whether any of these happened:

- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- background, overnight, daemon, watcher, scheduled, or unattended runners
- product repo access or mutation
- PrivateLens access or mutation
- archived project reactivation
- external account changes
- spending
- credential/account changes
- history rewrite or remote release changes

If none happened, say so plainly. If any happened, the report must name the
exact Tim approval that allowed it. If no exact approval exists, classify the
report as RED.

## Data Foundation Report Checks

For data foundation lanes, the report must also include:

- whether the lane was data foundation, audit, tuning, app work, or another
  class
- source discovery method
- provenance map path and row count
- target coverage and actual coverage
- suspicious-low-coverage result when target coverage is 20+ seasons
- whether public acquisition/import occurred
- exact Tim approval used for any public acquisition/import
- strict scoring completeness when scoring is involved
- available-component scoring posture when strict scoring is incomplete
- comparison/parity result when an independent benchmark exists
- row counts, season coverage, identity issue counts, and caveats
- no-promotion confirmation for model use, source truth, rankings, formulas,
  hidden sort, recommendations, and app wiring

If a data foundation lane reports low coverage without a provenance map, classify
the report as RED. If public acquisition/import occurred without exact Tim
approval, classify it as RED regardless of other validation.

## Blocker Recovery Report Checks

When a lane encountered a blocker, the final report must include:

- exact blocker summary
- blocker class or classes from `TSF_BLOCKER_CLASSIFICATION_MATRIX_V1.md`
- whether the blocker was solvable under current authority
- preservation action taken before cleanup/deletion/rerun, if applicable
- one bounded recovery path attempted, or reason recovery was not allowed
- artifact produced by the recovery pass
- validation result
- comparison against the original objective
- whether the result is recovered, narrowed, TIM_REQUIRED, or RED
- exact Tim approval request if a true gate remains

If a report repeats `blocked/not approved` without classification and a recovery
artifact, classify the report as RED unless the blocker is a true authority gate.

If more than one recovery rerun happened in the same lane without explicit user
approval, classify the report as RED.

## Commit Reporting Checks

When a local commit is created, the report should include:

- commit hash
- commit message
- files included in the commit
- validation checks before commit
- staged-file exactness check before commit
- final clean `git status --short`
- ahead/behind after commit
- statement that local commit does not imply push

If a commit was not created, the report should say `No commit created` and why.

## Push Posture Checks

Use one of these phrases:

- `Push not requested and not performed.`
- `Push requires exact Tim approval.`
- `Push was performed under exact Tim approval for [commit/branch].`

For push-readiness without push, the report should also include:

- current branch
- local HEAD
- local `origin/main`
- ahead/behind
- `git diff --check origin/main..HEAD` result when available
- clean worktree status

## Common Report Failures

RED failures:

- says GREEN while tests or diff checks failed
- omits final `git status --short`
- omits the commit hash after creating a commit
- says a restricted action happened but no exact approval is named
- claims product repo status from TSF-local docs alone
- treats a report, queue, UI label, or prompt as execution authority
- hides untracked or unstaged files
- says push-ready without checking ahead/behind and diff cleanliness
- declares historical/data coverage missing without mandatory source discovery
  and a provenance map
- performs public data acquisition/import without exact Tim approval
- reports data foundation output as source truth, model-ready, ranking-ready, or
  app-ready without a separate approval gate
- produces a blocker-only packet when a safe recovery artifact could have been
  built under current authority
- repeats blocker documentation without blocker classification, preservation
  when needed, one bounded recovery attempt, and a concrete recovery artifact
- asks Tim to choose normal TSF strategy when the autonomy envelope already
  covers it

YELLOW failures:

- validation was safe but skipped without enough reason
- the report names artifacts but not paths
- it lists too many next actions instead of one primary recommendation
- it says work is incomplete but does not define the remaining unblock artifact

## Good Report Fragment

```text
Verdict: GREEN

Work selected: TSF Report Quality Validator V1, because final-report quality is
now the review bottleneck after the autonomy envelope.

Artifacts:
- docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md

Commit:
- abc1234 docs: add TSF report quality validator

Validation:
- git diff --check -- docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md passed
- authority wording scan passed
- staged files were exactly docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md
- final git status --short was clean

Current branch: main
Ahead/behind: ahead 1, behind 0

Push requires exact Tim approval and was not performed.
No deploy/install/migration/secret/proof-run/all-fleet/background/product-repo/
PrivateLens/external-account work was performed.
```

## Bad Report Fragment

```text
Everything looks good. I made the docs better and we can ship.
```

Why this fails:

- no verdict
- no artifact paths
- no commit hash
- no validation evidence
- no git status
- no ahead/behind
- no restricted-boundary statement
- "ship" is ambiguous and may imply a restricted action

## Codex Self-Check Before Final Response

Before sending a final report, Codex should answer:

- Did I name the selected lane and why?
- Did I name the concrete unblock artifact?
- Did I list all changed files?
- If I committed, did I report the exact commit hash and message?
- Did I run and report `git status --short`?
- Did I report branch, HEAD, remote baseline, and ahead/behind when relevant?
- Did I report validation commands and results?
- Did I confirm staged files were exact before any commit?
- Did I say what was intentionally excluded?
- Did I name any true Tim gate that remains?
- Did I avoid asking Tim to arbitrate ordinary safe TSF strategy?
- Did I explicitly say no push happened unless exact push approval existed?
- Did I explicitly confirm no restricted action happened without exact approval?

## Future Improvement Hooks

If this validator repeatedly catches the same failure, create a future
TSF-local patch lane for one of:

- final-report template update
- push-readiness checklist update
- autonomous lane queue update
- safe stop escalation matrix
- authority boundary scan checklist

Do not add more prose if a validator, checklist, prompt, or work order would
solve the problem more directly.

## Final Note

This validator improves handoff quality. It does not execute checks by itself,
approve restricted gates, or replace current repo evidence. Codex must still
run the actual safe local commands and report their results.
