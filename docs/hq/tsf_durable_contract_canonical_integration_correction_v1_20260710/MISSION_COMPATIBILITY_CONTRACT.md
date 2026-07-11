# Mission Compatibility Contract

New missions use `tsf_mission_envelope_v1` and stable model aliases. `ConvertTo-TsfCanonicalExecutionArtifacts` validates the durable schema, role, permission profile, repository identity, model resolution, and all three generated operational schemas.

Identical durable input produces identical execution artifacts. The generation timestamp is the durable mission creation timestamp, so it is deterministic. Generated artifacts carry durable mission ID, revision, policy fingerprint, durable content hash, translator version, and timestamp in `source_binding`.

Compatibility labels are `CANONICAL_DURABLE_INPUT`, `LEGACY_OPERATIONAL_INPUT`, `GENERATED_EXECUTION_PACKET`, and `INVALID_CONFLICTING_REPRESENTATION`. This correction emits `GENERATED_EXECUTION_PACKET`; legacy operational packets remain legacy lifecycle inputs and are not promoted to durable assurance.
