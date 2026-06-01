# Backend-Sensitive Lane

Use for auth, payments, deployment config, production data, migrations, dependencies, secrets, external API contracts, and backend services.

Pass example: "Draft a migration plan with approval status, rollback steps, compatibility notes, and local test evidence."

Fail example: "Update dependencies and deploy during an overnight website polish run."

More pass examples:

- "Prepare a dependency update proposal listing affected packages, test plan, rollback plan, and captain approval status, without editing package files."
- "Review an API contract change and write compatibility notes plus local test evidence before any implementation."
- "Create a deployment checklist for a staging release, marked draft until the captain explicitly approves."

More fail examples:

- "Add Stripe checkout to the restaurant demo during a normal hospitality website run."
- "Edit `.env` or store an API token so the fixture can use a real service."
- "Run deploy/push/merge automatically after tests pass."
- "Fold auth migration work into a maintenance patch because it is only a small file change."

Required evidence: approval note, changed files list, risk assessment, tests, rollback instructions, secret/scope scan, migration/API notes when relevant.

Forbidden by default: autonomous execution without approval, broad refactors, secret storage, payment/auth work inside normal website runs, deploy/push/merge.
