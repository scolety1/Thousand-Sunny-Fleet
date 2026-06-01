# External Agent Roles

External agents are reviewers, not executors. They may inspect audit packages and return findings, questions, or structured task-packet suggestions. They must not edit repos, run ships, bypass validation, merge, push, deploy, delete locks, or approve sensitive work.

## Issue Auditor

- Purpose: find bugs, failed gates, missing evidence, stalls, unsafe states, and model-budget waste.
- Best input: audit package, `RUN_RESULT.json`, `EVIDENCE_INDEX.md`, wrapper reports, test output.
- Use for: broken runs, RED/YELLOW status, suspicious readiness claims.
- Do not use for: pure taste choices after deterministic checks pass.

## Improvement Auditor

- Purpose: suggest small useful upgrades that improve autonomy, reliability, or product quality.
- Best input: audit package plus current roadmap/checkpoint docs.
- Use for: next-stage planning and reducing stalls.
- Do not use for: broad rewrites or unsafe product repo changes.

## Product Taste Auditor

- Purpose: review first-screen clarity, hierarchy, copy, mobile fit, progressive disclosure, and demo usefulness.
- Best input: screenshots, product-quality evidence, first-screen contract, demo promise.
- Use for: final captain/taste review support after deterministic gates pass.
- Do not use for: recovering broken builds, missing evidence, or unsafe code.

## Formula Auditor

- Purpose: review model correctness, deterministic formulas, fixtures, assumptions, tests, and fake-confidence risks.
- Best input: formula docs, fixtures, expected outputs, test transcripts.
- Use for: analytical tools and scoring systems.
- Do not use for: visual polish unless the analytical output is already proven.

## Security Scope Auditor

- Purpose: check secrets, auth, payments, deployment, migrations, dependencies, forbidden paths, and scope expansion.
- Best input: diffs, runtime-scope policy, task packets, validation reports.
- Use for: any high-risk suggestion or external packet that touches sensitive areas.
- Do not use to approve sensitive work directly.

## Tie-Breaker Auditor

- Purpose: compare conflicting reports and recommend the safest validated plan.
- Best input: two or more external audit reports plus the original package.
- Use for: disagreement, duplicate suggestions, or taste conflict.
- Do not use to override runtime safety rules.

