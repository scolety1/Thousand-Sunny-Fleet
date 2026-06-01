# Stage 14 Phase 6 Prompt: Rollback And Recovery Checks

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 6 only: Rollback and Recovery Checks.

Goal:
Define how the fleet proves it can recover from bad runs without destroying user work.

Rollback/recovery checks should cover:
- what changed
- who owns the changes
- whether changes are staged/committed
- whether repo was dirty before run
- whether generated artifacts can be cleaned safely
- whether repair should continue or block
- whether a human must decide

Required recovery outputs:
- recovery report
- changed files list
- generated files list
- user-owned dirty files warning
- safe cleanup candidates
- forbidden cleanup list
- rollback instructions for fixture/disposable runs

Guardrails:
- Never reset or checkout user work automatically.
- Never delete outside approved fixture/workspace paths.
- Never clean dirty real repos without explicit approval.
- Do not implement rollback scripts in this docs stage.

Acceptance:
- Rollback/recovery check plan exists.
- It distinguishes fixture cleanup from real user work.
- It includes examples of safe and forbidden cleanup.

Proof:
Show rollback check doc and examples.
```

## Notes

The fleet should be brave with fixtures and gentle with real work.

## Implemented Rollback / Recovery Rules

Recovery report must include:

```text
changedFiles
generatedFiles
preExistingDirtyFiles
stagedFiles
owner
safeCleanupCandidates
forbiddenCleanupList
recommendedRecoveryAction
```

Safe cleanup examples:

- generated files under disposable fixture root
- generated reports under `out/stage14-*`
- temporary JSON fixtures created by tests

Forbidden cleanup examples:

- real product repo files
- user-owned dirty files
- `.git`
- locks and active PID files
- secrets/env files
- package/deploy/auth/payment/migration files unless explicitly approved

Rollback verdicts:

| Condition | Recovery Action |
| --- | --- |
| disposable fixture only | cleanup allowed inside fixture root |
| dirty before run | block and ask captain |
| unknown owner | block |
| generated evidence only | keep evidence until audit package is made |
| broad unexpected diff | block and write recovery report |
