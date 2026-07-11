# Failed audit attempt preservation

Neither failed mission was resumed or relabeled.

First attempt: `tsf-foundation-authority-audit-bd35f991-20260711`.

- stop record SHA-256: `f1829aeb1f9109b1b579a3449c5b7b4861561e6df70e67174c328a26638770ac`
- queue snapshot SHA-256: `b448d6ace79b44b0b2ac93074b7547c334888617233da690d213600be35c5eb8`

Second attempt: `tsf-foundation-lifecycle-audit-2d98222b-20260711`, final state `preflight_pending`.

- preserved queue snapshot SHA-256: `75724fe7d76ec7ab99cb96dde02a3895e97994a65bd30471eaab8aad79ef0ab5`
- executor evidence SHA-256: `14bede8d37746f0b5e546ef1babdfa8945831d46ece480162162f475032e465e`

The second active queue record was moved byte-for-byte into `.codex-local/programs/optional-approval-ledger-recovery-v1/second-failed-audit/`, together with its compact evidence files. The production queue contains no active record for either failed mission.
