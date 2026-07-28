# Generic Text Non-Admission Policy

For new verification and replay, generic text:

- preserves transport status and the raw worker response hash;
- preserves the closed worker claim when present;
- exposes structurally observed content;
- uses compatibility mode `STRUCTURAL_TEXT_ONLY_V2`;
- validates as a canonical `tsf_general_result_v2` informational result under the closed governing schema;
- adds `GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE`;
- maps affirmative generic claims to `UNCLASSIFIED_RESULT`;
- always sets semantic success and admissibility false.

An excellent-looking answer and a worker-supplied `FULFILLED` value are not verifier or admission authority.

Generic inability-looking prose is not scanned into worker failure. When the closed worker-status fields themselves report inability, the status remains visible, but admission still fails.

Exact next action: create a new mission with an exact or mechanically verifiable structured result contract when admitted fulfillment is required.

Schema compatibility describes representation only. It grants no semantic success, verifier GREEN, admission, or receipt authority.
