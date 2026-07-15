# Canonical Mission and Queue Integration

`tools/hq-dispatch/v1/New-TsfHqDispatchGovernedMission.ps1` is a closed wrapper for one fixed mission type: `hq_dispatch_read_only_vertical_slice`.

It invokes Project Main Bot, resolves the canonical model alias, captures Git and policy bindings, fixes read-only sandboxing, `CODEX_SERVICE_ONLY` control-plane access, disabled worker-tool network, one TSF-local read source, no writes, no approvals, and broad authority denials. It validates the durable envelope, obtains canonical runtime paths, writes one server-identified mission record, and calls `New-TsfCanonicalQueueMission.ps1` for one queue document.

The browser cannot supply identities or paths. Alternate queue roots exist only through the test-only server constructor and must remain beneath `.codex-local/fixtures`.

The deterministic slice created mission `hq2-mrlb47w3-bfa3cf` revision `1` with queue SHA-256 `5d1eefd3011f7ab566514652847d90234569b894a7a95c5539c9136ec772f99d` and reached `ADMITTED`. The single real slice created mission `hq2-mrlb70lk-dc5d7c` revision `1` with queue SHA-256 `23c14691014a8d3dea64e32d9a671b45f2dee4c6c6080b0dffdfd0f281b0e1d0` and reached `ADMITTED_WITH_CAVEATS` through the same canonical queue, lifecycle, verifier, preservation, and admission path.
