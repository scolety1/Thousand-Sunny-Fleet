# Canonical Authority Map

| Durable field or result claim | Canonical operational owner | Translation or evidence source | Executable consumer |
|---|---|---|---|
| Mission identity, revision, intent, policy binding | Durable mission envelope | Content hash and source binding | Durable translator and admission |
| Worker role | Worker-role registry | Exact `role_id` lookup | Role preflight/lifecycle |
| Permissions | Permission-profile registry | Profile keyed by worker role | Kernel and role permission preflight |
| Repository and paths | Kernel canonical path helpers | Observed Git top-level and filesystem paths | Kernel and admission |
| Model alias | Model routing policy | Stable alias or explicit legacy map | Translator and admission |
| Approval | Existing approval ledger | Native exact-action matcher | Kernel preflight and admission |
| Execution | Existing mission packet, role extension, worker packet | Deterministic durable translation | Lifecycle runner and worker adapter |
| Tests, Git, files, artifacts | Existing runtime plus filesystem observation | Runtime result mapper | Admission |
| Verifier | Existing verifier result | `VERIFIER_OBSERVED` evidence | Admission |
| Preservation and receipt | Existing preservation packet directory | Deterministic `admission/` link | Admission/idempotency |
| Queue state | Existing queue-state policy | Existing transition validator | `Move-TsfMissionState.ps1` |

The bounded schema validator supports only the constructs used by the admitted contracts: required fields, primitive and nested types, arrays/items, enums, constants, min/max bounds, patterns, additional-properties denial, nullability, unique items, date-time format, and local `$ref`.
