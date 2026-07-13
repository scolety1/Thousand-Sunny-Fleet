# Static Catalog

Baseline: `REVIEW_ONLY_REFERENCE_NOT_RUNTIME_ENFORCED`

The versioned catalog is `fleet/reference/plugin-catalog-risk-v1/plugin-catalog.v1.json`, isolated from runtime control files and validated against `plugin-catalog.schema.v1.json` plus the dedicated static suite.

## Counts

| Measure | Count |
|---|---:|
| Total unique seed records | 36 |
| User-reported AVAILABLE / NOT_INSTALLED | 8 |
| User-reported DISCOVERED / installation UNKNOWN | 28 |
| OPAQUE_QUARANTINED | 6 |
| Runtime observations | 0 |
| Records granting authority | 0 |
| Records claiming operational verification | 0 |

The six quarantined records are Alpaca and these five opaque IDs:

- `app-68d579f7b0948191a7da3124a3b560f`
- `app-68de829bf7648191acd70a907364c67c`
- `app-69949aa62bf48191be5e57a01202beca`
- `app-69a8f78087e081919e52cacacf00ff36`
- `app-69d319ffb64c8191a1c1abcd30fae202`

Every record has source quality and confidence `USER_SUPPLIED_UNVERIFIED`. Every publisher, version, manifest SHA-256, permission scope, authentication requirement, network requirement, and likely surface value remains `null`; connection, host availability, current enablement, and capability-probe status remain `UNKNOWN`. Risk tier is `UNKNOWN` because permissions and operating behavior were not verified.

Likely capability categories, project relevance, overlap groups, and sensitivity are static review labels only. They are not manifest claims, operational observations, runtime requirements, or selections.

## Primary classification counts

| Classification | Count |
|---|---:|
| TSF_CORE_REQUIRED_CANDIDATE | 3 |
| TSF_CORE_OPTIONAL_CANDIDATE | 1 |
| PROJECT_SPECIFIC_CANDIDATE | 7 |
| ARTIFACT_CAPABILITY | 7 |
| SENSITIVE_CONNECTOR_MISSION_ONLY | 12 |
| OPAQUE_QUARANTINED | 6 |

The full classification vocabulary also defines research, review, experimental, overlap, high-risk-last-resort, and unsafe/rejected labels for future manual classification without implying runtime use.
