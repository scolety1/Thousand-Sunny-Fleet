# Existing Component Reuse Map

| Operation | Existing owner reused | Dispatch role |
|---|---|---|
| Natural request drafting/classification | `tools/New-TsfProjectMainBotMissionDraft.ps1` | Calls only |
| Model resolution and durable validation | `tools/TsfDurableContract.Canonical.ps1` | Calls only |
| Queue document creation | `tools/New-TsfCanonicalQueueMission.ps1` | Calls only |
| Queue transitions and foreground execution | `tools/Invoke-TsfMissionQueueForegroundExecutor.ps1` | Owns one foreground child |
| App-server protocol | `tools/Invoke-TsfCodexAppServerForeground.ps1`, `tools/tsf-codex-app-server-adapter.mjs` | Projects result only |
| Lifecycle and terminal result | `tools/Invoke-TsfMissionLifecycle.ps1`, `tools/TsfLifecycleTerminalResult.ps1` | Projects records only |
| Verifier and preservation | enforcement-kernel verifier and preservation writer | Projects records only |
| Admission | `Get-TsfAdmissionDecision` through the queue executor | Receipt is terminal truth |
| Approval matching | `Find-TsfKernelApprovalMatches` | No writer fabricated |

New code is limited to a hardcoded submission wrapper and an in-process bridge/projection layer. It creates no second queue, executor, verifier, admission engine, or persistent watcher.
