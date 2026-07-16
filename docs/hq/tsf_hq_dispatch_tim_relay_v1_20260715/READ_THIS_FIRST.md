# TSF HQ Dispatch TIM_REQUIRED Relay V1

Milestone 2B completes the bounded operator-decision loop without adding a second authority system. HQ Dispatch projects a canonical terminal `TIM_REQUIRED` request, accepts one closed response, delegates authority-changing work to existing TSF owners, and starts a new governed mission revision when policy permits. The original run is never resumed or mutated.

## Build identity

- Canonical baseline: `58c54190d254d1b31149aae032467d33a1180a57`
- Baseline tree: `fc6c1b6df2d91fa294340bf3c92d22ab26667cb5`
- Branch: `work/tsf-hq-dispatch-tim-relay-v1-20260715`
- Worktree: `C:\TSF_M2B`
- Publication target: `main`
- Builder commit: recorded after the final evidence freeze

## Result

- Exact approval is written only through the canonical approval-ledger writer and matched by the canonical kernel.
- Denial is an immutable canonical response record, grants no authority, and creates no revision, queue document, or worker.
- Bounded clarification is stored as canonical mission context and creates a new revision through Project Main Bot and canonical mission preparation.
- Authority-relevant clarification changes stop at a fresh canonical `APPROVAL_REQUIRED` request.
- Exact response replay is idempotent; changed replay and cross-binding responses fail closed.
- The terminal revision remains byte-identical while the revised mission receives fresh run, result, thread, turn, verifier, and admission identities.

The deterministic proof matrix passed, and one bounded real `CODEX_SERVICE_ONLY` clarification-to-revision proof reached `ADMITTED_WITH_CAVEATS` with exact response verification, disabled worker-tool network, no repository writes, clean child exit, and no remaining listener. See `REAL_PROOF_EVIDENCE.md`.

No merge, auto-merge, deployment, package installation, plugin use, credential access, product-repository access, detached process, persistent process, or Milestone 3 work is part of this delivery.
