# Risk and Sensitivity Policy

Policy mode: descriptive, fail closed, human review only.

`UNKNOWN_RISK_OR_PERMISSION_REQUIRES_REVIEW`

Unknown metadata does not become low risk. A reported name or state does not establish permission scope, authentication requirements, connectivity, network behavior, host availability, enablement, or capability.

Manual review must consider local repository read and write, authenticated browser access, connected email/calendar/storage, network access, external account data, UI/computer control, plugin installation or enablement, invocation and action, and secrets or credentials.

Sensitive connected-account candidates require an exact future mission before further evaluation. This statement is a review expectation, not approval or an approval matcher. Computer Use is a broad-control, last-resort review concern. Google Drive joins the sensitive review pool where connected-account access would be required.

The static classification vocabulary is:

- `TSF_CORE_REQUIRED_CANDIDATE`
- `TSF_CORE_OPTIONAL_CANDIDATE`
- `PROJECT_SPECIFIC_CANDIDATE`
- `RESEARCH_ONLY`
- `REVIEW_ONLY`
- `ARTIFACT_CAPABILITY`
- `SENSITIVE_CONNECTOR_MISSION_ONLY`
- `HIGH_RISK_LAST_RESORT`
- `EXPERIMENTAL`
- `REDUNDANT_OR_OVERLAPPING`
- `OPAQUE_QUARANTINED`
- `UNSAFE_OR_REJECTED`

No classification proves need or availability. No classification grants approval, mission permission, policy, admission, or operational authority.
