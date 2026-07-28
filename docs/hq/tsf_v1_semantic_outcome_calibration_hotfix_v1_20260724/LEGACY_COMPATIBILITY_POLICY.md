# Legacy compatibility policy

Legacy behavior is deliberately fail closed.

- Empty freeform output becomes `REQUIRED_DELIVERABLE_MISSING`.
- Nonempty freeform output becomes `UNCLASSIFIED_RESULT`.
- Freeform prose is never scanned into an authoritative inability, refusal, policy, clarification, or success state.
- `tsf_worker_outcome_claim_v1` remains recognizable as `LEGACY_STRUCTURED_CLAIM_V1_FAIL_CLOSED`.
- A V1 claim cannot admit a new result.
- Exact-literal V1 remains mechanically validated and unchanged.

There is no fallback that treats transport success, a nonempty response, or worker-declared completion IDs as proof of fulfillment.
