# Canonical Submission Contract

The client may supply only natural request, preview ID/hash, request hash, server-generated submission ID, and exact intent `CREATE_GOVERNED_MISSION`.

Before preparation the server re-reads and hashes the stored preview artifact, recomputes the route through the unchanged Milestone 1 wrapper, and compares project/lane, role, model, effort, access proposal, restrictions, source bindings, classification, and request hash. Stale, altered, mismatched, cross-session, or gated previews fail closed.

`New-TsfHqDispatchGovernedMission.ps1` then invokes Project Main Bot, constructs only the fixed TSF-local read-only fixture envelope, validates it with the durable contract, generates canonical runtime paths, and calls `New-TsfCanonicalQueueMission.ps1`. Browser input cannot select paths, queue root, executable, arguments, environment, model, effort, access, network, thread, approval, verifier, or admission state.
