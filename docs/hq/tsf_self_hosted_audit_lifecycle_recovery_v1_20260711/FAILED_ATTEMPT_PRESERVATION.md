# Failed attempt preservation

Original mission: `tsf-foundation-authority-audit-bd35f991-20260711`, revision 1.

Immutable preserved records:

| Record | SHA-256 |
|---|---|
| `STOP_RECORD.json` | `f1829aeb1f9109b1b579a3449c5b7b4861561e6df70e67174c328a26638770ac` |
| `queue-record-preflight-pending.json` | `b448d6ace79b44b0b2ac93074b7547c334888617233da690d213600be35c5eb8` |
| `qd.json` | `b448d6ace79b44b0b2ac93074b7547c334888617233da690d213600be35c5eb8` |
| `qe.json` | `b2f00a8aadb95ca2503d3468323a4b5d0fc68865e6ed7c5092b09457b359c538` |
| `t01.json` | `85c705a9a7867dfbff1de7c8ab0d2b3d206abadbde64cb3b9b7a3a6db928886f` |
| `t02.json` | `6ac9aca8c2d9f2447ef259ce81ec0ac0a92e719d39d520a7bdb677139c847c22` |

Preflight confirmed that the original mission is absent from every active production queue state. It is not treated as completed and is not resumable.

`fleet/control/self-hosted-audit-recovery-policy.v1.json` and `New-TsfCanonicalQueueMission.ps1` require immutable stop/snapshot evidence, a distinct retry mission ID, exact clean-HEAD binding, no active identity collision, and a compact recovery marker. The marker records both original hashes and sets `original_attempt_completed: false`, `original_attempt_resumable: false`, and `duplicate_worker_prevented: true`.
