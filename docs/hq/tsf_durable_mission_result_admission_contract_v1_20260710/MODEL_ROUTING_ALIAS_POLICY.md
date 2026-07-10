# Model Routing Alias Policy

Schemas expose only `FAST`, `BALANCED`, `DEEP`, `MAX_SINGLE`, and `PARALLEL`. Current product model names live in `fleet/control/model-routing-alias-policy.v1.json` and can change without changing schemas.

Assurance is evidence-based:

- `RECOMMENDED_ONLY`: TSF recommended but cannot observe.
- `USER_CONFIRMED`: operator confirmed.
- `ADAPTER_VERIFIED`: adapter observed.
- `TECHNICALLY_ENFORCED`: bounded launcher/platform control set and verified.

Unknown actual model values are honest and admissible with a caveat when no higher assurance is required. UI labels alone are not technical enforcement.
