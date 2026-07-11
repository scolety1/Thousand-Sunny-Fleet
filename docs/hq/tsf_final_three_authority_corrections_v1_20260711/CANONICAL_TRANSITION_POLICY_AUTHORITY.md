# Canonical Transition Policy Authority

Production queue transitions derive both policy files from the verified repository top-level:

- `fleet/control/mission-queue-state-policy.v1.json`
- `fleet/control/mission-queue-foreground-executor-policy.v1.json`

The resolver verifies canonical containment, clean working-tree identity for each policy, committed blob identity at HEAD, and a combined authority hash before a policy is read or queue state can mutate.

Normal `PolicyPath`, `StatePolicyPath`, or executor-policy overrides fail before file read or transition. Existing public parameters remain only as rejecting compatibility boundaries; they do not select production policy.

Alternate policy files require an in-memory `TEST_ONLY_TRANSITION_POLICY_CAPABILITY`, an isolated test queue authority, and paths under approved fixture locations. Such results remain `TEST_ONLY`, cannot be production admission, and do not create a second queue or state machine.
