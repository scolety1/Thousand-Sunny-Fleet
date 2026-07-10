# Audit Finding Disposition

## Confirmed and corrected

1. Content-independent synthesis: confirmed. `New-TsfDeepResearchSynthesis.ps1` previously emitted fixed architecture findings and decisions without reading preserved report bodies. It now filters exact project/prompt eligibility, verifies preserved hashes, parses required Markdown sections, derives explicit decision signals, records attribution, agreements, disagreements, exclusions, and uncertainty, and fails YELLOW on insufficient eligible content.
2. Export sibling-prefix/path injection: confirmed. The exporter previously used `StartsWith` and an unanchored local-root regex. It now canonicalizes approved roots and every destination, applies boundary-aware containment, strictly validates project and prompt identifiers, revalidates every directory/file/ZIP/index path, and preflights destinations before creating the export tree.
3. Unconditional PASS claims: confirmed. Four unconditional assertions existed in the dedicated test script, and the historical 20-case matrix included unexecuted cases. The harness now records expected and observed results for every assertion. Historical matrices were corrected to PASS, NOT_TESTED, or DEFERRED with exact evidence IDs.
4. Import completeness: confirmed. The importer previously checked only for a Sources heading plus basic unsafe text. It now requires five non-empty sections, recognizes basic source entries/locators, bounds report size, accepts strict UTF-8 only, preserves hashes/bodies, and distinguishes incomplete, encoding, malicious, wrong-project, wrong-prompt, duplicate, and valid statuses.
5. Claim/UI truthfulness: confirmed. Static fixture cards used GREEN in ways that could imply live script integration, and historical packets overclaimed generalized synthesis and red-team coverage. The preview now exposes `READ_ONLY_PREVIEW`, `FIXTURE_DATA`, and `SCRIPT_BACKED_NOT_UI_WIRED`; docs state report-file-only return import and basic citation presence.

## Audit details that were materially incomplete

- The original importer already implemented SHA-256 hashing, raw report preservation, exact expected project/prompt comparison when parameters were supplied, duplicate detection, basic malicious-instruction screening, advisory-only metadata, and boundary-aware import read/write root checks. Those working controls were retained and hardened rather than replaced.
- The original Operator Console was genuinely static and read-only; the defect was status/capability wording, not hidden execution wiring.
- The exporter intentionally created outbound ZIP packages. The unsupported behavior was hostile returned ZIP import. The correction preserves outbound ZIP generation and removes any implication that ZIP returns are accepted.
- Rejected inputs were preserved with status-bearing metadata, but were not moved into a physically separate quarantine directory. Wording now says rejected/excluded rather than claiming a separate quarantine implementation.

## Deferred

Returned ZIP import, full citation correctness or claim-to-source verification, long-path stress, permission-failure fallback injection, partial-write recovery fault injection, repeated-research lifecycle handling, and normal-suite wiring are outside this bounded correction. They are recorded without PASS claims.
