# Audit Loop Mode Spec

## Definition

Audit Loop Mode, also called External Review Loop Mode, is an optional and opt-in Codex Fleet workflow. It helps a project use repeatable external audits without turning every Fleet run into an audit-driven process.

This spec is based on the HouseOS Customer Website Builder loop as a pattern library and case study. The pattern is useful, but HouseOS-specific product rules must stay local to HouseOS unless a captain explicitly adapts them for another project.

## When To Use It

Use Audit Loop Mode when:

- A project benefits from independent review after bounded implementation slices.
- The captain wants compact audit packages instead of a massive repo dump.
- The audit findings can be converted into short, focused tasks.
- The work has clear checks, proof, and stop conditions.
- The project can safely pause between tasks for review.

Do not use it when:

- The work is tiny enough to finish directly.
- The project has no useful external-review artifact.
- The captain needs live product judgment before any implementation.
- The audit would require secrets, production data, or private customer material.
- The result would be a nested loop of audits about audits with no product progress.

## Reusable Workflow Primitives

- Compact audit package: a zip with high-signal docs, source snapshots or diffs, evidence, checks, and a manifest.
- External audit prompt: a read-only prompt telling the reviewer what to inspect, what is out of scope, and how to report findings.
- Audit report: a verdict plus prioritized, actionable issues.
- Queue converter: a safe translation step from audit findings into a bounded task queue.
- One-task executor: a repeatable prompt pattern that executes exactly one queue item with a focused check.
- Proof record: task status, files changed, checks run, and remaining blockers.
- Accepted limitations: known caveats that should not be converted into repeat tasks.
- Stop rules: criteria for ending the loop when no actionable work remains.

## HouseOS-Specific Boundaries

The following HouseOS-specific details should stay local to the HouseOS/customer-website project and should not become global Fleet policy:

- Customer Website Builder product rules.
- PublicRestaurantData or `getPublicRestaurantData` assumptions.
- Customer, Manager, and Staff surface names.
- RestaurantConfig or SharedRestaurantRecord data shapes.
- Restaurant-specific CTA, menu, image, and hero rules.
- HouseOS file paths, reference sites, scripts, and test names.
- The exact 20-file audit package limit, which is a delivery constraint, not a universal quality rule.
- Commit cadence rules that only make sense for that repo.

Fleet may reuse the loop mechanics, not the product identity.

## Metadata Fields

Each project that opts into Audit Loop Mode should declare metadata before packaging or queue conversion:

- `projectName`: human-readable project name.
- `repository`: repo root or selected harness fixture.
- `surfaces`: all known surfaces for the project.
- `inScopeSurfaces`: surfaces included in this audit loop.
- `safeDataSources`: files or fixture data allowed in packages.
- `forbiddenDataSources`: secrets, production data, customer data, generated output, or private local files to exclude.
- `auditPackageFiles`: explicit high-signal files to include.
- `defaultChecks`: focused commands expected after implementation tasks.
- `maxTasks`: maximum tasks allowed from one audit report.
- `acceptedLimitations`: known caveats that should not cause repeated work.
- `ownerContact`: captain or owner note for ambiguous decisions.
- `riskTier`: fixture, safe-demo, product-demo, or sensitive.
- `requiresCaptainApproval`: whether queue conversion or execution needs approval.

## Task Queue Format

Audit-loop tasks should be small enough to run one at a time. A task should include:

- `id`
- `title`
- `dispatchPhrase`
- `goal`
- `readList`
- `workList`
- `acceptanceCriteria`
- `requiredChecks`
- `commitExpectation`
- `riskLevel`
- `notes`
- `stopIf`
- `proof`

The queue converter should reject vague tasks such as "fix everything from the audit" or tasks that bundle unrelated product, safety, and design changes together.

## Audit Package Contents

A compact audit package should include:

- Package README.
- Manifest with hashes and included paths.
- Current queue and recent completed task proof.
- Standard run evidence or task evidence.
- Relevant source snapshots or sanitized diffs.
- Scope and safety metadata.
- Accepted limitations.
- Focused check transcripts.
- External audit prompt.
- Any product-specific docs explicitly declared in metadata.

The package should not include `.git`, `.env`, secrets, raw locks, dependency folders, build output, private user files, or undeclared product repos.

## External Prompt Rules

The external audit prompt should tell the reviewer:

- Treat the package as read-only.
- Do not edit code.
- Do not invent product requirements outside the declared scope.
- Separate package completeness, implementation completeness, evidence completeness, and safety concerns.
- Return a verdict: `Ready`, `Ready with caveats`, or `Not ready`.
- Prioritize actionable issues.
- Name missing checks.
- Identify repeatability gaps.
- Respect `maxTasks`.
- Mark accepted limitations as non-blocking unless new evidence changes the risk.

## Stop And Continue Rules

Continue the loop only when the audit returns actionable, bounded issues that are inside declared scope and have clear checks.

Stop the loop when:

- The verdict is `Ready`.
- The verdict is `Ready with caveats` and the caveats are accepted limitations.
- Remaining issues require captain taste, product strategy, credentials, or private data.
- The same accepted caveat appears again after it was documented.
- The audit recommends broad rewrites, undefined polish, or out-of-scope work.
- Focused checks pass and no new concrete issue is present.

## Anti-Loop Criteria

Anti-loop rules are required because an audit loop can otherwise keep generating work forever.

- Do not create a new task from a repeated accepted limitation.
- Do not re-audit only to ask whether the previous audit was valid.
- Do not run more than the declared `maxTasks` from one report.
- Do not convert subjective preference into implementation without captain approval.
- Do not allow nested "audit the audit package" tasks unless package evidence is genuinely missing.
- Do not continue after two consecutive audit cycles produce no new actionable issue.
- Do not let the loop overwrite the normal done contract for the project.

## Safety Boundaries

Audit Loop Mode cannot bypass Codex Fleet safety rules:

- No real product repo work unless explicitly selected and allowed by policy.
- No merge, push, deploy, or destructive cleanup.
- No secrets, auth, payments, deployment, migrations, or dependency changes unless a later approved process allows them.
- No phone or external reviewer command may execute directly.
- Local validation must still approve scope, state, budget, safety, and evidence before any action.

## Minimal Generalized Loop

The smallest reusable version is:

1. Select one project and declare audit-loop metadata.
2. Build a compact package from declared files and evidence.
3. Send a read-only external prompt.
4. Convert structured findings into no more than `maxTasks`.
5. Run exactly one task with a focused check.
6. Record proof in the queue.
7. Repeat only while new actionable issues remain.
