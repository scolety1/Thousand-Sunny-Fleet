# Security and Authority Review

M4 adds no new runtime authority. The canonical queue, lifecycle, executor, verifier, preservation, admission, approval ledger, replay identity, and recovery records remain the only authorities.

| Boundary | M4 result |
|---|---|
| Arbitrary command or executable bridge | DENIED; no new bridge |
| Arbitrary/product repository execution | DENIED; TSF-local only |
| Deployment, merge, push, or approval authority | DENIED; publication remains a human-invoked Git step after audit |
| Automatic submit/continue/retry/approve/TIM answer | DENIED |
| Background, detached, daemon, service, scheduled task, startup item | DENIED |
| Plugin execution or runtime discovery | DENIED; static reference-only records remain static |
| Credential discovery or value capture | DENIED |
| Worker-tool network | DISABLED |
| Control-plane network | `CODEX_SERVICE_ONLY` only for the bounded real TSF-local proof |
| Listener | Fixed `127.0.0.1:4317`; no remote bind |
| Stop authority | Exact owner identity and local capability only; no arbitrary PID kill |
| Interruption seam | Private direct in-memory fixture injection only; no public/HTTP/env/mission activation |
| Workspace-write proof | Excluded; no separate approval |
| Second canonical system | NONE |

The final gate must verify PowerShell/Node syntax, JSON/CSV parsing, path budget, reparse containment, protected paths, `git diff --check`, exact baseline ancestry, evidence hashes, and zero final owner/listener/child. Raw stop/session capabilities, credentials, and secret-like prompt content are excluded from committed evidence.
