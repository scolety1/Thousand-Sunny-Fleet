# Audit Loop Prompt Rules

Audit Loop Mode uses external reviewers as read-only critics. They help the captain and Codex Fleet see missing evidence, unsafe scope, unclear checks, and repeatability gaps. They do not execute work.

The reusable template lives at `docs/templates/audit-loop/external-audit-prompt-template.md`.

## Required Prompt Properties

Every Audit Loop prompt should include:

- The selected project name and repository/scope.
- The declared risk tier.
- In-scope and out-of-scope surfaces.
- The package, manifest, and evidence index paths.
- The current `maxTasks` limit.
- Accepted limitations that should not generate duplicate tasks.
- A read-only reviewer rule.
- A clear `Do not edit code` instruction.
- The verdict options: `Ready`, `Ready with caveats`, and `Not ready`.
- Separate sections for package completeness, implementation completeness, safety/scope, repeatability gaps, and prioritized issues.

## Why The Prompt Is Structured

The prompt separates review categories so a missing package file does not get mistaken for a missing repo implementation. It also stops the reviewer from turning product taste, accepted limitations, or vague concerns into automatic work.

## Safety Rules

- External reviewers are not executors.
- They should not request broad repo rewrites or all-fleet actions.
- They should not ask for secrets, production data, deployment, auth, payments, migrations, dependency changes, raw lock files, or private user files.
- They should not turn HouseOS/customer-website rules into global Fleet policy.
- They should respect `maxTasks` and prioritize bounded, checkable issues.

## Verdict Semantics

- `Ready`: the evidence supports the current claim and no blocking issue remains.
- `Ready with caveats`: the evidence is mostly sufficient, but the reviewer found non-blocking limitations or future improvements.
- `Not ready`: evidence, implementation, safety, or repeatability gaps block use of the loop.

## Local Product Context

Project-specific context may be added under a clearly labeled local block. For example, HouseOS can name its customer website surfaces and data shapes there. Other projects should provide their own local context instead of inheriting HouseOS-specific assumptions.

## Queue Conversion Guidance

Only findings that are specific, bounded, safe, and checkable should become queue tasks. Accepted limitations should be recorded and skipped unless the audit identifies new evidence that changes the risk.
