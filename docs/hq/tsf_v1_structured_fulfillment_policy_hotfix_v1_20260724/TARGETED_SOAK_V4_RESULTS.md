# Targeted Soak V4

The V4 runner executes 21 bounded cases covering:

- two structured analytical successes;
- excellent generic prose;
- two generic inability paths;
- structured inability, missing deliverable, wrong task, and policy block;
- exact success and mismatch;
- detached write denial and safe-alternative confirmation;
- duplicate, changed, and one-active replay protection;
- interruption/recovery;
- responsive populated UI;
- runtime cleanliness;
- final Stop and Doctor;
- syntax, JSON, packet, and diff integrity.

The runner fails on any nonzero mandatory result, records stdout/stderr hashes per case, writes `TARGETED_SOAK_V4_RESULT.json`, and seals the evidence with `SHA256SUMS.txt`.

The pre-final documentation run on HEAD `789293aa4150d22d76470e365c64009c96b21b32` executed every case. Twenty cases passed. The sole deferred case was final Doctor, which correctly returned exit 4 because the worktree intentionally contained the two uncommitted, evidence-preserved test-harness corrections:

- route the A-G proof runner to its own authorized evidence boundary;
- hash documentation in a canonical LF text domain so Windows CRLF materialization cannot create a false packet mismatch.

No functional case failed. The pre-final result records zero generic-text admissions, two valid structured admissions, and zero phrase-based false rejections. Its SHA-256 is:

`11df45b47ed67e69ce6603c48d82399294f7862106506249df60151524902863`

This is not represented as final GREEN. Publication requires the clean exact candidate to rerun all 21 cases and Doctor after the final documentation amendment.
