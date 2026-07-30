# Verifier and Admission Binding

The existing verifier performs two linked phases within the same authority
system.

`PRECOMMIT_EXECUTION` independently reruns syntax, focused, acceptance, diff,
and status checks. It receives the registration, preauthorization, binding,
candidate-set identity, writeset identity, approved replacement SHA, and byte
observation.

After the single-use commit authority stages and commits the path, the same
verifier system emits `POSTCOMMIT_BINDING`. It binds the precommit verifier,
candidate set, writeset, byte observation, staged blob, committed blob, commit
receipt, and candidate-integrity proof. It independently rereads the committed
blob from Git.

Canonical admission requires descriptors for:

- registration;
- preauthorization;
- task binding;
- candidate set;
- writeset;
- byte observation;
- precommit verifier;
- postcommit verifier;
- commit authority;
- commit receipt;
- candidate-integrity proof.

Admission reloads the exact authority, reconstructs candidate membership, checks
every artifact file hash and self-identity, checks all cross-links, and reads the
raw committed blob itself. Missing or inconsistent evidence yields
`REJECTED_INVALID_EVIDENCE`. Worker claims and passing tests are
non-authoritative.
