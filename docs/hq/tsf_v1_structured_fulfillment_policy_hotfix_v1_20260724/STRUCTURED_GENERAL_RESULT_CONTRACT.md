# Structured GENERAL_RESULT_V2 Contract

The admissible analytical profile is `STRUCTURED_ANALYSIS_V2`, classified as `STRUCTURED_DETERMINISTIC` and `ADMISSIBLE_WHEN_VERIFIED`.

Required deliverables are closed before execution:

| ID | Type | Cardinality | Structural rule |
|---|---|---:|---|
| `summary` | string | 1 | substantive bounded text |
| `findings` | string array | 3–20 | bounded nonempty strings |
| `evidence_references` | string array | 1–20 | bounded nonempty strings |
| `limitations` | string | 1 | bounded nonempty text |

Admission also requires a closed outcome claim, matching mission/revision/run, task, original-intent, and scope identities, a complete deliverable partition, required evidence, accepted structured status, successful transport, independent verifier confirmation, and the existing preservation/admission gates.

The verifier checks structure and relationships. It does not interpret unrestricted answer prose as worker status.
