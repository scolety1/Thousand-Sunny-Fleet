# Security and authority review

Allowed authority is unchanged: fixed TSF-local preview, governed read-only mission preparation, canonical queue/lifecycle execution, `CODEX_SERVICE_ONLY` app-server transport, disabled worker-tool network, independent verifier, preservation, admission, Stop, and read-only Doctor.

Denied and tested:

- caller-supplied command, executable, environment, queue root, mission envelope, verifier result, admission state, approval state, repository, thread, or output path;
- partial/stale/changed/cross-preview exact contract;
- old-literal substitution, producer-declared success, wrong observed hash, normalization mismatch, and cross-run evidence;
- schema weakening or unknown properties;
- caller-selected production queue or second queue authority;
- alternate queue roots unless an explicit test-only capability is bound beneath `.codex-local/fixtures` by the deterministic demo/reliability harness;
- broad ignore policy or arbitrary untracked-file suppression;
- symlink, junction, mount-point, other reparse, path-escape, unreadable, nested, and non-regular protected queue entries;
- evidence deletion by Stop;
- product repositories, plugins, credentials, package installation, deployment, merge, auto-merge, services, tasks, startup entries, remote listeners, background/persistent execution, or arbitrary worker network.

The literal is result-validation data only. It is never interpreted as a command, path, script, environment value, approval, verifier verdict, or admission result. Queue file inspection uses non-following metadata before JSON reads and scopes reparse rejection to the protected generated runtime queue; no target is opened, modified, terminated, or deleted. The two StrictMode fixes in `TsfJsonContract.ps1` only make existing closed-schema validation deterministic for one-property objects and schemas without a `required` member; they do not broaden accepted data.
