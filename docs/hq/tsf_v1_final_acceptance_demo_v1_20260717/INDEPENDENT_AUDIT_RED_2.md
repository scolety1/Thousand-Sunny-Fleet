# Independent Audit RED 2

The second independent Tester and Auditor evaluated exact candidate `11e0b116afe150dccf82b4674bee45ae9ed59555` (tree `f95cf67602e0fabea1c5d119b8f7a7e80d7b62e1`) and both returned RED. Publication was not authorized.

The Tester reran the deterministic acceptance path: 20 of 20 checks passed in 514.069 seconds, with summary SHA-256 `2afddb6b9a4bd84f2d5ae96d51d767e73e891bd8b7e7a0b9467d0eddd69f6f70`. The Tester also independently verified the corrected verifier and preservation identities, every acceptance-seal binding, all 92 indexed evidence rows, and the safe no-owner/no-listener/no-child Doctor state.

The Auditor closed all three findings from the first RED audit and independently disposed the M3 erratum as GREEN and nonblocking. One new publication blocker remained: the acceptance runner and its generated coverage receipts identified the real proof as 83 assertions, while the executed proof, marker, and seal identified 94. That made the authoritative machine-readable PASS basis internally false.

Commit `f1a9fc6d64add5370067b90f2cae668bf55f342c` changes only that identity to 94 and adds positive and negative regression assertions. The subsequent full all-up run passed 21 of 21 checks and regenerated the real proof with the consistent basis `94_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_NEW_RUN_RECOVERY_PROOF`. A fresh independent audit is still required before publication.
