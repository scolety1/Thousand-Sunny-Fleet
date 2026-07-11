# Mission Envelope Contract V1

The canonical cross-surface schema is `fleet/control/mission-envelope.schema.v1.json`, version `tsf_mission_envelope_v1`.

It preserves request and normalized goal, project and parent identity, role and replaceable execution surface, stable model alias, honest model assurance, permission/network posture, repository/source/path boundaries, branch/worktree snapshot, completion criteria, required tests and artifacts, verifier independence, stop conditions, approvals, policy fingerprint, timestamps, and required result version.

Existing kernel mission packets remain the operational format used by current lifecycle tools. A future adapter may derive a worker instruction packet from this envelope but must not weaken it.

Expiry never silently admits a result. Active-policy changes require review; returned fingerprint mismatches are rejected. Unexpected starting HEAD changes require review or rejection. Restarting in a new conversation must carry the mission ID or receive a child mission.
