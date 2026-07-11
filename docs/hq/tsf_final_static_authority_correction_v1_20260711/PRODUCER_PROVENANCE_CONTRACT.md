# Producer Provenance Contract

The lifecycle creates a run-scoped registry at compact l/<mission-key>/<run-key>/pr.json. Its binding covers mission/revision, run/result, policy fingerprint, queue-document hash, repository, branch, worktree, orchestrator invocation identity, and a run nonce.

Producer, logical type, compact source path, and allowed classification come from an internal contract—not caller parameters. Registration independently records SHA-256, size, sequence, timestamp, producer invocation identity, and registry binding identity after each component finishes.

Preservation verifies the registry, compares any supplied path with the registered path, recomputes source bytes, copies exact bytes into p/, and writes the registry into the manifest as pr.json. Missing, conflicting, altered, wrong-path, wrong-producer, wrong-type, or wrong-run registrations fail closed.

q.txt is KERNEL_OBSERVED only through lifecycle registration. se.log remains UNVERIFIED. This is orchestrator-bound run provenance, not cryptographic producer attestation.

Synthetic injection requires the explicit TestOnlyAllowSyntheticProducerRegistry capability. The normal lifecycle and queue entry point do not expose it to a worker or caller.
