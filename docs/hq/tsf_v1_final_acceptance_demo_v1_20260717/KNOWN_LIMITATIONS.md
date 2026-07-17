# Known V1 Limitations

- HQ Dispatch is one local foreground process with one active governed mission. It is not a background queue service.
- Real execution requires the local Codex app-server/control-plane service to be available and authenticated. Worker tools remain network-disabled.
- The deterministic Demo proves choreography and UI projection only. It never launches a real model/app-server worker.
- V1 defaults to bounded TSF-local read-only work. The optional workspace-write proof is excluded from this release candidate.
- Restart reconciliation is read-only. It never auto-reruns, auto-answers, auto-approves, auto-completes, or resumes an old thread/turn.
- Exact pending TIM_REQUIRED records may make Doctor return exit `3`; this is an evidence-bound operator decision state, not a listener/owner cleanup failure.
- Admission may be `ADMITTED_WITH_CAVEATS` where runtime non-use is not authoritatively observable. V1 preserves `NOT_OBSERVED` instead of inventing false certainty.
- No product repository, plugins, credential discovery, deployment, merge, multi-worker scheduling, remote listener, or production authority is included.
