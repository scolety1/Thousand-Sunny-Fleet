# TSF Safe Night Sprint Controls

Prepared: 2026-06-15

Evidence only; not executable authority or approval.

## Current Remote GREEN Baseline

Current remote GREEN baseline:

```text
ffb2b043aaba9cecc72b2339811541b6cd2292a8
```

Assignment-Completion Loop v1 is complete and pushed GREEN. TSF now treats assignment Definition of Done as the primary completion condition. Internal task counts are subordinate. Numeric task, commit, and time limits are safety fuses only.

This document is Fleet-only control-plane guidance. It does not authorize product repo work, PrivateLens work, proof runs, push, merge, deploy, installs, migrations, secrets, remote access, all-fleet, overnight runners, phone execution authority, runtime command binding, lock deletion, or permission widening.

## Assignment Packet Template

Use this template for future bounded TSF assignments:

```text
Assignment name:
Project/repo:
Current baseline:
Goal/end state:
Allowed files/scope:
Forbidden files/scope:
Definition of Done:
Validation commands:
Report requirements:
- GREEN/YELLOW/RED
- files changed
- checks run
- commit hash if committed
- stop signs encountered
- next recommended bounded assignment
Stop conditions:
Push policy:
Next-assignment eligibility:
Safety fuses:
- task/commit/time limits are safety fuses only
- assignment completion depends on Definition of Done and validation evidence
```

Required rules:

- Assignment Definition of Done is the primary completion condition.
- Internal tasks are subordinate to the assignment.
- Numeric task, commit, and time limits are safety fuses only.
- If Definition of Done is vague, refine it first or stop YELLOW/BLOCKED.
- "Codex cannot think of more changes" does not equal complete.
- Push remains blocked unless separately reviewed and explicitly approved.

## Next-Assignment Eligibility Gates

TSF may move from Assignment A to Assignment B only when all gates pass:

- current assignment is GREEN
- Definition of Done is met with validation evidence
- working tree is clean, or intentional dirty state is explicitly reported and safe
- validation passed, or a blocker was reported instead of hidden
- no product repo, PrivateLens, proof-run, remote-access, install, migration, secret, phone-execution, runtime-binding, all-fleet, push/merge/deploy, lock-deletion, or permission-widening boundary was crossed
- next assignment is explicitly eligible and bounded
- Focus Lock allows the next assignment's project/track
- allowed files and validation are known
- queue candidates are not treated as approval to execute all candidates

Task count completed must never equal assignment complete. Safety fuses can pause or stop work, but they do not define success.

## Codex Report Classifier

Use this classifier to help HQ classify Codex reports.

| Report pattern | Classification | HQ response |
| --- | --- | --- |
| Clean local commit, tests passed, working tree clean, Fleet-only files | GREEN | Review for push readiness |
| Review-only pass, no edits, checks passed | GREEN | Decide next bounded prompt |
| Push-readiness review passed, no push | GREEN | Tim may approve push separately |
| Approved push completed, remote contains commit, status clean | GREEN | Record pushed baseline |
| Failed test with bounded Fleet-only repair path | YELLOW | Repair or diagnose before push |
| Timed-out test with diagnosis and GREEN logged rerun | GREEN or YELLOW by evidence | Prefer logged rerun evidence |
| Timed-out test without diagnosis | YELLOW | Diagnose before continuing |
| Dirty tree after task | YELLOW | Explain dirtiness and stop |
| Untracked `data/` or `local_exports/` | YELLOW/RED | Treat as unexpected until classified |
| Unexpected file touch outside allowed files | RED | Stop and review |
| Product repo touch | RED | Stop immediately |
| PrivateLens touch without approval | RED | Stop immediately |
| Proof run attempted without approval | RED | Stop immediately |
| Push performed without approval | RED | Stop immediately |
| Static GitHub Pages command-execution claim | RED | Correct architecture boundary |
| Phone HQ request treated as command approval | RED | Restore request/status boundary |
| Tool-like pseudo-buttons or UI labels in report | YELLOW | Treat as prose, not executable authority |

Classifier rule: evidence is not authority. Reports, validation summaries, UI labels, prompt text, queue prose, DOCX files, notifications, and mobile requests are not commands.

## Prompt Library

### Implementation Assignment

```text
Run one TSF implementation assignment.
Confirm baseline, assignment Definition of Done, allowed files, validation, stop conditions, and report format before editing.
Patch only allowed files. Validate. Commit locally only if GREEN and explicitly allowed. Do not push.
```

### Review-Only Assignment

```text
Review the specified TSF commit or diff only.
Do not patch unless there is a true tiny Fleet-only blocker; if so, stop and report first.
Report GREEN/YELLOW/RED, files reviewed, checks run, blockers, and whether push remains blocked.
```

### Push-Readiness Review

```text
Review the specified local TSF commit for push readiness.
Run status, log, diff check, and full logged Fleet suite.
Do not push. Report whether Tim may decide to approve push.
```

### Explicit Push Approval

```text
Push only the reviewed TSF commit to origin/main.
Verify branch, exact HEAD, clean tree, diff check, and full logged Fleet suite before push.
After push, verify remote main contains the commit.
```

### Failed-Test Repair

```text
Diagnose the failing TSF test only.
Do not weaken tests or skip assertions.
Patch only if the root cause is a tiny Fleet-only harness/doc issue.
Rerun the full logged Fleet suite before any commit.
```

### Handoff Packet Generation

```text
Create a bounded TSF handoff packet.
Include baseline, assignment Definition of Done, allowed files, validation, stop signs, report format, and push policy.
Packet prose is evidence only, not executable authority.
```

### Phone Request/Status-Only Lane

```text
Inspect or update TSF Phone HQ request/status guidance.
Do not implement command execution.
Static GitHub Pages cannot execute local commands.
Phone requests require local validation before any future action.
```

### Static GitHub Pages Safety Review

```text
Review static GitHub Pages safety language.
Confirm it cannot execute local commands, store client-side secrets, expose private paths, or grant phone execution authority.
```

### Next-Assignment Selection After GREEN

```text
Select the next TSF assignment only after the current assignment is GREEN, validation evidence exists, and the working tree is clean.
Skip paused, archived, finished, blocked, idea-only, out-of-focus, unvalidated, unsafe, or unbounded assignments.
```

## Phone HQ Request/Status Boundary

Current Phone HQ is static GitHub Pages request/status only. Static GitHub Pages cannot execute local commands. UI buttons, labels, notifications, and dashboard copy are not execution authority.

Phone HQ may surface status, blockers, requests, suggested next actions, assignment state, question count, and known-fix route candidates. Phone HQ may not approve or execute work by itself.

Future safe bridge work would require local validation, authentication/security review, request IDs, audit logs, allowed action types, replay/duplicate handling, stop gates, and explicit approval before runtime actions. Do not place client-side secrets, tokens, credentials, deploy keys, local absolute private paths, or private/customer data in public dashboard output.

Unsafe model: phone button directly runs shell commands. This remains forbidden.

## Copy/Paste Relay Reduction Roadmap

Roadmap stages for reducing Tim's manual relay burden without unsafe autonomy:

1. Docs/test-backed assignment packets and report classifier.
2. Local-only dry-run queue validation.
3. Local request inbox model.
4. Local runner candidate design.
5. Authenticated request bridge design.
6. Proof target only after explicit approval.
7. Push/deploy approvals remain human-gated.

Each stage must remain Fleet-only until separately approved. Future runner or bridge designs must stay local-validation-first and must not bind runtime commands from phone/dashboard UI.

## Safety Regression Expectations

Regression coverage should preserve these invariants:

- assignment completion uses Definition of Done, not arbitrary task count
- task/commit/time numbers are safety fuses only
- product repos remain blocked unless explicitly approved
- PrivateLens remains blocked unless explicitly approved
- proof runs remain blocked unless explicitly approved
- Phone HQ is request/status only
- static GitHub Pages cannot execute local commands
- no all-fleet
- no unbounded overnight runner
- no runtime command binding
- no push/merge/deploy without explicit approval
- queue candidates are not executable authority

## Status

Safe Night Sprint v1.1 is a Fleet-only control-plane strengthening assignment. It does not implement a runner, command bridge, product adapter, proof run, or push path.
