# PrivateLens Read-Only Inspection Approval Packet

Prepared: 2026-07-02

Draft only; not approved; no inspection is authorized until Tim gives exact
approval for this packet.

## TSF-Local Repo Evidence

TSF-local status currently names this PrivateLens repo path:

```text
C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-privatelens\outputs\privatelens
```

TSF-local passport evidence also says PrivateLens status is `UNKNOWN` and the
registered project is not available on this machine. Treat that as a caution,
not as permission to search elsewhere.

## Proposed read-only inspection scope

After Tim gives exact approval, Codex may inspect only the selected PrivateLens
repo path named above and only for:

- branch, HEAD, local git status, and recent local commits
- top-level project structure
- README or local docs needed to identify safe next work
- package/build/test metadata without installing packages
- existing test scripts or validation hints
- current dirty files, if any, without changing them

## Not Allowed

- No product repo mutation.
- No file edits.
- No staging, committing, or pushing.
- No package installs.
- No migrations.
- No deploys.
- No secrets/auth/payments access.
- No proof runs.
- No all-fleet commands.
- No background or watcher processes.
- No external account changes.
- No archived project reactivation.
- No search for alternate PrivateLens locations unless Tim names them.

## Stop Conditions

Stop and report if:

- the named repo path is missing or not a git repo
- the repo is dirty in a way that needs Tim classification
- read-only inspection would require opening secrets, auth, payments, deploy
  material, external accounts, or private credentials
- any useful next step requires mutation, install, migration, proof run, deploy,
  all-fleet command, background runner, push, or product direction

## Final Report Format

Return:

- verdict: GREEN/YELLOW/RED/TIM_REQUIRED
- repo path inspected
- branch, HEAD, status, and recent commits
- files read
- safe next work candidate
- blockers and true Tim decisions
- confirmation that no mutation or restricted action occurred

## Exact Approval Language

```text
TIM_EXACT_APPROVAL:
action: read-only inspection
repo/path: C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-privatelens\outputs\privatelens
branch: current local branch only
allowed command(s): git status --short; git branch --show-current; git rev-parse HEAD; git log --oneline -8; safe directory listing; read README/docs/package/test metadata
max scope: read-only inspection only, no file edits, no installs, no tests that mutate state, no proof runs
stop conditions: missing repo, dirty ambiguity, secrets/auth/payments/deploy material needed, mutation needed, install/migration/proof-run/push/deploy/all-fleet/background/external-account action needed
expires after: one Codex response
```

No PrivateLens inspection is authorized until Tim sends exact approval.
