# Security and authority review

The correction is fail-closed and TSF-local. It adds data contracts and checks inside existing authorities; it does not add a natural-language execution route, arbitrary repository command, queue, lifecycle, verifier, admission engine, approval ledger, credential path, plugin path, or network capability.

The Architect classified the defects as multiple localized corrections. Authority-bearing intent is checked before mission id allocation and again before queue mutation. Caller fields remain closed; cross-session, cross-preview, cross-mission, cross-revision, cross-run, changed route, changed access, and changed contract evidence are rejected. Exact-literal byte matching is unchanged.

Control-plane network remains `CODEX_SERVICE_ONLY` only for bounded real proof. Worker-tool network is disabled. Product repositories, NWR/PrivateLens, plugins, credentials, installs, deployment, services, scheduled tasks, remote listeners, background workers, and unattributed process termination are prohibited.

Publication requires a clean exact candidate, full acceptance, fresh read-only Tester and Auditor GREEN verdicts, one non-force push, one ready PR, and no merge or auto-merge.
