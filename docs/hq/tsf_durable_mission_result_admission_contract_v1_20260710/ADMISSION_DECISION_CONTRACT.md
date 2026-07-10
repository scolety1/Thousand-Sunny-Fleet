# Admission Decision Contract V1

Admission is deterministic evidence classification, not execution approval.

| Status | Rule |
|---|---|
| `ADMITTED` | Registered mission/result match and all blocking evidence exists. |
| `ADMITTED_WITH_CAVEATS` | Compliant result has honest non-blocking uncertainty or unavailable native identity/model facts. |
| `REVIEW_REQUIRED` | Recoverable policy change, expiry, branch advance, deviation, or missing independent verifier. |
| `REJECTED_OUT_OF_SCOPE` | Repository, path, branch/worktree, or network violates mission scope. |
| `REJECTED_POLICY_MISMATCH` | Returned fingerprint differs from the mission. |
| `REJECTED_INVALID_EVIDENCE` | Required tests, artifacts, hashes, or valid shape are absent. |
| `UNTRUSTED_NOT_TSF_GOVERNED` | Mission ID is absent/unknown, including bypass Work or Codex work. |
| `TIM_REQUIRED` | Result attempts to grant approval, merge, or production authority, or stale policy requires Tim. |

Unknown mission identity is classified first, then invalid shape, authority escalation, policy mismatch, scope, and evidence. Protected actions fail closed.

Exact resubmission of the same result ID and hash returns the preserved receipt with `idempotent_replay: true`. Reusing an ID with different content is invalid. Missing native task ID can be a caveat. Direct bypass work is never retroactively labeled TSF-governed.
