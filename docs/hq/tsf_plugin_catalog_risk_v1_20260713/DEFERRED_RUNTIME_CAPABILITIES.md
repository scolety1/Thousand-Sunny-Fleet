# Deferred Runtime Capabilities

This V1 deliberately excludes all runtime plugin work. The exclusions are architectural boundaries, not backlog items authorized by this commit.

No mission-envelope or result-envelope plugin fields, canonical admission changes, producer evidence registry, native capability evidence, runtime plugin observation, resolver, exact set-cover code, approval matcher, Project Main Bot routing, queue behavior, lifecycle behavior, app-server behavior, model routing, or policy-transition code was created or changed.

The following parked-branch implementations were not copied or reconstructed:

- `tools/TsfPluginCapability.ps1`
- `tools/TsfPluginEvidenceBinding.ps1`
- `tools/Resolve-TsfMissionPlugins.ps1`
- plugin-related changes in `tools/Invoke-TsfProjectMainBotDryRun.ps1`
- plugin-related changes in `tools/TsfDurableContract.Canonical.ps1`
- plugin-related changes in `tools/codex-fleet-enforcement-kernel.ps1`
- runtime plugin evidence fields in mission, result, and producer schemas

Also deferred and unauthorized are installation, enablement, connection, authentication, capability probing, loading, invocation, action, runtime availability verification, evidence binding, operational pilot work, and any attempt to fix the parked foundation’s decisive audit blockers in this lane.

Any future runtime proposal requires a new, explicit scope and independent architecture/security review. This baseline is not resolver input and does not make such a proposal safe or approved.
