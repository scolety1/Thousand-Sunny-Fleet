# Clarification Revision

Clarification is accepted only for a canonical `CLARIFICATION_REQUIRED` request. Input is trimmed plain text, 1–2000 characters, null-free, and checked for secret-like and executable/command content. The raw text is held only in the canonical response/context record; evidence documents retain its hash and do not reproduce any secret-like value.

The response writer never changes the original mission/result. `New-TsfHqDispatchGovernedMission.ps1` accepts a closed response-bound revision input, verifies the response-record hash and original terminal request, reruns Project Main Bot, recomputes route/model/effort/access/network/reads/writes/restrictions/approvals/clarifications/stops, and creates a new canonical mission/queue identity.

Authority-neutral deterministic identity:

- mission: `m2b-contract-clarification-clarification-0001-mrmrdc5w-27204`
- source/new revisions: `1` → `2`
- source/new runs: `canonical-result-m2b-contract-clarification-clarification-0001-mrmrdc5w-27204-1` → `canonical-result-m2b-contract-clarification-clarification-0001-mrmrdc5w-27204-2`
- request: `timreq-87dc7356c6cf88a919bcfb565a455433`
- response: `hq-response-contract-20260715-0003`
- response record SHA-256: `8384de80b7ff8ed6fcd589617254b7e02a213a40dc26bb255a4a1a1eaed8ff7a`
- revision-2 queue SHA-256: `9825ca257c456612ca0ad759aff040520d17e0d51e840e2c2d9a03c9bad4d4da`

An authority-relevant route-change fixture used response `hq-response-contract-20260715-0006`. Revision 2 stopped before a worker at a fresh `APPROVAL_REQUIRED` request; it did not reuse the clarification request ID. Its blocked queue SHA-256 is `417003c85b13c41828a651c850a6fa04f421cf74cffac1b8e0f70dd1889c60f0`.
