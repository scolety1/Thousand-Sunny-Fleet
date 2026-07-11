# TSF Canonical App-Server Vertical Slice V1

Verdict: `GREEN_TSF_WINDOWS_SAFE_APP_SERVER_VERTICAL_SLICE_READY_FOR_FINAL_AUDIT`

The successor lane completed one real read-only and one gated controlled workspace-write TSF → Codex app-server → TSF round trip. Both used the stable non-experimental stdio protocol, `CODEX_SERVICE_ONLY` control-plane connectivity, and `DISABLED` worker-tool network. Both generated verified compact preservation manifests, durable results, admission and transaction receipts, and ended in the existing `complete_ready_for_gate` queue state.

New V1 runtime packets use fixed 160-bit Base32 mission/run/receipt keys and compact filenames beneath `.codex-local/rt`. The longest planned and observed live path was 219 characters. Full SHA-256 identities remain in manifests and receipts and are checked before an existing short-key location is accepted.

The read-only final response was exactly `TSF_READ_ONLY_ROUND_TRIP_GREEN`. The workspace-write worker created exactly the approved synthetic `output/result.txt` content. Both exact child PIDs exited; neither remained in the process table.

The stable protocol did not expose authoritative turn-effective effort. Both missions therefore retained `effective_effort: UNKNOWN`, `effective_effort_source: NOT_EXPOSED`, and were admitted with the bounded `RECOMMENDED_ONLY` caveat. Thread default `ultra` was recorded separately from explicit turn requests (`low` and `medium`) and was not promoted to effective effort.

The branch is eligible for the authorized local commit after final diff and post-commit fingerprint gates. No push or merge is authorized.
