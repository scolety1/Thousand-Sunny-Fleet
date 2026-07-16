# Denial Persistence

`DENY REQUEST` produces a canonical immutable `tsf_tim_required_response_v1` record with `terminal_disposition: TIM_REQUIRED_DENIED`, empty `authority_granted`, and null approval/revision links. It never invokes mission preparation or the foreground executor.

Deterministic identity:

- mission/run/result: `m2b-contract-approval-denial-0001-mrmrdc5w-27204` / `canonical-result-m2b-contract-approval-denial-0001-mrmrdc5w-27204-1`
- request: `timreq-b82f2ab46ddeb1822e15d220600a6d31`
- request evidence: `eb1476a5863a7cd3692e55b70c90986ee88e3cff5159cd0ecabddca7def2f631`
- response: `hq-response-contract-20260715-0002`
- response-record SHA-256: `f2997ec0d140ddd1e8a4240727eb49ac47302947febc530e1fa47076d7674cd6`
- original queue SHA-256: `db4d3dcac727a32ef8de40c92851ef5b98c61b59e1c7786efc6988f016b486da`

Assertions established no approval, revision-2 mission, queue, worker, verifier, admission, or fabricated receipt. Exact denial replay is idempotent; changing the bounded reason under the response ID fails closed.
