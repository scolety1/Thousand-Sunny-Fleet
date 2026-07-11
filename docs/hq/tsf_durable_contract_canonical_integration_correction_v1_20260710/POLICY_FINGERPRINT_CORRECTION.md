# Policy Fingerprint Correction

The fingerprint helper resolves `HEAD^{commit}` itself and accepts no caller-supplied commit. Clean mode hashes content read from that verified commit's blobs. Dirty governing state fails closed.

An explicit `UnsupportedDevelopmentMode` exists only for pre-commit testing. It is labeled `WORKING_TREE_UNSUPPORTED_DEVELOPMENT` and never claims committed assurance.

The manifest covers the durable module/helper, enforcement kernel, queue transition helper, role and permission registries, model policy, mission/result/admission schemas, operational mission/role/worker schemas, and approval-ledger schema. Missions, results, receipts, secrets, credentials, and unrelated files are excluded.
