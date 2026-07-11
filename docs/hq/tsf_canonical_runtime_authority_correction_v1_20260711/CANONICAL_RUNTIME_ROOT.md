# Canonical Runtime Root

Normal V1 runtime writes resolve `<verified Git top-level>/.codex-local/rt` internally. Alternate roots are rejected, not redirected, before adapter startup or artifact creation. Reparse and containment checks bind the root to the repository.

Prefixes are fixed: `p` preservation, `a` adapter, `q` queue-executor control, `l` lifecycle control, and `x` preservation staging. Mission and run path segments are 32-character Base32 encodings of 160 SHA-256 bits; complete identities remain in manifests.

`New-TsfRuntimeStoragePlan -TestOnlyAllowAlternateRoot` performs path planning only. Normal executor, lifecycle, adapter, preservation, result, and admission entry points do not expose that switch and cannot write through it.
