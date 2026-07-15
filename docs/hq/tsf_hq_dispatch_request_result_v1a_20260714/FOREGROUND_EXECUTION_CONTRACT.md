# Foreground Execution Contract

The relay invokes only the existing PowerShell queue executor with fixed paths and arguments. Processes remain non-detached, bounded by timeout and output limits, and owned through a tracked foreground child handle. Server shutdown invalidates sessions, interrupts the local projection, terminates the owned child if needed, waits boundedly, and closes the listener.

The durable mission now carries the fixed required-test command `exact-response-sha256:106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`. Lifecycle passes the canonical mission/revision/run/result identity and expected hash into the existing foreground adapter. The adapter records the raw final response and its raw UTF-8 SHA-256 without trimming or case folding.

Transport and semantics are separate:

- `transport_success` means the bounded native protocol completed successfully;
- `response_exact_match` means the observed raw response hash equals the mission-bound hash;
- `semantic_response_success` requires an observed final response and the exact comparison when one is required;
- lifecycle worker green, the required-test `PASS`, verifier green, preservation, and admission all require the exact bound evidence.

The verifier reads the preserved canonical queue document to recover the durable mission requirement, reads the worker-bound adapter artifact, verifies its artifact hash and mission/revision/run/result/thread/turn bindings, independently re-hashes the raw response, and fails closed on missing, empty, wrong, prefixed, suffixed, case-changed, whitespace-changed, newline-changed, or cross-run evidence.

The real correction proof observed: HTTP `200`, worker `CODEX_APP_SERVER_WORKER_GREEN`, verifier `GREEN`, admission `ADMITTED_WITH_CAVEATS`, owned child exited `true`, listener remaining `false`, and no worker filesystem writes. No arbitrary shell bridge, background runner, watcher, daemon, product repository, plugin, credential, push, merge, deployment, package installation, remote listener, or production mutation was introduced.
