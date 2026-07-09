# Project Main Bot Dry-Run Loop V1

`tools/Invoke-TsfProjectMainBotDryRun.ps1` accepts a request fixture, creates a mission draft through the intake adapter, runs role-aware lifecycle dry-run when safe, writes a Tim-readable summary, and updates a local context capsule. It never executes a worker, invokes Codex CLI, calls an API, starts a runner, or touches product/canonical repos.
