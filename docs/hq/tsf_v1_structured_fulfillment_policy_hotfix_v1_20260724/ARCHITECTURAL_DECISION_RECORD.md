# Architectural Decision Record

## Decision

Generic text is structural-only and non-admissible in TSF V1.

## Context

The prior calibration correctly separated worker status from subject-matter prose, but a generic affirmative `TEXT_RESPONSE_V2` claim could still admit based on nonempty prose. A deterministic verifier cannot prove arbitrary task fulfillment without interpreting unrestricted prose.

## Consequences

- `TEXT_RESPONSE_V2` is `STRUCTURAL_TEXT_ONLY` with `INFORMATIONAL_NON_ADMISSIBLE` eligibility.
- Its canonical affirmative disposition is the existing `UNCLASSIFIED_RESULT`; no overlapping disposition was added.
- Negative structured worker statuses such as `UNABLE_TO_PERFORM`, wrong-task identity, and missing deliverables remain distinguishable without scanning prose.
- `STRUCTURED_ANALYSIS_V2` remains admissible only after all closed deliverables and identities verify.
- Mission preview selects and exposes the result contract before queueing.
- Informational-only submission requires the exact confirmation token bound through the existing governed submission path.
- Submission independently recomputes the preview, scope, and task-completion contract.
- Interruption recovery clones the source mission's task-completion contract; it does not select a new contract or accept a caller override.
- A recovery fixture that expects admission must therefore request a mechanically admissible contract. Generic recovery output remains preserved and non-admissible.

The localized recovery-fixture blocker was classified as `RECOVERY_SUCCESS_FIXTURE_USES_NON_ADMISSIBLE_GENERIC_TEXT`. It was a contradictory acceptance expectation, not a runtime, verifier, admission, relay, or UI defect.

A later independent publication audit found `GENERIC_RESULT_COMPATIBILITY_MODE_SCHEMA_ENUM_OMISSION`: the runtime's existing `STRUCTURAL_TEXT_ONLY_V2` evidence tag was absent from the closed general-result schema. The bounded correction aligns representation only; generic-text semantic and admission authority remain unchanged.

## Rejected alternative

No bounded or unbounded LLM semantic verifier is introduced.
