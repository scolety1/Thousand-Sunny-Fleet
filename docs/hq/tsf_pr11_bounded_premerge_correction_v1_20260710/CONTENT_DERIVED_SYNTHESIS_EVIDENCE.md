# Content-Derived Synthesis Evidence

The corrected V1 is deterministic and local. It does not invoke an LLM, API, Codex worker, or external service.

Eligibility requires exactly one `IMPORTED_VALID` metadata record per planned prompt, exact `research_project_id`, a prompt ID present in the plan, a preserved report under the import's `preserved` directory, matching SHA-256, non-empty Summary/Findings/Recommendations/Caveats/Sources sections, and at least one structured KEEP/CHANGE/ADD/REMOVE/DELAY line. Duplicate, wrong-project, unexpected-prompt, incomplete, malicious, rejected, missing, path-escaping, and hash-mismatching imports are excluded.

Observed proof from the executed suite:

- `SEC-SYNTH-010`: alpha content emitted `KEEP Alpha Coordinator`; beta content emitted `REMOVE Beta Coordinator`.
- `SEC-SYNTH-004`: the wrong-project report's `REMOVE expected-project safety controls` signal was absent.
- `SEC-SYNTH-005`: the complete but unexpected prompt was recorded as `UNEXPECTED_PROMPT_ID` and did not influence decisions.
- `SEC-SYNTH-006` and `SEC-SYNTH-007`: duplicate, partial, and malicious imports were excluded.
- `SEC-SYNTH-009`: a partial report as the only expected input produced `YELLOW_SYNTHESIS_INSUFFICIENT_ELIGIBLE_REPORT_CONTENT` with zero eligible reports.
- `SEC-SYNTH-008`: every emitted decision carried prompt ID, report hash, source line, and source entries.
- `SEC-SYNTH-011`: two `KEEP Shared Audit Trail` signals produced a content-derived agreement.
- `SEC-SYNTH-012`: `KEEP Console Authority` versus `REMOVE Console Authority` produced `UNRESOLVED_ADVISORY_DISAGREEMENT` without automatic resolution.
- `SEC-SYNTH-002`: output remained `advisory_only: true` and `grants_approval: false`.

All inputs are labeled `SYNTHETIC_FIXTURE_NOT_REAL_RESEARCH`. GREEN means only that the bounded fixture inputs were structurally eligible for advisory review. It does not mean sources are true, citations are correct, claims are verified, research is production-grade, or implementation/merge is approved.
