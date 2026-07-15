# Foreground Execution Contract

One mission may be active per Dispatch process. The relay spawns the existing queue executor with fixed arguments, `detached:false`, `shell:false`, a bounded timeout, bounded stdout/stderr capture, and a tracked child handle. Shutdown invalidates sessions and terminates the owned child.

The mission fixes read-only sandboxing, `CODEX_SERVICE_ONLY` control-plane network, disabled worker-tool network, no plugins, no credentials, no product repository, and no writes. The browser cannot change these values.

No watcher, daemon, detached child, persistent queue consumer, or restart recovery was added.
