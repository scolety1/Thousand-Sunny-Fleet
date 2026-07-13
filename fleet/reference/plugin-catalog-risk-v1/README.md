# TSF Plugin Catalog and Risk Baseline V1

Baseline: `REVIEW_ONLY_REFERENCE_NOT_RUNTIME_ENFORCED`

This directory contains static, human-consulted reference data for Thousand Sunny Fleet HQ and future mission designers. It records user-supplied, unverified plugin names and reported states; descriptive classification, quarantine, sensitivity, and risk metadata; non-operational pack labels; and a manual review sequence.

It is non-operational and non-authoritative. Nothing here selects, installs, enables, connects, authenticates, probes, loads, invokes, or operates a plugin. Nothing grants approval, policy, permission, admission, mission, routing, commit, push, merge, deployment, or production authority. Runtime admission and Project Main Bot do not load this directory.

Unknown publisher, version, manifest, permission, authentication, connection, network, host, enablement, and capability-probe facts remain `null` or `UNKNOWN`. `AVAILABLE` and `DISCOVERED` are user-reported seed states, not current host observations.

Files:

- `plugin-catalog.schema.v1.json`: isolated schema for the 36-record static catalog.
- `plugin-catalog.v1.json`: user-supplied, unverified seed records with zero runtime observations.
- `plugin-risk-policy.v1.json`: descriptive classifications, risk considerations, and fail-closed review rule.
- `plugin-packs-reference.v1.json`: five non-operational labels and review pools.
- `plugin-review-priority.v1.json`: human/HQ review order and allowed manual dispositions.

The parked advanced research branch is source-trace material only and must not be treated as canonical. See the companion HQ packet under `docs/hq/tsf_plugin_catalog_risk_v1_20260713/`.
