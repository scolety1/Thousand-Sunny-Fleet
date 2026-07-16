# UI Authority Boundary

The TIM_REQUIRED view renders canonical scope only: operation/question, repository/worktree, exact paths, access, network, expiry, usage/reuse, reason, excluded authority, and the original-run-terminal warning.

Compatible controls are exclusive:

- Approval request: `APPROVE EXACT REQUEST` and `DENY REQUEST`
- Clarification request: `PROVIDE CLARIFICATION`

Approval and denial require their exact confirmation phrases. Clarification uses one bounded text area. There are no editable ledger, queue, evidence-root, mission-envelope, model, effort, access, network, path, verifier, result, receipt, admission, command, environment, or authority fields.

The page states that the original run is terminal, the prior worker is never resumed, a response may create a new governed revision, approval is exact and bounded, submission is not approval, and the canonical approval record or revised mission is the source of truth.

The browser never writes a canonical file. It submits the closed response contract to the session-protected loopback server, which revalidates and delegates to canonical TSF entrypoints.
