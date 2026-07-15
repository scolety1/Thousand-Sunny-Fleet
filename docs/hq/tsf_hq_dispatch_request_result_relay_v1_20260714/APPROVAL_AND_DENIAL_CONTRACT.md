# Approval and Denial Contract

Approval requires exact action `APPROVE_EXACT_REQUEST`, the session token, exact confirmation phrase, matching request evidence hash, unexpired request, and single-use response identity.

The production approval path currently returns `CANONICAL_APPROVAL_WRITER_NOT_AVAILABLE`. This is deliberate fail-closed behavior: the repository contains a canonical schema and matcher but no canonical writer, and Dispatch does not fabricate an approval ledger or broaden authority. Synthetic fixtures prove the intended one-write/idempotent contract only.

Denial requires exact confirmation, launches no worker, creates no rerun, and grants no authority. Canonical denial-record persistence remains blocked by the same missing canonical response writer.
