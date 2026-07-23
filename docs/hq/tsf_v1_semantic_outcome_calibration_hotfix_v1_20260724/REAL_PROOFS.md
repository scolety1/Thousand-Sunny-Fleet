# Real proofs

Deterministic and integration proofs completed before candidate finalization:

- semantic outcome corpus: 136 assertions;
- general-result intent integrity: 140 assertions;
- independent kernel verifier: 13 assertions;
- route preview: 189 assertions;
- intent authorization: 149 assertions;
- request/result relay: 122 assertions;
- canonical runtime/admission matrix: 154 assertions;
- final authority and recovery relationships: 34 assertions;
- responsive/accessibility browser proof: 1,086 assertions;
- targeted soak V3: 12 commands, all exit 0.

The corrected exact candidate `db2aff814dde0c03d2ab4393aa76dfb3f99f369a` passed the 12-case targeted soak. Its full deterministic acceptance run passed 29 of 30 checks. The sole exception was an unchanged M3 child process that exited with Windows code `-1073740791` before producing stdout or stderr. The same M2A command immediately passed 122 assertions, and a complete unchanged M3 aggregate rerun passed. The preserved M3 rerun result hash is `b62cfc9917838253775b6ac0ba939473d5a8347e63a4c2175c9d7019bec8ba58`.

The first bounded live run exposed that the worker prompt did not state the array types of `evidence` and `caveats`. Live workers returned scalar strings, and the strict V2 schema correctly failed closed. The correction makes those array types explicit in the prompt; it does not coerce malformed claims or weaken the schema.

The corrected live proof uses `CODEX_SERVICE_ONLY` for the control-plane adapter, keeps worker-tool network disabled, requires the four-field analysis profile, and verifies canonical result, verifier, preservation, admission, receipts, and process cleanup. It passed 175 assertions:

- simple read-only mission: GREEN and admitted with bounded caveats;
- structured analysis with historical, normative, and hypothetical inability language: GREEN and admitted with bounded caveats;
- all required structured deliverables independently observed;
- all child processes exited and no orphan remained.

The live validation file hash is `5c87daeb9db2c9a19571da71668083f57fb86db8f3f4918d4383b17177043214`. Because the proof ran before the final evidence-only amend, it is labeled `WORKING_TREE_UNSUPPORTED_DEVELOPMENT`. A separate ignored final proof packet must bind the final commit and tree after publication-packet finalization.

All other proofs are deterministic TSF-local fixtures. No product repository, plugin, credential, installation, deployment, external API, or worker-tool network was used.
