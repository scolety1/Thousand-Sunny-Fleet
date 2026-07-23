# Root cause: GENERAL_RESULT_V1 false success

`tools/tsf-codex-app-server-adapter.mjs` set general semantic success equal to successful foreground transport when no exact-response hash was present. `tools/Invoke-TsfMissionLifecycle.ps1` repeated that decision and emitted a required-test PASS from the event-journal hash. The kernel verifier checked transport, role claims, and pre-existing read-only artifacts but had no mission-bound required-deliverable contract for general text. The durable result mapper and admission engine therefore inherited a transport-derived PASS.

This let inability, refusal, missing deliverables, or a related but unperformed task reach an admitted receipt. The defect affected adapter, lifecycle, verifier, result mapping, admission, and UI wording; it was not an app-server transport failure.

The correction makes the adapter non-authoritative for general semantics, introduces a closed `GENERAL_RESULT_V2` evidence wrapper and task-completion contract, independently recomputes the evidence in the verifier and mapper, and requires an accepted disposition plus zero missing required deliverables at admission. Legacy unstructured general output is fail-closed.
