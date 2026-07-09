# Role-Aware Lifecycle Integration V1

This integration keeps the existing TSF foreground lifecycle and inserts worker-role permission preflight before worker instruction generation. A Project Main Bot mission draft is normalized to an effective mission packet, kernel preflight runs, role registry/profile checks run, approval ledger matching remains authoritative, and only then is a dry-run worker instruction packet created. Unknown roles, missing profiles, forbidden paths, protected repos, Codex CLI/API requests, and missing approval fail closed.
