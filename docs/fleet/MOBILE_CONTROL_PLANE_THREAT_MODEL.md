# Mobile Control Plane Threat Model

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Threats And Required Controls

| Threat | Risk | Required control |
| --- | --- | --- |
| Public dashboard treated as command UI | Unauthorized execution | Public dashboard remains static, read-only, and request-only |
| Client-side secret storage | Token theft | Browser stores no GitHub PATs, Codex tokens, SSH keys, deploy keys, passwords, MFA, or repo secrets |
| Direct browser command execution | Remote code execution | Browser never executes shell, Codex, GitHub Actions, deploy, install, migration, all-fleet, overnight, or product-repo commands |
| Phone approval confusion | Unsafe authority grant | Phone approval is not execution authority and cannot bypass validation |
| Broad product repo access | Cross-project damage | Product repo access denied by default and separately approved per project and task |
| Missing task contract | Scope drift | Every executable request requires allowedFiles, validationCommands, stopIf, and one-task boundary |
| Request tampering or replay | Wrong work executed | Authenticated request object, immutable requestId, createdAt, requester, status transitions, and audit log |
| Model/cost mismatch | Overpaying or low-quality work | Model routing / cost-quality recommendation recorded before execution |
| Emergency stop misuse | Hidden command channel | Emergency stop is limited to audited stop signaling or narrow runner pause behavior |
| Premature control-plane implementation | Unsafe backend or runner authority | Authenticated request intake requires a separate one-task implementation packet with auth design, secret storage boundary, request integrity, policy gate, model routing, runner refusal behavior, audit logs, and human approval rules |
| Backend compromise | Privilege escalation | Least-privilege service identity, deny-by-default policy, and runner-side enforcement |
| GitHub Actions misuse | Unreviewed automation | Least-privilege tokens, protected environments, and review gates before any future workflow integration |

## RED Stop Signs

- browser stores secrets
- public command buttons
- direct browser command execution
- phone approval authority
- product repo access by default
- missing allowedFiles
- missing validationCommands
- missing stopIf
- no audit log
- missing authentication design
- missing secret storage boundary
- missing request integrity
- missing policy gate
- missing model routing / cost-quality recommendation
- missing runner refusal behavior
- missing human approval rules
- backend/auth/execution/GitHub Actions implementation approved by docs alone
- all-fleet from mobile
- overnight runner from mobile
- deploys from public dashboard
- staging, commit, push, migrations, lock deletion, or permission widening from public dashboard

## Implementation Cutline Abuse Cases

- architecture docs treated as approval to build authentication code
- architecture docs treated as approval to add backend services
- architecture docs treated as approval to trigger GitHub Actions
- architecture docs treated as approval to execute shell or Codex commands
- request intake launched before authentication design is reviewed
- request intake launched before secret storage boundary is reviewed
- request intake launched before request integrity and replay resistance are reviewed
- runner integration launched before runner refusal behavior and audit logs are reviewed

Required control: implementation requires a later exact one-task packet with allowedFiles, validationCommands, stopIf, model routing / cost-quality recommendation, human approval rules, and explicit non-goals.

## Emergency Stop Abuse Cases

- `REQUEST_STOP` text treated as a shell command
- emergency request used to kill processes from the public dashboard
- emergency request used to configure remote access
- emergency request used as phone approval
- emergency request containing PINs, passwords, MFA, recovery codes, keys, tokens, credentials, private screenshots, private device identifiers, customer data, or product data
- emergency request used to mutate product repos, run all-fleet, run overnight, deploy, stage, commit, push, install, migrate, delete locks, widen permissions, bind runtime commands, or trigger GitHub Actions

Required control: emergency stop remains a high-priority request/signal that must be reviewed, scoped, and repacketized before any safe handling occurs.

## Residual Risk

Even after authentication exists, the mobile control plane remains YELLOW until request signing or equivalent integrity controls, policy gates, model routing, runner-side execution gates, and audit logs are tested together.
