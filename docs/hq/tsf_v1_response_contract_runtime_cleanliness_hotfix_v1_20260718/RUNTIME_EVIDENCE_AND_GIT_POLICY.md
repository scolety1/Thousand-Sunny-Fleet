# Runtime evidence and Git policy

The only new ignore rules are rooted, state-specific patterns for generated `*.r*.json` mission-revision records in the eleven existing queue states. They do not ignore `fleet/**`, arbitrary JSON, `.gitkeep`, schemas, policies, tests, scripts, documents, or unknown file types.

Consequences:

- valid generated records remain durable, readable, recoverable, inventoried, and fully schema-validated locally;
- tracked changes remain visible;
- unrelated untracked files remain visible;
- arbitrary ignored JSON, incomplete canonical-looking JSON, `UNKNOWN_RUNTIME_FILE.txt`, malformed or misnamed JSON, duplicate identities, and link/reparse entries inside a protected state make Doctor unsafe;
- Stop never deletes queue, result, verifier, preservation, admission, receipt, or recovery evidence;
- each worktree retains its own `fleet/missions` and `.codex-local` roots, preventing attached/detached collisions.

`test-tsf-runtime-queue-cleanliness-v1.mjs` now derives 87 assertions from observed Doctor output, Git status, canonical validator output, filesystem entry type, file hashes, and Stop results. A filename match and two identity properties never confer trust.
