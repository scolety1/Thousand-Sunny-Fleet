# Security Boundary

- Listener: fixed IPv4 loopback only.
- Browser boundary: exact same-origin session, random memory token, custom header, expiry, rate limit, no CORS.
- Input: JSON-only, closed schemas, 8192-byte HTTP limit, bounded text, no command/path/environment fields.
- Execution: fixed PowerShell and repository entrypoints, no shell, no detached child, one active mission.
- Mission: TSF-local read-only fixture, no product repository, plugins, credentials, worker-tool network, merge, push, deploy, install, or production authority.
- Truth: canonical queue/lifecycle/verifier/preservation/admission records; UI memory is projection only.

Known blockers are the 225-character runtime target at the mandated long worktree and the absent canonical approval/denial writer.
