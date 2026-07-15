# Existing Component Reuse Map

| Operation | Canonical owner | HQ Dispatch boundary | Forbidden duplicate avoided |
|---|---|---|---|
| Route draft/classification | `tools/New-TsfProjectMainBotMissionDraft.ps1` | Fixed wrapper invocation | No second Project Main Bot |
| Model resolution and mission validation | `Resolve-TsfModelRouting`, `Test-TsfMissionEnvelope` in `tools/TsfDurableContract.Canonical.ps1` | Calls only | No second schema or validator |
| Mission record/runtime paths | `New-TsfCompleteRuntimePathPlan`, `Write-TsfKernelJson` | Fixed read-only fixture envelope | No caller-selected path |
| Queue document | `tools/New-TsfCanonicalQueueMission.ps1` | Calls only | No Node-authored queue JSON |
| Queue transitions/execution | `tools/Invoke-TsfMissionQueueForegroundExecutor.ps1` | One owned foreground process | No second queue/executor/watcher |
| App-server protocol | `tools/Invoke-TsfCodexAppServerForeground.ps1`, `tools/tsf-codex-app-server-adapter.mjs` | Reads result only | No second adapter |
| Lifecycle/terminal result | `tools/Invoke-TsfMissionLifecycle.ps1`, `tools/TsfLifecycleTerminalResult.ps1` | Reads canonical result | No second lifecycle |
| Verifier/preservation | enforcement-kernel verifier and preservation writer | Projection only | No second verifier/store |
| Admission | `Get-TsfAdmissionDecision` through the queue executor | Receipt is terminal truth | No second admission engine |
| Replay | submission/preview binding plus canonical terminal receipt | Memory index prevents duplicate process execution | No persistent private authority |

The browser cannot select executable, arguments, environment, model, effort, access, network, queue/evidence/output roots, repository, worker identity, verifier result, or admission state.

Milestone 2A retained every canonical owner. The relocation-only test correction resolves the registered historical linked worktree after `git worktree move`; it does not introduce an alternate repository or runtime address. The result projection now reads the canonical admission fields `admission_receipt_path`, `receipt_identity_sha256`, and `admission_decision_sha256`, and independently hashes the canonical receipt bytes before presentation.
