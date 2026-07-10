# Result Envelope Contract V1

The canonical result schema is `fleet/control/result-envelope.schema.v1.json`, version `tsf_result_envelope_v1`.

It records what the surface actually did: task identity when available, observed or unknown model settings, repository/branch/worktree and Git facts, files and actions, network activity, artifacts and hashes, test observations, verifier evidence, approval use, deviations, uncertainty, warnings, and next action. Protected structured actions use `ACTION:<action_id>` in `major_actions` so admission can compare them to `forbidden_actions`; free prose never creates approval.

Unknown native settings are legal as `null`, `UNKNOWN`, or `RECOMMENDED_ONLY`; fabricated confirmation is invalid evidence. Results default to no authority and must explicitly set `grants_approval`, `grants_merge_authority`, and `grants_production_authority` false. A true authority flag routes to `TIM_REQUIRED`; prose never creates approval.
