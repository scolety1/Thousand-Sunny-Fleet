# UI Operator Truth

The operator surface separates:

- transport completion;
- worker status claim;
- structured fulfillment verification;
- admission and receipt state;
- original requested goal;
- authorized mission goal;
- result-contract class and eligibility;
- required, observed, and missing deliverables;
- exact next action.

Generic text uses a non-green caveat state:

> Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.

The response body remains displayed from the preserved worker claim. The UI shows `GENERIC_TEXT_RECEIVED_FULFILLMENT_UNVERIFIED`, `UNFULFILLED_GENERIC_TEXT_UNVERIFIED`, the non-admission reason, absence of a receipt, and the exact next action.

Subject-matter words such as “cannot,” “unable,” “failed,” or “blocked” do not create worker-failure styling. Closed worker status, verifier, and admission evidence control the presentation.

Recovery follows the same operator truth. A structured recovery displays fulfilled state only after the cloned source contract verifies and admits. A generic recovery displays the preserved response with the informational non-admission caveat, no success receipt, and no fulfilled presentation.
