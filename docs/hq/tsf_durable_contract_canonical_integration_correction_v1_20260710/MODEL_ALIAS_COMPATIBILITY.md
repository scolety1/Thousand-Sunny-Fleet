# Model Alias Compatibility

Stable aliases are `FAST`, `BALANCED`, `DEEP`, `MAX_SINGLE`, and `PARALLEL`.

| Legacy input | Stable alias |
|---|---|
| `fast_readonly` | `FAST` |
| `standard_patch` | `BALANCED` |
| `deep_reasoning` | `DEEP` |
| `premium_audit` | `MAX_SINGLE` |

Requested alias, stable alias, resolved model, reasoning effort, and assurance are recorded separately. Unknown aliases and mission/policy conflicts fail closed. Model names remain replaceable values in the routing-policy file.
