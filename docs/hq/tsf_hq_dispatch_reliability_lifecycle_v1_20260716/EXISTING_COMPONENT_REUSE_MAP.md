# Existing Component Reuse Map

| Capability | Classification | Reused authority or bounded M3 addition |
|---|---|---|
| Mission validation and routing | EXISTING_CANONICAL_REUSE | Mission envelope, Project Main Bot routing, durable preflight |
| Queue creation and movement | EXISTING_CANONICAL_REUSE | `New-TsfCanonicalQueueMission.ps1`, `Move-TsfMissionState.ps1` |
| Foreground execution | EXISTING_PARTIAL | Existing executor and app-server adapter; exact ownership callbacks and shutdown settling added |
| Lifecycle terminal truth | EXISTING_CANONICAL_REUSE | Lifecycle terminal-result record remains authoritative |
| Verifier, preservation, admission | EXISTING_CANONICAL_REUSE | Existing independent postrun verifier and admission transaction |
| TIM_REQUIRED response | EXISTING_CANONICAL_REUSE | Existing response writer and response replay identity |
| Submission duplicate/replay | EXISTING_PARTIAL | Existing canonical identity; restart/operator projection added |
| Process owner and listener correlation | WRAPPER_REQUIRED | Ignored, atomic, cryptographically bound local owner record |
| Doctor and restart reconciliation | WRAPPER_REQUIRED | Read-only projection across canonical records and live process evidence |
| Bounded recovery actions | WRAPPER_REQUIRED | Evidence-bound wrappers delegate to existing canonical entrypoints |
| Recovery/Doctor/Stop UI | UI_PROJECTION_REQUIRED | Status and exact decisions only; no new authority |
| M1/M2A/M2B demonstration | WRAPPER_REQUIRED | One isolated fixture-only foreground demo |
| Real interruption determinism | WRAPPER_REQUIRED | Private test dependency-injection barrier after real child ownership |
| Background queue/service/scheduler | DEFERRED_POST_V1 | Prohibited and absent |
| Automatic continuation/approval | DEFERRED_POST_V1 | Prohibited and absent |

No M3 requirement needed a second state store, replay registry, lifecycle engine, queue mover, approval system, or product-repository bridge. See `PHASE_0_RELIABILITY_INVENTORY.md` for the full research-first inventory.
