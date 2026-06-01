# Product Quality Evidence Fields

Purpose: define how product-quality evidence should appear in run evidence later.

Suggested `RUN_RESULT.json` fields:
```json
{
  "productQuality": {
    "demoPromiseStatus": "PASS_WITH_NOTES",
    "firstScreenStatus": "PASS",
    "informationHierarchyStatus": "PASS",
    "simplicityGateStatus": "PASS_WITH_NOTES",
    "mobileStatus": "PASS",
    "doneContractStatus": "NOT_DONE",
    "tasteGateStatus": "UNKNOWN",
    "productQualityDecisionHint": "RUN_AGAIN",
    "screenshots": [
      "screenshots/mobile-first-screen.png"
    ],
    "reviewerNotes": [
      "Primary job is clear; secondary setup flow still needs staging."
    ]
  }
}
```

Statuses:
- PASS
- PASS_WITH_NOTES
- FAIL
- FAIL_OVERLOADED
- NEEDS_TASTE_REVIEW
- UNKNOWN
- NOT_APPLICABLE

Decision notes:
- `FAIL` or `FAIL_OVERLOADED` should prevent taste-gate success.
- `NEEDS_TASTE_REVIEW` should map to `USER_TASTE_GATE` once deterministic gates pass.
- `UNKNOWN` should not automatically block analytical/backend-only ships when product surfaces are not relevant.

## Stage 8 Consumption Note

Stage 8 should treat `productQuality` as advisory evidence for the autonomy
wrapper after deterministic gates have run. It should not use product-quality
fields to bypass build, test, scope, packet-validation, lock, or safety checks.

Example `RUN_RESULT.json` fragment:

```json
{
  "status": "GREEN",
  "decisionHint": "RUN_AGAIN",
  "productQuality": {
    "demoPromiseStatus": "PASS_WITH_NOTES",
    "firstScreenStatus": "PASS",
    "informationHierarchyStatus": "PASS_WITH_NOTES",
    "simplicityGateStatus": "PASS",
    "mobileStatus": "PASS",
    "doneContractStatus": "NOT_DONE",
    "tasteGateStatus": "UNKNOWN",
    "productQualityDecisionHint": "RUN_AGAIN",
    "screenshots": [
      "out/screenshots/customer-mobile-first-screen.png",
      "out/screenshots/customer-desktop-list-view.png"
    ],
    "reviewerNotes": [
      "The first screen has a clear primary promise.",
      "The helper flow is staged behind a secondary action instead of dumped into the first screen."
    ]
  }
}
```

Stage 8 decision mapping:

| Product-quality evidence | Wrapper decision influence |
|---|---|
| `demoPromiseStatus`, `firstScreenStatus`, or `informationHierarchyStatus` is `FAIL` | Prefer `BLOCK` or a repair task before another normal run. |
| `simplicityGateStatus` is `FAIL_OVERLOADED` | Prefer `BLOCK` or repair; do not park or taste-gate an overloaded screen. |
| `mobileStatus` is `FAIL` for customer-facing hospitality or local-business website lanes | Prefer repair before `PARK`; mobile is part of done for those lanes. |
| `doneContractStatus` is `NOT_DONE` and other deterministic gates pass | Prefer `RUN_AGAIN` if there are scoped remaining tasks. |
| `doneContractStatus` is `DONE` or `DONE_WITH_NOTES` and `tasteGateStatus` is `PASS` or `NOT_APPLICABLE` | Prefer `PARK`. |
| `tasteGateStatus` is `NEEDS_TASTE_REVIEW` and deterministic gates pass | Prefer `USER_TASTE_GATE`; do not keep polishing automatically. |
| `productQualityDecisionHint` is `RUN_AGAIN`, `PARK`, `USER_TASTE_GATE`, or `BLOCK` | Use it as the product-quality vote, then let the Stage 8 wrapper combine it with safety, scope, budget, and state-machine rules. |

If product-quality fields conflict, Stage 8 should choose the most conservative
safe action in this order: `BLOCK`, `USER_TASTE_GATE`, `RUN_AGAIN`, then `PARK`.
