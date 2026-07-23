# Result-Contract Selection

Selection happens during route preview, before mission ID allocation or queue mutation.

- An explicit exact-literal request selects `EXACT_LITERAL_DETERMINISTIC`.
- An analytical request that explicitly requires summary, findings, evidence references, and limitations selects `STRUCTURED_DETERMINISTIC`.
- Other general text selects `STRUCTURAL_TEXT_ONLY` and is marked informational/non-admissible.
- A blocked scope has no queueable result-contract selection.

The preview exposes validation mode, result-contract class, admission eligibility, confirmation requirement, non-admission reason, exact next action, and the bound contract identity.

For material informational-only output, the existing reviewed submission carries `CONFIRM_INFORMATIONAL_NON_ADMISSIBLE`. The relay rejects a missing or changed token, a stale preview, changed replay, or caller-supplied contract type. Mission preparation independently recomputes the task-completion contract and rejects substitution before queueing.

There is no silent fallback from a structured admissible result to admissible generic prose.

Recovery does not re-select or widen the result contract. The relay clones the interrupted source mission's task-completion contract and rejects a caller-supplied replacement. Consequently, an explicit structured-analysis source task can recover through `GENERAL_RESULT_V2` / `STRUCTURED_ANALYSIS_V2`, while a generic source task remains `TEXT_RESPONSE_V2` / `STRUCTURAL_TEXT_ONLY` and informational non-admissible after recovery.
