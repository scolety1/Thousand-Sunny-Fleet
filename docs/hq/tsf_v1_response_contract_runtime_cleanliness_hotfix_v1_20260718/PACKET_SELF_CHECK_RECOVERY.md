# Packet self-check recovery

## Root cause

The preserved packet self-check failure is classified `CLASSIFICATION_TEXT_STORED_IN_PATH_FIELD`. The `detached-full-acceptance-working-tree` row put `PER_COMMAND_STDERR_FILES_UNDER_C:\TSFDA4\...` in `stderr_path`. That value described a disposition but was not a filesystem path, so the closed validator correctly failed while resolving it. The failed result and its hashes remain preserved; it is not relabeled as passing.

## Corrected evidence contract

`stderr_path` now names the real repository-relative `PER_COMMAND_STDERR_MANIFEST.json`. The manifest binds the aggregate suite, disposable detached candidate, command, timing, numeric exit, evidence root, and all 31 child-command stderr files and SHA-256 values. The aggregate coverage row hashes the manifest itself. No prose, fake file, or synthesized empty stderr replaces the child evidence.

The shared path validator rejects control characters, malformed drive prefixes, prose/classification prefixes, missing files, directories where files are required, and traversal outside explicitly approved roots. Blank paths remain invalid unless a caller invokes an explicit schema rule allowing them. The manifest validator also rejects missing or changed child files, duplicate child IDs or paths, stale candidate identity, invalid exits, and paths escaping the declared evidence root.

## Hash domains and historical evidence

Canonical release-packet integrity remains `CANONICAL_GIT_BLOB_BYTES_V1`; working-tree hashes and expected Git text materialization remain separate. The previous full-acceptance wrapper whose numeric exit was not reliably retained remains `EXIT_NOT_RELIABLY_OBSERVED`. The corrected working-tree acceptance row continues to report its independently observed exit 0 and disposable pre-amend identity without claiming final-commit binding.
