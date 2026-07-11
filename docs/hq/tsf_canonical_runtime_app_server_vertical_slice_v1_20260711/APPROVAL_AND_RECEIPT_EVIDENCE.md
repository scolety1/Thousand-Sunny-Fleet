# Approval and Receipt Evidence

Neither live synthetic mission required approval, and the native protocol emitted no approval request. Executed tests prove exact ledger matching, expiry/state/mission/worktree/reuse checks, and fixture-approval non-authority. Real approval consumption remains deferred and approval-requiring missions fail `TIM_REQUIRED`.

Read-only:

- preservation packet: `a1c2dad35d4d886db332dd7ea472fcf18a49567b3e66f332104e05813fda1fa0`
- admission receipt: `a775fb7806902e19c1e544543d74f5cd78f95e50ad99f763d0b697db6adf4269`
- transaction receipt: `9f97e4f006151ddf06f88a4c0d47aca7c955d63b439dfad11d1b6f703479b406`, state `COMMITTED`

Workspace-write:

- preservation packet: `93f87c1cbab1c177ced8fa72c5616bcb96118ac8e350da4b72a3bf02c94b7f87`
- admission receipt: `a339cd69b323bf537cb3cdef317153e72ed43900baaa0cb397f991720e6e2136`
- transaction receipt: `435e8c6b5e6e627783f91aa0185bbb78224f8fc1d8f3de551cd08660f4fe431a`, state `COMMITTED`

Receipts are beneath the verified compact packet, use 32-character Base32 collision-checked keys, retain complete SHA-256 identities in their bodies, and cannot select an independent root. Exact replay returned the original receipt idempotently. Conflicting result-ID reuse preserved the original and produced the immutable read-only conflict record captured in the final packet snapshot.
