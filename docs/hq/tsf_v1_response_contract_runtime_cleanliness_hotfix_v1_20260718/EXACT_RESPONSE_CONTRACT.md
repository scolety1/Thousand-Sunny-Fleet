# Exact response contract

Canonical schema: `fleet/control/exact-literal-response-contract.schema.v1.json`.

`EXACT_LITERAL_V1` uses `ASCII_TOKEN_IDENTITY_V1` with the grammar `^[A-Z][A-Z0-9_]{0,127}$`. The value is one line, 1-128 ASCII characters, has no control character, whitespace, hidden normalization, path, script, or executable interpretation, and is compared case- and whitespace-sensitively as raw UTF-8 bytes.

The closed contract records:

- expected literal and SHA-256;
- semantic-contract SHA-256;
- exact validation and normalization versions;
- source request SHA-256 and explicit-requirement kind;
- reviewed preview ID, semantic binding hash, and full artifact SHA-256;
- allocated mission ID and revision.

Submission reloads the stored preview, verifies its full artifact hash, recomputes request evidence and the exact contract, and rejects partial, stale, changed, cross-preview, or substituted bindings. The mission, queue source binding, mission packet, worker instruction, worker evidence, verifier evidence, durable result, admission-required test evidence, and UI projection preserve the same semantic hash and literal hash.

The verifier reads the adapter artifact itself, recomputes the observed raw-text hash, checks mission/run/thread/turn identity, and rejects missing, prefix, suffix, case, leading/trailing whitespace, newline, normalization, semantic-contract, and cross-run mismatches. Producer claims such as transport success or a supplied PASS cannot replace verifier evidence.
