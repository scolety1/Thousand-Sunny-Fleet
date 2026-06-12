# Model Routing Fixtures

Prepared: 2026-06-12

Evidence only; not executable authority or approval.

These fixtures describe expected policy decisions. They are not executable
commands and do not wire model routing into Codex Fleet runtime behavior.

## Fixture Matrix

| Fixture | qualityMode | Classifier | Recommended alias | Expected status |
| --- | --- | --- | --- | --- |
| read-only status review | `best_value` | scope read-only, risk low, ambiguity clear, validation strong, token pressure low, failure cost low | `fast_readonly` | GREEN |
| narrow docs test patch | `best_value` | scope narrow patch, risk low, ambiguity clear, validation strong, token pressure medium, failure cost moderate | `standard_patch` | GREEN |
| unclear security boundary | `best_value` | scope architecture, risk high, ambiguity high, validation partial, token pressure medium, failure cost high | `deep_reasoning` | YELLOW until repacketized |
| explicit perfect audit | `perfection` | scope audit, risk medium, ambiguity moderate, validation strong, token pressure high, failure cost high | `premium_audit` | GREEN if no blocked condition |
| unauthorized deploy request | `perfection` | scope product deploy, risk blocked, ambiguity clear, validation missing, token pressure any, failure cost unacceptable | none | RED |

## Required Invariants

- Use aliases only: `fast_readonly`, `standard_patch`, `deep_reasoning`, and
  `premium_audit`.
- Do not hardcode current model names.
- Do not include pricing claims.
- Do not call model APIs.
- Do not wire routing into live execution.
- Keep `best_value` and `perfection` as the only quality modes.
- Preserve one-task packets, `allowedFiles`, `validationCommands`, and `stopIf`.
- Preserve blocked conditions for secrets, unauthorized product repo access,
  deploy/merge/push, all-fleet, overnight runner, and broad authority.

## Example Classification

```text
request: update one Fleet doc and one Fleet test
qualityMode: best_value
recommendedModelAlias: standard_patch
reason: narrow patch, low risk, strong validation
stopIf: secrets, product repo access, deploy/merge/push, all-fleet, overnight runner, broad authority
```

## Preflight Helper Fixtures

```text
packet: docs/fleet/PRIVATE_LENS_CSV_VALIDATION_PROOF_TASK.md
qualityMode: best_value
expectedAlias: standard_patch
expectedStatus: GREEN
reason: bounded proof task with explicit allowed files and validation commands
```

```text
packet: synthetic blocked request
qualityMode: best_value
expectedAlias: none
expectedStatus: BLOCKED
reason: active deploy/merge/push, all-fleet, or broad-authority language must not be solved by model escalation
```

The helper output is recommendation-only. It does not execute tasks, mutate
task packets, configure Codex, or approve product work.
