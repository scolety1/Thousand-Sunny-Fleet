# Root cause

The queue executor constructed a positional native PowerShell argument array containing `-ApprovalLedgerPath` followed by an empty string. PowerShell rejected the empty value during parameter binding, before `Invoke-TsfMissionLifecycle.ps1` entered its body.

Consequences for the second failed audit were exact: the queue reached `preflight_pending`; no lifecycle terminal result was written; no app-server or worker child launched; no Auditor verdict existed; and the queue record remained recoverable failed history.

A second unsafe fallback was also removed: after a successful lifecycle the executor synthesized a `canonical-empty-ledger` when no ledger path was supplied. No-approval missions now use explicit `NO_APPROVAL_REQUIRED` semantics and consume no ledger.

The repair uses a deterministic argument plan. Required parameters are always present; optional parameters are present only with canonical validated values; argument evidence records names, never sensitive values.
