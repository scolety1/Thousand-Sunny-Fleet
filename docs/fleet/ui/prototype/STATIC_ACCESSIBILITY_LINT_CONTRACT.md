# Static Accessibility Lint Contract

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet local static Fleet Console prototype.

This contract is evidence only. It defines local static review expectations for the prototype. It does not approve scripts, package installs, browser automation, live UI execution, remote access, product-repo access, package creation, package sending, runtime command binding, phone approvals, staging, commit, push, deploy, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, or future authority.

## Purpose

The static accessibility lint path checks whether the local HTML/CSS prototype preserves basic review readability while staying non-operational. It is a docs/tests guardrail, not a runtime accessibility scanner.

## Required Static Checks

Future local static lint assertions should stay limited to committed prototype files and may check:

- Skip link: the page includes a skip link to the main local mock content.
- Landmarks: the page includes a `main` landmark and labelled local review regions.
- Heading order: headings remain readable and nested in a predictable review order.
- Labels and states: mock controls, tables, disabled states, unavailable states, future-only states, and forbidden states have labels or descriptions.
- Focus-visible CSS: focusable local links and the main target keep visible keyboard focus treatment.
- Narrow-screen readability: panels, rows, fixture names, labels, and status text can wrap without overlap.
- CSS-disabled readability: core evidence-only and non-authority boundaries remain visible in document order.
- Evidence-only safety copy: accessibility polish does not imply approval, execution, package sending, command binding, remote access, product-repo work, phone approval, or future authority.

## Allowed Future Tooling

Any future automated accessibility tooling must be separately queued before use. It must be local, dependency-approved, non-networked, bounded to allowed files, and validated by an explicit task. Passing tooling output remains evidence only.

## Forbidden Expansion

This contract does not allow:

- package installs or dependency changes
- browser automation, screenshots, or dev server setup
- JavaScript, forms, network fetches, remote fonts, or remote resources
- live state reads or runtime command binding
- product-repo access or product mutation
- package creation or package sending
- staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or all-fleet execution

## Stop Conditions

Stop and repacketize if accessibility validation would require files outside the selected task, package installation, browser automation, network access, product repos, runtime behavior, remote access, package sending, or any approval/command-binding interpretation.
