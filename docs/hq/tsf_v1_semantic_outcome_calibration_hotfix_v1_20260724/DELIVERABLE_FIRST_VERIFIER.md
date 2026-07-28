# Deliverable-first verifier

`tsf_task_completion_contract_v2` defines a profile and, for each mandatory deliverable:

- ID;
- type;
- minimum and maximum cardinality;
- structure rule;
- content path;
- evidence-reference requirement.

`TEXT_RESPONSE_V2` requires one substantive `requested_answer`. `STRUCTURED_ANALYSIS_V2` requires `summary`, at least three `findings`, nonempty `evidence_references`, and `limitations`.

The verifier derives observed deliverables from `substantive_answer`. It then checks:

1. mission/revision/run and intent/scope/task identity;
2. the closed worker-own status relationship;
3. the exact required-deliverable partition;
4. content-derived observed and missing deliverables;
5. type, cardinality, bounded structure, and evidence;
6. worker claim versus verifier observation;
7. accepted disposition and partial-completion policy.

Admission recomputes the same assessment from the bound mission contract and durable result. It rejects disagreement in observed deliverables, missing deliverables, disposition, or evidence.
