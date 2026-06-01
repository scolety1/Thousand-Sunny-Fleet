# Stage 9 Phase 1 Prompt: External Review Roles

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 1 only: External Review Roles.

Goal:
Define the standard external audit roles for Codex Fleet.

Create role docs for:
- Issue Auditor: finds bugs, failures, blockers, and safety risks.
- Improvement Auditor: suggests useful next upgrades.
- Product Taste Auditor: reviews clarity, hierarchy, copy, and demo usefulness.
- Formula Auditor: reviews analytical/model correctness and fake-confidence risks.
- Security / Scope Auditor: checks secrets, auth, payments, deployments, dependencies, and forbidden scope.
- Tie-Breaker Auditor: compares conflicting reports and chooses the safest next plan.

Each role doc should include:
- purpose
- best input package
- what to inspect
- what not to do
- expected output
- when to use this role
- when not to use this role

Guardrails:
- Do not implement agent calls.
- Do not modify fleet scripts.
- Do not touch downstream product repos.
- External agents are reviewers, not executors.

Acceptance:
- Role docs exist.
- Each role has a clear use case.
- The docs explain which roles are useful for website, product, formula, and security work.

Proof:
Show created role doc paths and summaries.
```

## Notes

This phase gives the user reusable audit lanes instead of one giant vague review.

## Implementation Status

Status: GREEN

Implemented in `docs/templates/external-agent-workflow/roles.md` and `tools/codex-fleet-external-agent.ps1`.
