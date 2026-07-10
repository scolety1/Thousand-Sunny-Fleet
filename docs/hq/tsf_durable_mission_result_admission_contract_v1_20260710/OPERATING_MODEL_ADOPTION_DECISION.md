# Operating Model Adoption Decision

Status: **ADOPTED_CONTROL_PLANE_ARCHITECTURE_V1**

This decision supersedes older implications that TSF should become a full chatroom, that a native surface is itself a TSF role, or that returned research or implementation evidence can approve its own adoption. Historical packets remain evidence of their time and are not rewritten.

## Adopted model

- The TSF kernel is the local system of record for mission identity, policy, approvals, evidence, admission, and recovery.
- The Project Main Bot is a routing and policy role. It is not a chatbot, implementer, final reviewer, or approver.
- Chat is the strategic Master HQ conversation surface.
- Work is a research and substantial-deliverable execution surface.
- Codex is the software implementation, repository-work, and technical-review surface.
- HQ Dispatch is a future small optional sidecar, not a second full chatbot.
- Surfaces, model names, and user interfaces are replaceable.
- The stable boundary is `mission envelope -> native execution -> result envelope -> postflight validation -> admission decision`.
- Research, implementation, verification, admission, merge, production, and human adoption authority remain separate.

Native task completion is evidence, not approval. Protected decisions remain subject to the existing approval ledger, decision-authority policy, independent verification, and Tim gates.

Related prior evidence: `agent_of_agents_architecture_improvement_adoption_v1`, `project_main_bot_worker_role_foundation_overnight_v1`, `role_aware_mission_lifecycle_integration_v1`, `hq_chokepoint_adapter_no_api_v1`, and `tsf_pr11_bounded_premerge_correction_v1_20260710`.
