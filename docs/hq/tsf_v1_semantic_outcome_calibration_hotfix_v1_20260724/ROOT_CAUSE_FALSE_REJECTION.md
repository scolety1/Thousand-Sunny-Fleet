# Root cause: false rejection

The same answer classifier confused subject matter with execution status. Historical descriptions, direct quotations, normative prohibitions, hypothetical examples, JSON strings, code samples, and another actor's inability could all contain phrases such as “cannot,” “could not,” or “unable.”

Because those phrases appeared in `answer`, a truthful affirmative worker claim could be rewritten as inability even when the requested analysis and every deliverable were complete.

The V2 boundary treats `substantive_answer`, `evidence`, and `caveats` as content only. No outcome regex is applied to them. The verifier instead checks closed status fields, identities, types, cardinalities, structure, evidence references, and observed deliverables.
