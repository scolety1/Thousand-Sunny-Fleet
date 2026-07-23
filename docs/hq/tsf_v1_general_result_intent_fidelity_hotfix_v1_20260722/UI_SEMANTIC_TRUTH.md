# UI semantic truth

The operator vocabulary separates foreground transport from fulfillment, verifier disposition, and admission. A returned message, successful app-server round trip, or worker claim is not labeled task success.

Preview data exposes original requested goal/operations, proposed mission goal/operations, scope classification, denied authority, unperformed operations, queue gate, and exact next action. Status/result data exposes transport status, worker claim, canonical semantic disposition, required/observed/missing deliverables, verifier evidence, and admission disposition without granting authority. The renderer uses only the records projected by HQ Dispatch; it does not infer a second result, verifier, admission, or policy decision.

Detached write requests must show: attached approved branch required; no queue created; no worker started; no verifier or admission exists; no request fulfillment claimed. The request-retention notice states that request text is retained in the hashed original-intent contract and warns against credential content.

The outcome vocabulary distinguishes `FULFILLED`, `FULFILLED_WITH_CAVEATS`, `PARTIAL`, `UNABLE_TO_PERFORM`, `REFUSED`, `BLOCKED_BY_POLICY`, `NEEDS_CLARIFICATION`, `REQUIRED_DELIVERABLE_MISSING`, `WRONG_TASK_PERFORMED`, `FAILED`, and `UNCLASSIFIED_RESULT`. Non-admissible states explicitly display `NOT_ADMITTED`, the missing deliverables, verifier rejection where present, and the exact next action. Green success treatment is limited to canonically admitted fulfilled outcomes.

The assertion-derived browser proof covers fulfilled, unable, missing-deliverable, partial, wrong-task, policy-block, detached-authority, TIM-alternative, exact-success, exact-mismatch, and cross-revision states at 320, 375, 390, 768, and 1180 pixels. It requires no page-level overflow hiding, no off-viewport or clipped controls, labeled controls, visible keyboard focus, live outcome regions, safely wrapped long values, text labels in addition to color, and no production test-only controls. Each 375-pixel screenshot is framed on the relevant preview or mission truth surface.

Any projection that collapses transport and semantic status, treats response presence as fulfillment, hides the original authority-bearing intent, or displays stale identity evidence as current success is release-blocking.
