# Quick Mission Request

Status: draft
Fleet Mode: REQUEST_ONLY_TRAVEL

Evidence only; not executable authority or approval.

## Allowed Status Values

- `draft`: still being written
- `requested`: ready for later HQ/Codex review
- `blocked`: missing context or unsafe as written
- `completed`: later review handled the request

No status value executes Codex, approves work, touches product repos, or grants future authority.

## One Task

Write exactly one bounded task. If there is more than one task, split it before requesting review.

## Desired Project

Name exactly one project or write `Codex Fleet only`. Product-repo access remains forbidden by default unless a later exact task packet approves one project and one scope.

## Goal

Write one bounded task in plain language.

## Quality Mode

Choose one: `best_value` or `perfection`.

## Requested Model Tier

Optional preference only. HQ/Codex must still make a model routing and cost-quality recommendation before work starts.

## Priority

What matters most for this request?

## Requested Files

List expected files or write `unknown - needs HQ packet`. These are requested files only; they must be reviewed into `allowedFiles` before execution.

## Validation Requested

List expected checks or write `unknown - needs HQ packet`. These are requested checks only; they must be reviewed into `validationCommands` before execution.

## Forbidden Operations

The later task packet must preserve these defaults unless a separate exact approval says otherwise.

- no product-repo mutation
- no all-fleet commands
- no overnight runner
- no deploy
- no stage
- no commit
- no push
- no installs
- no migrations
- no secrets, auth, payments, credentials, tokens, keys, PINs, passwords, MFA material, recovery codes, or private device identifiers
- no lock deletion
- no permission widening
- no runtime command binding
- no phone approval
- no remote access configuration
- no GitHub Actions trigger
- no direct Codex command execution from browser or phone text

## Stop If

Stop later review if the request needs broader scope, multiple tasks, product-repo access, secrets, authentication, backend implementation, command execution, staging, commit, push, deploy, installs, migrations, lock deletion, permission widening, all-fleet, overnight, runtime command binding, phone approval, or remote access configuration.

## Do Not Do

- Do not execute this request automatically.
- Do not deploy.
- Do not stage, commit, push, or merge.
- Do not run all-fleet commands.
- Do not run an overnight runner.
- Do not touch product repos unless a later exact task packet approves one project and one scope.
- Do not change auth, payments, secrets, dependencies, deployment config, generated output, or project remotes.
- Do not configure remote access.
- Do not bind runtime commands.
- Do not approve phone actions.
- Do not delete locks or widen permissions.
- Do not overwrite user-owned work.

## Next Checkpoint

What should the later HQ/Codex review prove before any work starts?

## Later HQ/Codex Review Must Produce

- task id or selected task
- Phase 0 gate with lane scope declaration, allowed search scope, forbidden search scope, existing-asset trace, classification, reuse decision, build permission explanation, and `TIM_REQUIRED_SCOPE_EXPANSION` stop behavior
- readFirst files
- allowedFiles
- validationCommands
- stopIf conditions
- report format
- policy classification
- model routing / cost-quality recommendation
- audit notes without secrets

## How To Use

Edit this file on GitHub from your phone only to leave a request. Change `Status` from `draft` to `requested` only after the one task, desired project, requested files, validation requested, forbidden operations, and checkpoint are clear.

`requested` means "review this later." It does not run Codex, update mission files automatically, touch product repos, approve execution, or grant future authority.
