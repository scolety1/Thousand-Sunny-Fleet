# Fleet Skill Map

The fleet uses skills as the work discipline inside each checkpoint task. Skills do not replace the fleet harness; they tell each worker which engineering workflow to follow while the harness still handles project selection, locks, safe stops, launch shape, reports, and GitHub remote control.

## Phase To Skill Mapping

| Fleet phase | Primary skill | Supporting skills | Use when |
| --- | --- | --- | --- |
| brief | spec-driven-development | idea-refine, documentation-and-adrs | The goal or product promise is still unclear. |
| foundation | planning-and-task-breakdown | context-engineering, documentation-and-adrs | The repo needs bounded implementation slices. |
| shape | incremental-implementation | frontend-ui-engineering, code-review-and-quality | A product surface needs one visible, reviewable change. |
| simplicity | code-simplification | code-review-and-quality, frontend-ui-engineering | The existing surface should be easier to scan or maintain. |
| polish | frontend-ui-engineering | browser-testing-with-devtools, accessibility-checklist | A visible UI/detail pass is needed after the core shape exists. |
| proof | code-review-and-quality | browser-testing-with-devtools, debugging-and-error-recovery | The ship needs evidence, checks, reports, or one blocker fix. |
| parked | shipping-and-launch | documentation-and-adrs, code-review-and-quality | The ship should be left clean with clear review guidance. |
| repair | debugging-and-error-recovery | incremental-implementation, code-review-and-quality | Supervisor, Simon, Robin, Joey, visual, build, or staging checks are blocking. |
| problem-brief | spec-driven-development | documentation-and-adrs | Analytical work needs a user problem and non-goals before formulas. |
| data-contract | api-and-interface-design | test-driven-development | Data boundaries, schemas, fixtures, or public contracts need proof. |
| formula-spec | source-driven-development | test-driven-development | Formula behavior needs source-backed definitions before code. |
| fixture-tests | test-driven-development | debugging-and-error-recovery | Fixtures and golden cases need to guard future implementation. |
| engine-build | incremental-implementation | test-driven-development, performance-optimization | Analytical engine work is approved and sliced. |
| calibration | performance-optimization | test-driven-development, documentation-and-adrs | Model/formula output needs measured comparison or tuning. |
| dashboard | frontend-ui-engineering | accessibility-checklist, performance-optimization | Analytical results need a clear user-facing surface. |
| scenario-tools | api-and-interface-design | incremental-implementation, test-driven-development | Users need bounded scenario controls or what-if inputs. |
| analysis-proof | code-review-and-quality | documentation-and-adrs, source-driven-development | The analytical ship needs final evidence and known-risk reporting. |

## Workflow Rules

- Every generated task should name one primary `skill:` or `workflow:`.
- The skill tells the worker how to move, not what files it may touch. File authority still comes from `target:`, `scope:`, project guardrails, and the launch gate.
- Visible/product tasks should usually use `incremental-implementation`, `frontend-ui-engineering`, `code-simplification`, or `debugging-and-error-recovery`.
- Planning/proof tasks may be docs-only only when the class and workflow say so.
- Security, auth, payments, external APIs, migrations, package/dependency files, deployments, or sensitive data must use the relevant gated skills and approval docs before implementation.

## Default Skill Inference

If a legacy task does not name a skill, the harness may display an inferred workflow:

- `class:design` or `impact:visible/showpiece`: `frontend-ui-engineering`
- `class:copy`: `code-review-and-quality`
- `class:bugfix`: `debugging-and-error-recovery`
- `class:test`: `test-driven-development`
- `class:docs`: `documentation-and-adrs`
- `class:backend` or `class:integration`: `api-and-interface-design`
- `class:migration`: `deprecation-and-migration`
- otherwise: `incremental-implementation`

Inference is for reporting and compatibility. New tasks should state the skill explicitly.
