# End-to-End Runtime Trace

| Boundary | Read-only | Workspace-write |
|---|---|---|
| Durable mission → canonical queue | PASS, hash `ff91ad0c02a64479ed83df7508287ecc5864421198fd95367a182fc74fe3ace6` | PASS, hash `2f679e09e297686017755930f0eaf8b385c456c8b62811e14fb85425a6d4acf1` |
| Existing queue/lifecycle | `inbox` → `drafted` → `preflight_pending` → `approved_for_worker` → `worker_running` → `postrun_pending` | Same canonical transition path |
| Kernel and role preflight | GREEN, `auditor_worker` | GREEN, `builder_worker` |
| Stable foreground app-server | Thread `019f4f55-4f06-7873-b688-53cafb7f0e32`, turn `019f4f55-63e4-7621-ab77-1692572d4814` | Thread `019f4f55-a0c7-7411-b08a-f3395e336958`, turn `019f4f55-b5d2-7c13-99a8-c1a43f88ccc3` |
| Native journal / usage | 36 events, 16,691 tokens | 123 events, 55,459 tokens |
| Worker-tool network | DISABLED, unused | DISABLED, unused |
| Verifier | GREEN | GREEN; exact controlled file verified |
| Compact preservation | Manifest `bc841f3bd50c96be33c46c17ed7be40936a74474776e6eb3e3959790f3c2c4d0` | Manifest `a1ceefaf37d34521df8ab11f717f9ec4fdc47188ae3a5500a585f7dd60497d24` |
| Durable result | `e8b2815162ab41dfd764411ac5e81d217154a3f8d9ca24fcd4b6bc43f5717895` | `a31c6ca3e4c328646b734bf48b3c73604787ab0cf8c09737191c0ae44bf033b9` |
| Effort | Effective value not exposed; admitted with caveat | Effective value not exposed; admitted with caveat |
| Admission / transaction | Both immutable receipts verified and COMMITTED | Both immutable receipts verified and COMMITTED |
| Final queue state | `complete_ready_for_gate` | `complete_ready_for_gate` |
| Maximum runtime path | 219 | 219 |
| Child cleanup | PID 34228 exited; exact orphan false | PID 33644 exited; exact orphan false |

The flow uses the existing queue transition validator, enforcement kernel, role registry, verifier, preservation writer, result mapper, and admission policy. It does not create another orchestrator.
