# Native fast-fail diagnostics and packet-seal proof

`tests/run-tsf-native-fast-fail-diagnostic-v1.ps1` launches one exact Node child with `--report-on-fatalerror`, `--report-uncaught-exception`, `--trace-uncaught`, and `--trace-exit`. Each fresh evidence root records the child PID/start time, executable and Node version, numeric and hexadecimal exit, durable stage trace, stdout/stderr hashes, bounded Windows-event correlation, diagnostic reports, and a blocker on failure. Environment values, tokens, and capabilities are not recorded.

The six-level child-process ladder separates import, server creation, abort, Stop, close, and full assertion stages. Safe variants passed at every level before the correction; selected legacy handler-close comparisons also passed, demonstrating nondeterminism rather than disproving the preserved crash. After the correction, the full focused test passed once fresh and twice consecutively, and the M3 aggregate passed 71/71.

The exact packet-seal Proof 2 candidate was `57c0b873808c416c4c4d2d7d689c02f198ff7cbb`, tree `65e8639d08c5582549f89028f9614bff8e62c8ba`. These rows are intentionally labeled pre-final packet-seal evidence: editing and committing this packet necessarily creates a successor commit, so the publication candidate is verified by the fresh detached runtime self-check rather than by an impossible self-referential tracked hash.

| Run | Child PID | Exit | Last stage | Assertions | stdout SHA-256 | stderr SHA-256 |
| --- | ---: | --- | --- | ---: | --- | --- |
| packet-seal-proof2-native-fetch-1 | 32252 | `0x00000000` | `TEST_ASSERTIONS_COMPLETE` | 93 | `101ab114dec1b65fefbb73a5dda0102845c30a1db07d26f6db2a121c59ec3792` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| packet-seal-proof2-native-fetch-2 | 1584 | `0x00000000` | `TEST_ASSERTIONS_COMPLETE` | 93 | `8f7fdee521d59e033f28b84c83567cae6d3ce4d519b3732f8a7fd6e1c93aa06e` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Neither run produced a Node diagnostic report or residual child process. No native failure was ignored or converted to success.

The first full-acceptance invocation used `.codex-local/final-proof`, outside the responsive harness's required `.codex-local/evidence` root. That invocation is preserved as an explicit invocation-path failure. The corrected-root invocation then passed 31/31 checks and 1,163 criteria with reliable numeric exit 0; this was not a retry of a native crash.
