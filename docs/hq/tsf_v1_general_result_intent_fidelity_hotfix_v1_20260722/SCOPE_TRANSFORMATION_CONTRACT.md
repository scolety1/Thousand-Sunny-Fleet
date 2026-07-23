# SCOPE_TRANSFORMATION_V1

Schema: `fleet/control/scope-transformation.schema.v1.json`.

The contract compares original goal/operations with proposed and actual mission goal/operations and records access, repository/worktree, detached-HEAD state, denied authority, unperformed actions, confirmation state, queue permission, and exact next action.

Closed classifications are `NO_MATERIAL_CHANGE`, `SAFE_PRESENTATION_NORMALIZATION`, `MATERIAL_SCOPE_REDUCTION`, `AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION`, `GOAL_CHANGED`, `REQUEST_UNFULFILLABLE_UNDER_CURRENT_AUTHORITY`, and `AMBIGUOUS_REQUIRES_TIM`.

Only the first two are queueable. V1 never converts submission of the original preview into confirmation of a material reduction. On detached HEAD, a write/commit request explicitly requires an attached approved branch and creates no queue, worker, verifier, admission, or fulfillment claim.
