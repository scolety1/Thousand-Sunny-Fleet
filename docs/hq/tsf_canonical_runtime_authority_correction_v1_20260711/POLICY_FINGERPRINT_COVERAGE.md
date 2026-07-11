# Policy Fingerprint Coverage

`tools/codex-fleet-runtime.ps1` is now a governing file because both canonical orchestration scripts load it. Coverage tests require loaded runtime dependencies to appear in the policy manifest, verify that representative governing changes alter the fingerprint, and verify that unrelated files do not.

Normal clean operation continues to hash committed blobs at internally resolved HEAD and rejects dirty governing state. Generated missions, results, journals, manifests, receipts, credentials, and secrets remain excluded. The final clean committed fingerprint is computed after the correction commit and reported without a post-commit tracked mutation.
