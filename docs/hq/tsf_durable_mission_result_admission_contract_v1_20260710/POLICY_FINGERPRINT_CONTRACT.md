# Policy Fingerprint Contract V1

`fleet/control/policy-manifest.v1.json` is an ordered allowlist. `tools/New-TsfPolicyFingerprint.ps1` hashes only the manifest version, relevant Git commit, declared schema versions, and each ordered repository-relative governing file path plus SHA-256.

Paths are canonicalized, must remain inside the repository, and may not be rooted or traverse. Missing and duplicate entries fail closed. Runtime approvals, secrets, source material, transcripts, and unrelated files are excluded.

Canonical input is compact UTF-8 JSON with deterministic property and array order. A governing-file, schema-version, path-order, manifest-version, or policy-commit change changes the fingerprint.
