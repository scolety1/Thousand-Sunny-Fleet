# Existing Component Reuse Map

Research-first inventory established the following ownership boundaries before implementation.

| Action | Canonical entrypoint | Authoritative record | M2B wrapper/projection | Duplicate implementation prohibited |
|---|---|---|---|---|
| Operator session and HTTP boundary | `tools/hq-dispatch/v1/server.mjs` | Server-owned session boundary and exact Host/Origin checks | `POST /api/v1/missions/:id/tim-response` | No alternate token, listener, or origin policy |
| Mission preparation/revision | `tools/hq-dispatch/v1/New-TsfHqDispatchGovernedMission.ps1` and Project Main Bot | `tsf_mission_envelope_v1` | Closed response-bound revision input | No private mission editor or revision store |
| Queue creation/state | `tools/New-TsfCanonicalQueueMission.ps1` and foreground executor | `tsf_canonical_queue_document_v1` | Immediate-parent revision allowed only from `blocked_needs_tim` | No second queue or watcher |
| Terminal human request | `tools/TsfLifecycleTerminalResult.ps1` | `tsf_lifecycle_terminal_result_v1` plus `tsf_tim_required_request_v1` | Exact browser projection with evidence hash | No inferred or UI-authored request |
| Approval writing | `New-TsfKernelExactApprovalLedger` in `tools/codex-fleet-enforcement-kernel.ps1` | Existing canonical approval ledger | `Invoke-TsfHqDispatchTimResponse.ps1` delegates exact fields | No arbitrary ledger JSON write or parallel approval format |
| Approval matching/consumption | `Test-TsfKernelApprovalLedger` and `Use-TsfKernelApproval` | Canonical ledger entry and usage state | New revision passes ledger path to existing executor | No HQ-side matcher or reuse ledger |
| Denial/clarification persistence | Existing durable `context_update` record path | `tsf_tim_required_response_v1` | Atomic canonical response write | No private response-authority registry |
| Worker execution | `Invoke-TsfMissionQueueForegroundExecutor.ps1` and `Invoke-TsfMissionLifecycle.ps1` | Canonical lifecycle/result records | Always a new revision and run | No resume, suspended turn, or command bridge |
| Verification | Existing canonical kernel post-run verifier | Verifier result | Read-only status projection | No UI/server verifier result |
| Admission | Existing durable contract admission | Admission receipt | Read-only status projection | No HQ admission decision |
| Replay | Canonical response/ledger/mission/queue identities | Existing response, ledger, mission, and queue records | In-process promise cache only collapses concurrent HTTP double-clicks | No parallel authority registry |

The only in-memory relay state is a non-authoritative concurrency/idempotency cache. Every returned decision is reconstituted from or linked to canonical TSF records.
