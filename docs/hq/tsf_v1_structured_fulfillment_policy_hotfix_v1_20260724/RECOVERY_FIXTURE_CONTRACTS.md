# Recovery Fixture Contracts

## Architecture classification

`RECOVERY_SUCCESS_FIXTURE_USES_NON_ADMISSIBLE_GENERIC_TEXT`

The preserved blocker was caused by a test fixture, not by the recovery,
verifier, preservation, admission, or UI runtime. The former success fixture
requested generic `TEXT_RESPONSE_V2`, explicitly confirmed its
`INFORMATIONAL_NON_ADMISSIBLE` selection, and later asserted canonical
admission.

Recovery correctly preserves the source mission's result contract. It must
not silently upgrade generic text to an admissible contract because doing so
would substitute authority and invalidate the intent, scope, and contract
identity chain.

## Fixture A — admitted recovery success

Criterion: `RECOVERY_PIPELINE_COMPLETED_AND_ADMITTED`

The real interruption/recovery fixture now requests a structured analysis
with:

- a summary;
- at least three findings;
- evidence references;
- limitations.

Canonical selection must therefore be:

- validation mode `GENERAL_RESULT_V2`;
- deliverable profile `STRUCTURED_ANALYSIS_V2`;
- result-contract class `STRUCTURED_DETERMINISTIC`;
- admission eligibility `ADMISSIBLE_WHEN_VERIFIED`.

The contract is selected before queueing and remains bound through mission,
queue, worker instruction, result, verifier, preservation, admission, and
receipt. The interrupted run remains immutable. A distinct recovery mission,
run, thread, and turn must independently satisfy every structured deliverable
before admission.

## Fixture B — generic recovery policy

Criterion: `GENERIC_RECOVERY_RESPONSE_PRESERVED_NON_ADMISSIBLE`

A recovery result using `TEXT_RESPONSE_V2` remains:

- transportable;
- preserved and hash-bound;
- visible and auditable;
- `STRUCTURAL_TEXT_ONLY`;
- `INFORMATIONAL_NON_ADMISSIBLE`;
- `UNCLASSIFIED_RESULT` when no authoritative structured status exists.

Neither strong prose nor a worker `FULFILLED` claim may produce fulfillment,
verifier GREEN, admission, or a success receipt. The recovery-action audit
receipt is not an admission receipt.

The UI must say:

> Response received. Task fulfillment could not be independently verified
> from this result contract. The response was preserved but not admitted.

It must also show the original goal, authorized goal, contract class,
non-admission reason, absence of an admission receipt, and the exact next
action.

## Authority boundary

`retryInterrupted` accepts no caller-supplied result contract. It carries the
canonical source mission's natural request, intent, scope, exact-response
contract, and task-completion contract into the new-run preparation path.

No LLM semantic judge, whole-answer phrase authority, generic-text admission,
new verifier, or new admission authority is introduced by this alignment.
