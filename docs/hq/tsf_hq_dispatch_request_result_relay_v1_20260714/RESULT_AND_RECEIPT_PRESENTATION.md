# Result and Receipt Presentation

The versioned status projection retains state, canonical source record/path, mission/revision, run/result identity, timestamp, assurance, and explanation. It exposes route/access, worker thread/turn when observed, verifier, preservation, admission reasons/caveats, replay protection, authority denials, and exact next action.

Only a canonical `ADMITTED` or `ADMITTED_WITH_CAVEATS` receipt becomes an accepted terminal UI state. Worker completion without admission is `REJECTED`; the live proof demonstrated this fail-closed behavior. Secrets, raw credentials, arbitrary file contents, and caller-selected paths are not rendered.
