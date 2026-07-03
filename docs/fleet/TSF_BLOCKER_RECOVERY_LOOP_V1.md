# TSF Blocker Recovery Loop V1

Prepared: 2026-07-03

Authority artifact for TSF-local control-plane behavior. This protocol does
not approve push, merge, deploy, installs, migrations, secrets/auth/payments,
PrivateLens work, product repo mutation, canonical repo mutation, public data
acquisition, background runners, all-fleet commands, model/ranking/formula
promotion, source-truth promotion, or app behavior changes.

## Purpose

TSF Blocker Recovery Loop V1 defines what Codex should do when a TSF lane hits
a blocker. The goal is to avoid both failure modes:

- safe-but-bureaucratic loops that keep documenting the same blocker
- unsafe force-through behavior that bypasses real authority gates

When TSF hits a blocker, it must first classify the blocker and run one bounded
safe recovery pass when that pass is inside current authority.

## Blocker Recovery Principle

Do not immediately force through.

Do not immediately create a dead-end blocker packet.

First classify the blocker. If it is not a true authority gate and a safe
bounded recovery path exists, build the artifact that removes, narrows, or
proves the blocker. If recovery needs a restricted action, stop and produce one
exact Tim approval request.

## Blocker Classes

Common blocker classes:

- `TRUE_AUTHORITY_GATE`
- `PRODUCT_REPO_GATE`
- `DATA_DISCOVERY_GAP`
- `SOURCE_PROVENANCE_GAP`
- `PROMPT_SCOPE_FLAW`
- `SCRIPT_LOGIC_FLAW`
- `VALIDATION_FAILURE`
- `TOOLING_ENVIRONMENT_GAP`
- `MISSING_LOCAL_DATA`
- `PUBLIC_DATA_REQUIRED`
- `INSTALL_REQUIRED`
- `CREDENTIAL_OR_SECRET_REQUIRED`
- `SCOPE_DRIFT`
- `UNSAFE_OPERATION_REQUESTED`
- `AMBIGUOUS_STATE`
- `ARTIFACT_PRESERVATION_NEEDED`

Use `docs/fleet/TSF_BLOCKER_CLASSIFICATION_MATRIX_V1.md` for the durable
classification table.

## Recovery Loop Steps

For non-authority blockers, run the loop once:

1. Freeze and preserve current state.
2. Record the exact blocker.
3. Classify the blocker.
4. Decide whether it is solvable under current approval.
5. Inspect local evidence/provenance before declaring anything missing.
6. Try one bounded safe recovery path.
7. Validate the result.
8. Compare against the original objective.
9. Produce one of:
   - recovered artifact
   - narrowed artifact
   - exact Tim approval request
   - RED stop report

The loop must produce an artifact. A second report that merely says `still
blocked` is not enough unless the blocker is a true authority gate.

## Hard Stop Rules

Stop immediately and ask Tim for exact approval if recovery requires:

- push
- merge
- deploy
- install
- migration
- secrets/auth/payment access
- PrivateLens access or mutation
- product repo mutation outside explicit approval
- canonical repo mutation
- external account changes
- public data acquisition not already approved
- background or persistent runner
- all-fleet command
- model/ranking/formula/source-truth promotion
- app behavior change

Do not wrap these as `safe recovery`. They are authority gates.

## Bounded Retry Rule

TSF may attempt at most one recovery rerun inside the same lane unless the user
explicitly approves more.

If the recovery rerun fails, stop the loop and produce a clear unblock artifact:

- exact Tim approval packet
- narrowed work order
- root cause report
- validation failure report
- source provenance map
- preserved packet
- comparison report

## Preservation Rule

Before cleanup, deletion, reset, or removal of any sandbox or generated output,
TSF must preserve useful artifacts and verify the preservation packet opens.

The preservation report must record:

- path preserved
- packet path
- contents verified
- checksum when easy
- exact cleanup path
- proof cleanup did not touch other files

Never use wildcard deletion for blocker recovery cleanup.

## Suspicious Failure Rule

If a result is suspiciously narrow compared with the target, investigate before
concluding failure.

Example:

- Target: 2000-2025 historical coverage.
- Found: only 4 seasons.
- Required response: source/provenance discovery, not immediate `missing data`
  conclusion.

Suspiciously narrow results require a provenance artifact or clear explanation
of why broader discovery is impossible under current authority.

## Recovery Artifact Requirement

Every blocker recovery pass must produce a concrete artifact, such as:

- root cause report
- provenance map
- validation report
- preserved zip
- narrowed work order
- exact authority request
- comparison report

If no artifact can be produced, classify the lane as RED or TIM_REQUIRED and
stop.

## Tim Escalation Format

When Tim is truly needed, ask for one exact approval line instead of vague
permission.

Example:

```text
Tim approves one duplicate-only public nflverse data acquisition/import lane
for this sandbox only. Canonical repo must not be modified. No model tuning,
ranking changes, app wiring, source-truth promotion, push, merge, install,
deploy, migration, secrets, or PrivateLens.
```

The approval packet should also name repo/path, branch or baseline, allowed
commands or source class, max scope, stop conditions, and expiry.

## Anti-Loop Language

- Do not repeatedly prove `not approved yet`.
- Do not produce blocker packets when a safe recovery artifact can be built.
- Do not escalate normal discovery/debugging to Tim.
- Do not bypass true authority gates.
- Do not confuse safe YELLOW evidence with complete progress.
- Do not keep running recovery attempts after the bounded retry is exhausted.

## Worked Example: NWR Historical Foundation

Original issue:

- `DATA_DISCOVERY_GAP`
- `SOURCE_PROVENANCE_GAP`
- `PROMPT_SCOPE_FLAW`

Wrong behavior:

- Report partial historical coverage after checking only four hard-coded local
  artifacts.

Correct behavior:

1. Preserve the old partial packet.
2. Delete only the old sandbox after validation.
3. Diagnose the shallow source discovery root cause.
4. Create a fresh duplicate sandbox.
5. Add source discovery and provenance.
6. Rerun safely.
7. Compare against independent NWR evidence.
8. Escalate public data acquisition only when it is proven necessary.
9. Reach parity after exact Tim approval, without model/ranking/app/source-truth
   changes.

Final result:

- TSF reached 2000-2025 parity after exact public acquisition approval.
- The packet remained review/candidate evidence.
- Canonical NWR stayed unchanged.
- 2025 bridge and Matthew Stafford 2010 week 8 duplicate caveats stayed
  documented.

## Final Rule

Blocker recovery should convert stuck lanes into evidence, artifacts, or exact
authority requests. It should not create bureaucracy, and it should not cross
authority boundaries.
