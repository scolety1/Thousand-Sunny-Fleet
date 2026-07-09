# Reuse Decision Report

Verdict: ADAPT_EXISTING_TSF_COMPONENTS

The Project Main Bot and worker foundation should reuse the current TSF enforcement kernel, mission schema, lifecycle runner, mission authoring helper, approval ledger, verifier, preservation writer, HQ escalation schema, project-management helper, lane resolver, worktree boundary contract, and project status files.

Do not rebuild mission packets, preflight, approval ledger, verifier, preservation, specialized lanes, or external auditor role concepts. The missing layer is role-aware intake and permission validation, not a new orchestration stack.

Do not use or implement Operator Console, API/HQ transport, Codex CLI worker execution, persistent runners, or product repo missions in this batch.
