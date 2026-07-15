# Result and Receipt Presentation

The API/UI present mission, revision, run and result identity; route/model/effort; access and network policy; queue state; thread/turn; worker and verifier verdicts; exact expected and observed response hashes; independent-recomputation status; required tests; durable, verifier, preservation and receipt hashes; replay facts; authority denials; observation claims; caveats; and the exact next action.

Result identity is present in a result-bearing terminal status, terminal event, durable result, admission receipt, and replay. The browser projection retains `result_id` rather than dropping it. Rejected runs without a durable result or admission receipt keep both status and nested result identity null; `run_id` is never promoted into a result identity.

Observation claims distinguish:

- `POLICY_PROHIBITED` and `CONFIGURED_DISABLED`, which describe authority or configuration;
- `OBSERVED_NOT_USED`, which requires an authoritative run-bound observation;
- `NOT_OBSERVED` and `UNKNOWN`, which must carry `null` rather than an invented `false`.

In the real proof, product-repository access, plugin use, credential access, and external-network access are `NOT_OBSERVED`; worker-tool network is `CONFIGURED_DISABLED`; filesystem writes, detached/unowned child, and listener remaining are `OBSERVED_NOT_USED`. Every claim is bound to the canonical run ID.

File hashes are calculated only for existing files contained by the TSF worktree. Arbitrary file contents, session tokens, stderr, prompts, credentials, and secret-like data are not rendered. Submission is not approval, worker completion is not admission, and the canonical admission receipt remains terminal truth.
