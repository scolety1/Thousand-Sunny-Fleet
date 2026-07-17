# TSF V1 Final Acceptance, Demo, and Release Candidate V1

This packet is the Milestone 4 acceptance layer for the already-built Thousand Sunny Fleet V1. It does not replace the canonical mission, queue, lifecycle, verifier, admission, approval, replay, or recovery authorities.

Required baseline: `952f30e137214735fe2513a7b068d9680ca882c7`.

The source changes are intentionally narrow:

- the human Doctor formatter uses each authoritative check `id`, and rejects a missing label;
- parser evidence records an honest numeric exit and explicit parser-result identity for every row;
- the accepted M3 validation hash typo is preserved and corrected by an additive erratum;
- the Start/Doctor/Stop test waits boundedly for the demo banner it asserts, removing a stdout scheduling race;
- one repeatable M4 runner composes accepted milestone and canonical suites, the bounded real app-server proof, cleanup assertions, and hashed evidence.

The deterministic Demo is clearly labeled fixture behavior. The final acceptance run is what proves the real Codex app-server interruption and distinct new-run recovery path under `CODEX_SERVICE_ONLY`, with worker-tool network disabled.

Publication remains prohibited until a fresh independent Tester and Auditor both report GREEN on the frozen candidate. Publication is one normal non-force push and one ready PR; this milestone never merges or enables auto-merge.

Start with [OPERATOR_RUNBOOK.md](OPERATOR_RUNBOOK.md), [DEMO_SCRIPT.md](DEMO_SCRIPT.md), and [PHASE_0_FINAL_INVENTORY.md](PHASE_0_FINAL_INVENTORY.md).
