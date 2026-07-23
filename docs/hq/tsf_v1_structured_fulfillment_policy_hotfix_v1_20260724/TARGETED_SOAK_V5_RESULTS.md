# Targeted Soak V5 Results

Targeted Soak V5 extends V4 with explicit, separate recovery criteria:

- one real structured admitted interruption/recovery;
- one deterministic generic recovery preserved without admission.

The runner contains 23 mandatory cases and fails on any unexpected numeric
exit. It records stdout, stderr, duration, and SHA-256 identity for every
case, then writes `TARGETED_SOAK_V5_RESULT.json` and a bundle manifest.

Required invariants include:

- generic text admissions: zero;
- structured valid admissions: three, including one recovery;
- generic recovery admissions: zero;
- structured inability, missing deliverable, and wrong-task admission: zero;
- exact-literal success and mismatch rejection unchanged;
- replay and one-active protections unchanged;
- no owner, listener, or proof-owned process after final Stop;
- a clean, exact candidate HEAD and tree.

The committed implementation packet records the runner and its required
criteria. Final detached-candidate result identity is recorded in
`VALIDATION.json` after the exact-candidate gate is completed.

## Pre-final evidence-amendment run

The clean detached candidate `d9b32aad965b454bfe033af3462f64cac01d4abf`
with tree `6fbcf1911a57289654243bcc10fdb0e409973865` passed all 23
cases.

- Result:
  `C:\TSF_RECOVERY_PROOF1\.codex-local\evidence\structured-fulfillment-soak-v5\candidate-d9b32aa-exact-pass1\TARGETED_SOAK_V5_RESULT.json`
- Result SHA-256:
  `cb96e767c213f194dfae5c5e6926af09c88edb6dc1026d141d7fbeac248db0a6`
- Bundle-manifest SHA-256:
  `d92299a158b3c6b347908b459b9bbb3089455b3408ed598fb3e72d8c7d5838de`
- Real structured interruption/recovery: PASS, 201 assertions.
- Generic-text admissions: zero.
- Structured valid admissions: three.
- Structured recovery admissions: one.
- Generic recovery admissions: zero.

This result authorizes the evidence-only amendment. Publication still
requires full acceptance and independent reviews of the exact post-amendment
candidate.
