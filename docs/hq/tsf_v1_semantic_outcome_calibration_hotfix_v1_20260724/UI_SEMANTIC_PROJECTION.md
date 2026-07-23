# UI semantic projection

The operator UI now separates:

- worker transport and lifecycle status;
- closed worker claim (`task_attempted`, `task_completed`, disposition, blocked reason, completed/missing IDs, caveats);
- observed and missing deliverables;
- canonical semantic outcome;
- verifier;
- preservation and admission.

The worker claim is labeled non-authoritative. A GENERAL_RESULT_V2 fulfilled label requires:

- canonical semantic status `FULFILLED`;
- verifier `GREEN`;
- admission `ADMITTED` or `ADMITTED_WITH_CAVEATS`.

An affirmative worker claim without those gates is presented as `FULFILLMENT_NOT_ADMITTED`. Inability, missing deliverables, and legacy ambiguity remain unfulfilled. Transport completion is never displayed as fulfillment.

Observed responsive/accessibility proof: 1,086 assertions at 320, 375, 390, 768, and 1180 pixels with zero page-overflow, clipped-control, and unlabeled-control failures.
