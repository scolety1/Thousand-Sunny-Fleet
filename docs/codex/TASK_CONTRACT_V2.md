# Task Contract V2

Task Contract V2 is the fleet's compact task grammar for unattended work. It borrows the useful part of agent-skills: explicit workflow, small slices, proof requirements, and named stop conditions.

## Required Fields

Every new implementation task should include these fields in the checklist line:

- `User pain:` the concrete confusion, wasted time, broken workflow, missing trust, or blocked demo value.
- `Skill:` or `Workflow:` the primary skill from `FLEET_SKILL_MAP.md`.
- `Target:` exact owned files, routes, modules, docs, tests, or directories.
- `Change:` the one behavior, layout, formula, copy, test, report, or route change.
- `First screen:` required for UI/product tasks.
- `Remove/simplify:` required for repair, shape, polish, design, copy, and visible work.
- `Guardrails:` forbidden scope and any phase/admission/usefulness boundary.
- `Acceptance:` exact build, static check, test, or docs-only acceptance.
- `Proof:` expected evidence artifact, report, screenshot, route check, fixture output, or review packet.
- `Stop if:` the condition that should halt or quarantine instead of improvising.
- `Check:` the human-readable usefulness check.
- Metadata: `[class:<type> risk:<level> mode:<single|feature-pack> impact:<standard|visible|showpiece> surface:<public|app|internal|mixed> scope:<paths> accept:<commands>]`.

## Allowed Docs-Only Work

Docs-only tasks are allowed only when they are planning, proof, review, or parking tasks. They must say what decision or evidence they produce.

Good docs-only examples:

- `class:planning impact:standard` with `Skill: planning-and-task-breakdown`
- `class:proof impact:standard` with `Skill: code-review-and-quality`
- simple documentation maintenance with `class:docs impact:standard` only when it is not pretending to be product progress

Bad docs-only examples:

- visible task with only `docs/codex/` scope
- design/showpiece task that produces only a report
- broad planning task that says "make it better" without acceptance or stop conditions

## Visible Product Work

Visible/product tasks must:

- name at least one product surface scope such as `src/`, `app-vNext/src/`, `public/`, `content/`, `styles/`, `index.html`, or route/component files
- include exactly one `surface:` metadata value
- include `First screen:` when impact is visible/showpiece or class is feature/design/copy
- include `Acceptance:` with a build or local static check
- include `Proof:` with a visual, route, review, or report artifact
- include `Stop if:` for build failure, scope conflict, sensitive-system risk, repeated quality loop, or missing evidence

## Rejection Rules

The harness should reject, quarantine, or at least mark blocked before implementation when:

- a visible/product task has docs-only scope
- a visible/product task lacks a first-screen rule
- a feature-pack task lacks approved planning, scope, and acceptance
- a high/gated task lacks architecture approval
- a backend/integration task lacks API contract approval
- a sensitive-system task lacks sensitive-system policy approval
- a migration task lacks migration and fixture evidence
- a V2 task declares one of `Skill`, `Proof`, or `Stop if` but omits the others

## Example

```md
- [ ] User pain: mobile managers still cannot see the next action quickly enough. Skill: frontend-ui-engineering. Target: src/pages/App.tsx, src/styles.css. Change: tighten the quick-action card so the shift decision and one action appear before secondary module detail. First screen: next shift action, module context, and the quick action stay dominant. Remove/simplify: one repeated label or cramped secondary chip. Guardrails: no backend, auth, payments, APIs, analytics, dependencies, deployment config, generated output, real restaurant data, or unrelated files. Acceptance: npm.cmd run build. Proof: mobile route check and NIGHTLY_REPORT.md note. Stop if: build fails, guest/internal copy leaks, or the change needs new backend behavior. Check: a manager can name the next action in under 10 seconds. [class:design risk:low mode:single impact:visible surface:mobile scope:src/ accept:npm.cmd run build]
```
