# TSF Operating Model

Prepared: 2026-06-14

Evidence only; not executable authority or approval.

## Purpose

This document defines Thousand Sunny Fleet / Codex Fleet as a local project-control and project-management system for safely coordinating bounded Codex work. The goal is TSF itself. PrivateLens remains a disposable proof target for selected proof-run workflows, not the TSF objective.

This operating model is architecture/spec guidance only. It does not implement product repo control, live phone command execution, proof runs, push, merge, deploy, package installation, migrations, remote access, secrets handling, all-fleet execution, overnight runners, phone approvals, runtime command binding, or future authority.

Backbone rule: reports are not the product. Reports prove what got finished.

## Completion-First Hierarchy

TSF exists to finish selected product work while Tim is away, not to produce
triage as the main deliverable. Morning reports, return reviews, scoreboards,
and console panels are proof and handoff surfaces after the real work is done.

The hierarchy is:

1. Finish the product work.
2. Keep moving through safe next steps without asking Tim.
3. Only stop for true blockers.
4. Make local commits for GREEN completed work when the run explicitly allows
   local commits.
5. Leave Tim a concise morning scoreboard after the work is done.

When a selected project's intent is clear, TSF should choose obvious safe
implementation details itself, make reasonable product-grade choices, and
continue from one safe task to the next. If visual or UX uncertainty could
matter, TSF may create up to three clearly labeled local options, choose the
safest default, and keep pushing toward a finished/showable surface.

TSF should not ask "how did I do?", stop after one small task, or hand Tim a
homework pile when more selected safe work remains. It should stop for Tim only
when the next step needs product direction, conflicting source truth resolution,
publication/release approval, secrets/accounts/API keys, migrations, archived
project reactivation, off-limits file expansion, or a validation failure that
cannot be safely repaired.

## Project Sections

TSF projects and tracks move through explicit sections:

- Ideas / Backlog
- Active / Development
- Review / Release Candidate
- Paused
- Archived / Parked
- Finished / Rolled Out
- Blocked

The section controls work eligibility. Section labels are evidence and routing metadata, not authority to execute.

## Ideas / Backlog

Ideas / Backlog can contain a one-line idea, rough note, vague outline, future feature thought, or possible upgrade. Ideas are not executable authority and are not autonomous-eligible.

TSF may help refine an idea into an end goal, milestone sketch, task packet, or active-track proposal. It must not treat an idea as approval to implement. Before implementation, the idea must be promoted into an active project/track with exactly one selected task, known allowed files, known validation, and current stop gates.

## Active / Development

Active / Development tracks are the normal place for bounded implementation work. They are eligible only when one project, one track, and one task are selected, and when allowed files, validation commands, stop conditions, and mode constraints are known.

Active status does not bypass safety gates. Product repos, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone approvals, and runtime command binding still require separate exact approval where applicable.

## Review / Release Candidate

Codex/TSF may mark a track as Review / Release Candidate after GREEN local validation. Review does not equal Finished.

Review / Release Candidate tracks can receive explicitly eligible review, polish, evidence, release-checklist, or rollback-planning work. TSF may not push, deploy, ship, or mark a track Finished / Rolled Out from review status by itself.

## Finished / Rolled Out

Finished / Rolled Out represents a Tim-accepted or actually rolled-out version. Finished requires Tim acceptance or explicit rollout evidence. Codex/TSF may not mark a track Finished / Rolled Out by itself.

Finished tracks are stable baselines and are not directly mutated. They may receive metadata/status notes, acceptance evidence, rollback references, and archive notes. Future work starts by creating a new Active / Development upgrade track derived from the finished baseline.

Example: Niners v1.0 remains Finished / Rolled Out while Niners v1.2 is Active / Development. Niners v1.2 points to v1.0 as its baseline; TSF does not blindly copy an entire repo to create the upgrade track.

## Paused, Archived, And Blocked

Paused means temporarily frozen and out of work selection until resumed. Archived / Parked means intentionally out of rotation while still visible for later revival. Blocked means TSF cannot continue without Tim, missing context, a known-fix route, or a safer packet.

Paused, Archived / Parked, Blocked, Finished / Rolled Out, and Ideas / Backlog tracks are not autonomous-eligible.

## Project Tracks And Versions

A project can have multiple tracks or versions at once. Track fields should include:

- project
- track/version
- section
- baseline
- end goal
- deadline
- priority
- definition of done
- validation
- blockers
- next milestone
- rollback target
- work eligibility

Additional implementation fields may later include `project_id`, `track_id`, `baseline_track_id`, `baseline_commit`, `branch`, `allowed_files`, `forbidden_files`, `mode_constraints`, `last_green_commit`, `last_review_status`, and `Tim_acceptance_required`.

Track duplication means creating a new active upgrade track from a finished baseline, not copying the entire repo blindly. Finished tracks stay immutable except for metadata/status notes.

## Assignments

Assignment is the main unit of Away Mode work. Internal tasks are subordinate to the assignment.

Assignment fields should include:

- project
- track
- end goal
- definition of done
- allowed files
- validation
- stop conditions
- priority
- mode eligibility
- next-assignment behavior

TSF should continue working until the current assignment's definition of done is met, or until it hits YELLOW/RED/BLOCKED. Numeric task, commit, and time limits are safety fuses only, not the primary stopping condition.

Assignment completion requires the assignment's definition of done and validation evidence. "Codex cannot think of more changes" does not equal complete. If the definition of done is vague, TSF must refine it first or stop YELLOW/BLOCKED instead of drifting.

When Assignment A completes GREEN, TSF may select Assignment B only if B is eligible. TSF must not jump to paused, archived, finished, blocked, idea-only, out-of-focus, unvalidated, or unsafe assignments. Focus Lock restricts assignment hopping to selected priority projects/tracks.

Active eligible assignments can be ordered by priority, deadline, and Focus Lock. Ideas / Backlog are not assignments until promoted. Finished tracks are not assignments unless a new active upgrade track is created. Review / Release Candidate work remains distinct from Finished / Rolled Out.

## Mode Switcher

TSF supports three human-availability modes:

- In-House Mode: Tim is present and actively improving code. TSF may ask questions as they arise, reroute interactively, and work through blockers with Tim while still obeying one project, one track, one task, allowed files, validation, and stop gates.
- Busy Mode: Tim is partly available. TSF should ask only meaningful blockers, batch questions, continue safe work when possible, and avoid risky work that needs frequent intervention.
- Away Mode: Tim is away. TSF may run only bounded preapproved assignment-completion loops, never an unbounded overnight runner, stop the current assignment on YELLOW/RED/BLOCKED, surface true blockers to Mobile HQ, and collect non-urgent questions in the Tim Question Queue. Away Mode can work through many internal tasks if they are necessary to finish the current assignment and all stop gates stay GREEN.

Mode changes are routing context, not safety exceptions.

## Autonomy Profiles

`docs/fleet/TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md` defines the V1 autonomy
profiles: `review_only`, `bounded_implementation`, `batch_implementation`, and
`away_safe`.

Autonomy profiles are execution-shape constraints, not approval. They determine
whether Codex may only review, patch one bounded task, work a bounded queue
slice, or continue an away-safe assignment slice. They do not approve product
repo mutation, archived project mutation, proof runs, push, deploy, package
installs, migrations, secrets, remote access, all-fleet, overnight runners,
phone execution authority, or runtime command binding.

## Work Eligibility

TSF can only work on eligible tracks. Eligible means all of these are true:

- section is Active / Development, or explicitly approved Review / Release Candidate work
- not Paused
- not Archived / Parked
- not Finished / Rolled Out
- not Blocked
- inside Focus Lock if Focus Lock is active
- exactly one selected project
- exactly one selected track
- exactly one selected task
- allowed files are known
- validation commands are known
- stop gates are known

Ideas, archived tracks, paused tracks, blocked tracks, finished tracks, vague goals without a task packet, tasks needing secrets/install/migration/remote access, and tasks requiring unapproved product repo mutation are not autonomous-eligible.

An assignment is eligible only when its project/track is eligible, its definition of done is clear, allowed files and validation are known, and its next-assignment behavior does not bypass Focus Lock or stop gates.

## Focus Lock And Pause Behavior

Focus Lock restricts TSF to selected priority projects/tracks during deadlines or high-priority windows. When Focus Lock is active, non-selected tracks are treated as temporarily out of rotation for automation.

Focus Lock does not approve unsafe actions, override validation, grant product repo access, approve proof runs, or permit push/merge/deploy.

Paused means do not select for work until resumed. Archived / Parked means intentionally out of rotation. Finished means stable accepted baseline, not mutable active work.

## Mobile HQ Request/Status Model

Phone HQ can request mode changes, pause/resume, priority changes, stop requests, upgrade-track creation, known-fix routes, status refreshes, idea capture, deadline/end-goal updates, and question responses.

Phone HQ remains request/status only. Phone requests are not execution authority. Static GitHub Pages cannot securely execute commands on the laptop.

Future mobile control requires a safe authenticated/local request bridge. TSF must validate every request locally before acting. Public dashboard output must not include client-side secrets, tokens, credentials, deploy keys, local absolute private paths, or private/customer data.

## Safe Request Bridge Constraints

The request bridge is future architecture, not implemented by this task.

Safe model:

1. Phone creates a typed request.
2. The request receives a request ID.
3. TSF locally ingests the request.
4. TSF validates mode, work eligibility, allowed files, validation, stop gates, and safety rules.
5. TSF acts only if the request is allowed, otherwise refuses or marks BLOCKED.
6. TSF writes audit/status evidence.

Unsafe model: a phone button directly runs shell commands. This is forbidden.

Any future bridge must preserve audit logs, request IDs, allowed action types, local validation, stop gates, refusal states, duplicate/replay protection where possible, and human-readable status. It must not accept arbitrary command payloads.

## Known-Fix Routes

A known-fix route is a narrow route for repeated, well-understood blockers. It is not general repair permission.

Each route must include:

- ID
- name
- fingerprint
- allowed files
- allowed commands
- validation
- forbidden actions
- stop conditions
- confidence level

Confidence levels:

- `auto-safe`
- `phone-requestable`
- `in-house-only`
- `forbidden/manual-only`

Known-fix routes require local validation before acting. Unknown blockers remain BLOCKED/YELLOW and require Tim or In-House Mode.

Example known fix: outer terminal/output timeout where the suite passes under log redirection. Safe response is rerun with log redirection, inspect the last completed section, report elapsed time and exit code, and never skip tests.

Example non-auto fix: missing product repo path on a new laptop. Safe response is mark path missing or request Tim's exact path/configuration; do not guess, broadly search, clone, mutate product repos, or run proof runs.

## Tim Question Queue

Away Mode should collect non-urgent questions instead of spamming Tim. Mobile HQ should show question count, blocker summaries, safe requestable fix routes, current mode, current focus lock, and last GREEN commit.

Question fields should include question ID, project/track, task, severity, mode, why TSF needs Tim, safe choices, default stop behavior, and deadline impact.

In-House Mode may ask immediately. Busy Mode should batch meaningful questions. Away Mode should collect questions and stop if needed.

## Deadline And End-Goal Planning

TSF can sketch deadlines, milestones, end goals, definitions of done, focus priorities, rollback targets, and uncertainty. It must label uncertainty.

A planned deadline is not approval to push, deploy, ship, mutate finished tracks, touch product repos, run proof runs, install packages, run migrations, configure remote access, store secrets, or bypass validation.

Deadline mode should prioritize selected active tracks, apply Focus Lock where appropriate, and pause nonessential work.

## WIP Limits

Away Mode:

- max one active project
- max one active track
- max one assignment at a time
- many internal tasks only when required by the assignment definition of done
- numeric task/commit/time limits are runaway safety fuses only
- stop after first blocker
- stop the current assignment after the first true blocker; if the approved run
  already selected another independent eligible project, record the blocker and
  continue to that next project
- no unbounded overnight or all-fleet behavior

Busy Mode may continue safe work and batch questions. In-House Mode may route more interactively but still obeys all hard safety boundaries.

## Status

This operating model is the architecture/spec baseline for later TSF implementation tasks. Later tasks may add project/track schemas, renderers, validators, registries, request inboxes, and dashboard sections only through bounded Fleet-only packets with tests.
