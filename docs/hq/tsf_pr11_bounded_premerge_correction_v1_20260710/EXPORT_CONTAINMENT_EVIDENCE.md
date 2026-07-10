# Export Containment Evidence

The exporter canonicalizes the three approved root families, the requested/fallback roots, project directories, prompt directories, every exported file, every outbound ZIP, and the final export index. A destination must equal its approved output root or start with the canonical root plus the platform directory boundary.

Project and prompt IDs use a strict lowercase allowlist: `^[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?$`. Rooted/absolute identifiers, drive/UNC forms, slash/backslash separators, traversal tokens, invalid characters, and control characters are rejected. All plan-derived destinations are validated before the exporter creates the output tree where possible, and each write destination is revalidated immediately before use.

Executed containment cases:

- `SEC-EXPORT-002` / `003`: sibling-prefix `exports_EVIL` rejected and not created.
- `SEC-EXPORT-004`: `..` traversal root rejected.
- `SEC-EXPORT-005`: drive-rooted project ID rejected.
- `SEC-EXPORT-006`: UNC project ID rejected.
- `SEC-EXPORT-007`: backslash separator rejected.
- `SEC-EXPORT-008`: alternate `/` separator rejected.
- `SEC-EXPORT-009`: traversal token inside identifier rejected.
- `SEC-EXPORT-010`: control-character identifier rejected.
- `SEC-EXPORT-011`: reserved Windows device identifier rejected.
- `RP-005` and `RP-EXPORT-*`: the approved `.codex-local/research-pipeline/exports` path still produced three complete outbound request ZIPs.

Fallback-root behavior remains in the script. Permission-failure injection against the fallback branch is explicitly NOT_TESTED in this lane. Returned ZIP import is not implemented.
