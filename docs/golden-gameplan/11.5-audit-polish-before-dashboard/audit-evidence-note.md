# Audit Evidence Note: Dirty Repo Review

The Golden Gameplan work is intentionally performed in a dirty harness repo
while stages are being built. A dirty repo is acceptable for audit only when the
package includes reviewable evidence for the changed files.

Audit packages for these stages should include:

- `ships/CodexFleet/git-status.txt`
- `ships/CodexFleet/git-diff-stat.txt`
- sanitized changed-source snapshots for harness scripts, docs, templates, and tests
- sanitized diffs when Git can provide them
- fresh test transcript or summary evidence

This does not relax runtime safety. Audit-package redaction is separate from
runtime scope control. Runtime automation still must not touch secrets, `.git`,
locks, generated folders, product repos, merge/push/deploy paths, or
backend-sensitive work without explicit approval.

If the repo is dirty and changed-source snapshots or diffs are missing, the
audit package should be treated as incomplete.

