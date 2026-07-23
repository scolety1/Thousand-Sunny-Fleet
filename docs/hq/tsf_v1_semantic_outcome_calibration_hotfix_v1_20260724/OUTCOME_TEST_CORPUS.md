# Outcome test corpus

Canonical corpus:

`tests/fixtures/fleet/semantic-outcome/semantic-outcome-corpus.v1.json`

Runner:

`tests/Test-TsfSemanticOutcomeCalibrationV1.ps1`

Observed working-tree result:

`TSF_SEMANTIC_OUTCOME_CALIBRATION_PASS assertions=134`

Coverage includes:

- 20 worker-own contraction, passive, and indirect non-success statements;
- 12 fulfilled historical, normative, quoted, hypothetical, other-actor, JSON, code, blockquote, and requirement cases;
- fulfilled status with worker-own incompletion;
- missing deliverable;
- partial with all deliverables;
- substantive unable explanation;
- wrong task;
- V1 structured legacy claim;
- freeform legacy output;
- four-field structured analysis success and missing evidence-reference failure;
- bounded substantive-answer and evidence-reference rejection;
- UI verifier/admission truth guards.

All outcome expectations are driven by structured fields and deliverable observation, not answer-text classification.
