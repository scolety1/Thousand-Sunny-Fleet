# Stage 3 Checkpoint: Audit Package Loop

Status: GREEN

## Phase Checklist

- [x] Phase 1: Audit manifest schema
- [x] Phase 2: Audit package directory layout
- [x] Phase 3: Audit package builder
- [x] Phase 4: Evidence collection and exclusions
- [x] Phase 5: Prompt generation
- [x] Phase 6: Multi-ship audit packages
- [x] Phase 7: Package validation and size guardrails
- [x] Phase 8: Stage 3 integration check

## Required Final Evidence

- [x] `.\tests\run-fleet-tests.ps1` passes
- [x] audit manifest schema/template exists
- [x] one command creates audit package folder
- [x] one command creates audit package zip
- [x] package includes `manifest.json`
- [x] package includes `README_AUDIT_PACKAGE.md`
- [x] package includes external audit prompts
- [x] package includes Stage 2 canonical evidence when present
- [x] package supports selected ship bundles
- [x] package excludes secrets and dependency/build folders by manifest policy
- [x] package records manifest file references and hashes
- [x] package reports missing optional evidence as non-blocking omissions

## Deferrals

```text
No blocking deferrals. Morning watch item: add package size limits and stricter manifest-reference validation during Stage 14 stress testing.
```

## Stage Verdict

```text
Verdict: GREEN
Date: 2026-05-26
Summary: Stage 3 added audit schema docs and `new-audit-package.ps1`, which creates deterministic audit folders, zips, manifests, README files, prompts, selected ship evidence, git status, and diff stats.
Known risks: Package size limits are policy-level today; hard cap enforcement should be stress-tested later.
Ready for Stage 4: yes
```
