# Phase 0 Reliability Inventory

The inventory was completed against exact `origin/main` commit `6f0fc0a481f2832a60073e872854f56ac6207516`. The canonical checkout was clean, no Git lock/merge/rebase existed, no Milestone 3 branch/worktree conflicted, and merged Milestones 1, 2A, and 2B flows were present before `C:\TSF_M3` was created.

| Capability | Classification | Existing source / Milestone 3 disposition |
|---|---|---|
| HTTP startup and fixed loopback bind | EXISTING_PARTIAL | `server.mjs` already bound `127.0.0.1:4317`; Start/Doctor and ownership gating were missing. |
| Server shutdown and signal handling | EXISTING_PARTIAL | Sessions and one relay child were invalidated/killed; exact ownership, listener confirmation, interruption evidence, and tree cleanup were missing. |
| Operator-session lifecycle | EXISTING_CANONICAL_REUSE | Memory-only random tokens, exact Host/Origin, TTL, rate bound, and shutdown invalidation are retained; a fresh process generation is now projected. |
| Foreground child ownership | EXISTING_PARTIAL | `mission-relay.mjs` already used `detached:false`, `shell:false`, bounded timeout/output, and one child handle; owner evidence callbacks and exact cleanup were added. |
| Canonical queue states | EXISTING_CANONICAL_REUSE | `mission-queue-state-policy.v1.json`, `New-TsfCanonicalQueueMission.ps1`, `Move-TsfMissionState.ps1`, and the foreground executor remain authoritative. |
| Lifecycle terminal-result states | EXISTING_CANONICAL_REUSE | `TsfLifecycleTerminalResult.ps1` and its schema remain authoritative. |
| Interrupted-result handling | WRAPPER_REQUIRED | No restart discovery or immutable Dispatch interruption record existed. An append-only interruption receipt and exact queue snapshot now preserve the source without declaring completion. |
| Submission duplicate/replay | EXISTING_PARTIAL | Canonical mission/queue content identities and in-process promise collapse existed; restart projection and operator messages were missing. |
| TIM_REQUIRED response replay | EXISTING_CANONICAL_REUSE | Exact response ID/content and ledger semantics remain owned by the Milestone 2B response path. Restart rehydration projects the request without answering it. |
| Queue mover and recovery entrypoints | EXISTING_CANONICAL_REUSE | `Move-TsfMissionState.ps1`, admission transaction relationships, canonical recovery envelopes, and `New-TsfCanonicalQueueMission.ps1 -RecoveryFromMissionId` are wrapped; no new mover exists. |
| Stale record and identity validation | EXISTING_PARTIAL | Canonical hashes and schema validation existed; a cross-root read-only reconciler and PID/start/executable checks were missing. |
| Orphan-process checks | EXISTING_PARTIAL | App-server adapter recorded `child_exited`/`no_orphan_process`; process-owner and listener correlation were missing. |
| Listener checks | WRAPPER_REQUIRED | Fixed bind existed, but no read-only listener/owner disposition or second-instance gate existed. |
| Fleet doctor | EXISTING_PARTIAL | `fleet-doctor.ps1` checks product fleet readiness, not HQ Dispatch lifecycle/canonical recovery. A scoped read-only Doctor wrapper was required. |
| Cooperative stop tool | EXISTING_PARTIAL | `request-safe-stop.ps1` is a general boundary marker, not exact HQ process control. Exact owner-authenticated Stop was required. |
| Existing demos/fixtures | EXISTING_PARTIAL | M1/M2A/M2B tests existed independently. A single foreground, isolated, operator demo covering all three was required. |
| Windows path budget | EXISTING_CANONICAL_REUSE | `TsfRuntimeArtifactAddressing.ps1` owns 225 target / 240 hard budgets. Doctor adds lifecycle path projections and uses the intentional short worktree. |
| Artifact/runtime roots | EXISTING_CANONICAL_REUSE | `.codex-local\rt` and `fleet\missions` remain canonical; demo roots are isolated below `.codex-local\fixtures`. |
| App-server child termination | EXISTING_PARTIAL | Canonical runtime bounded the child and timed out its tree. Stop now verifies the Dispatch-owned parent identity, requests cooperative exit, and only then uses exact owned-tree termination. |
| Doctor/recovery UI projection | UI_PROJECTION_REQUIRED | No Milestone 3 status/recovery surfaces existed. Read-only Doctor, startup block, recovery center, and stop view were added. |
| Background queue daemon/service/scheduler | DEFERRED_POST_V1 | Explicitly prohibited and not implemented. |
| Automatic resume/approval/completion | DEFERRED_POST_V1 | Explicitly prohibited and not implemented. |
| Arbitrary repository/product execution | DEFERRED_POST_V1 | Explicitly prohibited and not implemented. |

## Architecture decision

No `MISSING_V1_BLOCKER` required another state store or authority engine. The implementation could be completed with bounded wrappers and projections around existing canonical controls, so the architecture stop rule did not fire.
