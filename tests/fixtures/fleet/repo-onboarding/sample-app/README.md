# Repo Onboarding Sample App

This fixture gives TSF a safe local target for repo onboarding validation.

It intentionally includes a report export workflow in docs, scripts, package
scripts, and tests so the existing-feature detector can prove duplicate/reuse
classification without reading or mutating a product repo.

## Workflows

- Report export: `scripts/export-report.ps1`
- Test entrypoint: `npm test`
- Build entrypoint: `npm run build`
