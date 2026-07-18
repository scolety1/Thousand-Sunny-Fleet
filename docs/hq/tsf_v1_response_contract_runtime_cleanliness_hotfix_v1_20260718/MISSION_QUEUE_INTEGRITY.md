# Mission queue integrity

The hotfix reuses `Resolve-TsfQueueAuthority`, `New-TsfCanonicalQueueMission.ps1`, `Move-TsfMissionState.ps1`, the foreground queue executor, lifecycle, preservation, and admission entrypoints. No alternate production queue or caller-selected root was added.

Integrity properties exercised by the matrix:

- one canonical filename per mission and revision;
- complete canonical queue-document validation before inventory trust;
- exact parent-directory state authority without mutating immutable queue-document bytes;
- normalized containment and non-following rejection of symbolic links, junctions, and reparse points;
- existing atomic queue moves and transactional receipt binding remain unchanged;
- exact replay returns the original receipt without a second execution;
- changed-content replay and substituted destination records fail closed;
- `complete_ready_for_gate` remains readable;
- admission receipt, durable result, preservation packet, verifier result, and queue identities remain linked;
- test-only alternate roots still require the existing explicit isolated capability;
- current worktree identity is rebound only in synthetic final-three fixtures, allowing the same authority suite to validate attached and detached candidates.

The Doctor matrix passed 87 assertions. It covers queued, running, TIM_REQUIRED, admitted, rejected, interrupted, recovered, and exact-replay documents plus malformed/incomplete/schema-invalid documents, identity and state mismatches, duplicate records, unknown protected files, real link/reparse attacks, source dirtiness, and Stop preservation. The canonical app-server matrix previously passed 151 assertions; the final-three authority suite passed 34 assertions including exact replay and recovery substitution rejection.
