# Real runtime-cleanliness proof

Corrected focused command `node tests/test-tsf-runtime-queue-cleanliness-v1.mjs` passed 87 assertions from `2026-07-18T05:56:06.5278221Z` through `2026-07-18T05:57:12.1478856Z`. Exit was `0`; stdout SHA-256 was `0336b0db3dcca3087cc4a7b7f02e6b78aa2f50c607530f96265a1d529cf9553f`; stderr SHA-256 was `877675458e747776a4c46ba39ffd03b696bb5fe4483377941723e260799a61f2` (the captured Git line-ending warning, not a test failure).

It generated complete canonical queued, running, TIM_REQUIRED, admitted, rejected, interrupted, recovered, and exact-replay records through `ConvertTo-TsfCanonicalExecutionArtifacts`; each record was ignored only by its exact state-specific `*.r*.json` rule. Doctor accepted only records that passed the authoritative canonical validator and reported the validation authority, queue root, states, and counts.

The same proof then:

1. rejected identity-only, empty, missing-schema, missing-packet, missing-integrity, malformed, wrong-schema, wrong-state, filename/revision/case-mismatch, duplicate, and arbitrary protected JSON;
2. created real file symlinks to a valid record, an outside file, and another worktree plus a real directory junction; Doctor rejected every link/reparse path without following it and every target hash remained unchanged;
3. created an unrelated untracked sentinel and observed the exact unsafe Doctor status line;
4. modified and then staged a tracked `.gitkeep`, observed both unsafe states, and restored the index and exact bytes;
5. ran Stop and proved every canonical fixture record byte-stable;
6. removed only test-owned fixtures and observed canonical runtime safety restored.

The final detached production harness repeats the mission/Stop/sentinel sequence without deleting the admitted queue record and records its final inventory and Git status.

The integrated wrong-result proof is documented separately in `DETERMINISTIC_WRONG_RESULT_PROOF.md`. It executes preview, submission, mission/queue, the production adapter with a deterministic fake app-server response, independent verifier, preservation, replay, terminal lifecycle, and no-admission presentation in one path.
