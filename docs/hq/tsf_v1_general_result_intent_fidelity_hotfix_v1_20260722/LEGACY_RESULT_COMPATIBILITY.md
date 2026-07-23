# Legacy result compatibility

Older general worker output has no mission-bound task/intent/scope envelope. It is never promoted to success.

The closed compatibility parser maps empty output to `REQUIRED_DELIVERABLE_MISSING`; inability or unsupported action to `UNABLE_TO_PERFORM`; explicit refusal to `REFUSED`; policy blockage to `BLOCKED_BY_POLICY`; and clarification language to `NEEDS_CLARIFICATION`. Any other legacy text becomes `UNCLASSIFIED_RESULT`. All compatibility outcomes set `semantic_success=false` and `admissible=false`.

This is an intentional compatibility consequence: old exact-literal missions continue unchanged, while old general missions require a new preview/mission under `GENERAL_RESULT_V2`. Historical receipts are preserved and not retrospectively relabeled.
