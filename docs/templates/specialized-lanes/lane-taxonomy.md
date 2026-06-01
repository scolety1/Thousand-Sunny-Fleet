# Specialized Lane Taxonomy

Stable lane IDs:

| Lane ID | Purpose | Default Budget | Overnight Eligibility |
| --- | --- | --- | --- |
| `hospitality_website` | Guest-facing restaurant, beverage, event, catering, and local hospitality websites. | balanced | allowed with visual evidence |
| `manager_internal_tool` | Operational tools for managers, staff, kitchens, service, and events. | balanced | allowed with workflow proof |
| `analytical_software` | Formula-first models, forecasts, simulations, pricing, margin, and decision tools. | premium for correctness | allowed only with deterministic tests |
| `backend_sensitive` | Auth, payments, deployment, migrations, dependencies, secrets, production data, and external APIs. | approval required | status-only unless explicitly approved |
| `maintenance` | Small bug fixes, docs cleanup, fixture repair, status work, and narrow harness upkeep. | cheap | status or small repair |

Escalation rule: if a task touches backend-sensitive scope, package/dependency files, secrets, deployment, auth, payments, migrations, production data, or external API contracts, `backend_sensitive` overrides the normal lane.

