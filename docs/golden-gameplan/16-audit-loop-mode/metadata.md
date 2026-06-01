# Audit Loop Metadata

Audit Loop Mode is optional and opt-in. Metadata tells Codex Fleet what a specific project wants reviewed, what evidence is safe to package, what must stay out, and when to stop the loop.

The metadata schema lives at `templates/audit-loop-metadata-schema.json`.

## Required Fields

| Field | Purpose |
| --- | --- |
| `projectName` | Human-readable name for audit package titles and reports. |
| `repository` | Selected repo or fixture root. This is a declaration, not permission to bypass runtime scope policy. |
| `surfaces` | All known project surfaces. Examples: `public-site`, `admin-console`, `analytics-model`, `harness-docs`. |
| `inScopeSurfaces` | The surfaces included in this audit loop. Keep this smaller than all surfaces when possible. |
| `safeDataSources` | Fixture data, docs, logs, sanitized diffs, and other evidence that may be packaged. |
| `forbiddenDataSources` | Secrets, private customer data, `.git`, dependency folders, generated output, raw locks, and undeclared repos. |
| `auditPackageFiles` | High-signal files to include in the compact audit package. |
| `defaultChecks` | Focused checks that implementation tasks should run. |
| `maxTasks` | Maximum task count produced from one audit report. Use a small number by default. |
| `acceptedLimitations` | Known caveats that should not regenerate the same task every cycle. |
| `ownerContact` | Captain or owner note for ambiguous decisions. |
| `riskTier` | One of `fixture`, `safe-demo`, `product-demo`, or `sensitive`. |
| `requiresCaptainApproval` | Whether queue conversion or execution requires explicit captain approval. |

## Project-Neutral Surface Examples

Use generic surface names so this mode works outside HouseOS:

- `public-site`
- `internal-tool`
- `mobile-console`
- `analytical-model`
- `backend-sensitive`
- `maintenance`
- `harness-docs`

Do not make HouseOS field names globally required. Names like Customer, Manager, Staff, PublicRestaurantData, RestaurantConfig, or SharedRestaurantRecord belong in HouseOS project metadata only.

## Safety Semantics

Metadata narrows scope but does not grant execution permission. Runtime validation still controls path safety, state, budgets, task packets, approvals, and forbidden domains.

Use `safeDataSources` and `forbiddenDataSources` separately:

- `safeDataSources` tells the package builder what evidence may be copied.
- `forbiddenDataSources` tells it what must never be copied, even if a task or audit asks for it.

For dirty repositories, the audit package must include sanitized diffs or source snapshots for changed harness files. Dirty state without reviewable evidence should produce a YELLOW or RED audit result.

## Example Metadata

```json
{
  "projectName": "Fixture Audit Loop Demo",
  "repository": "C:/Dev/codex-fleet",
  "surfaces": ["harness-docs", "fixture-tests"],
  "inScopeSurfaces": ["harness-docs"],
  "safeDataSources": [
    "docs/golden-gameplan/16-audit-loop-mode/",
    "templates/audit-loop-metadata-schema.json",
    "tests/run-fleet-tests.ps1"
  ],
  "forbiddenDataSources": [
    ".env",
    ".git/",
    "node_modules/",
    "dist/",
    ".codex-local/locks/",
    "C:/Users/"
  ],
  "auditPackageFiles": [
    "docs/golden-gameplan/16-audit-loop-mode/stage-plan.md",
    "docs/golden-gameplan/16-audit-loop-mode/audit-loop-mode-spec.md",
    "docs/golden-gameplan/16-audit-loop-mode/metadata.md",
    "templates/audit-loop-metadata-schema.json"
  ],
  "defaultChecks": [
    "powershell -NoProfile -ExecutionPolicy Bypass -Command \"Get-Content templates/audit-loop-metadata-schema.json -Raw | ConvertFrom-Json | Out-Null\""
  ],
  "maxTasks": 8,
  "acceptedLimitations": [
    "No live external-agent transport is implemented in this stage.",
    "Real product repos require a separate explicit approval."
  ],
  "ownerContact": "Captain review required for product-specific taste decisions.",
  "riskTier": "fixture",
  "requiresCaptainApproval": false
}
```

## Validation Expectations

Focused tests should prove:

- The schema parses as JSON.
- Every required metadata field exists.
- `riskTier` uses the shared risk vocabulary.
- Metadata docs explain each field.
- The docs warn that HouseOS-specific fields stay local and should not become global requirements.
