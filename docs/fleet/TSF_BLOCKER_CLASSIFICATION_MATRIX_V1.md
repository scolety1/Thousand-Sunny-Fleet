# TSF Blocker Classification Matrix V1

Prepared: 2026-07-03

Authority artifact for TSF-local blocker classification. This matrix does not
approve restricted work by itself.

| blocker_class | symptoms | safe_recovery_actions | must_stop_if | Tim_required | example | expected_artifact |
| --- | --- | --- | --- | --- | --- | --- |
| `TRUE_AUTHORITY_GATE` | The next step needs explicit human authority. | Produce one exact approval packet. | Any execution would cross a restricted gate. | Yes | Push is needed after local GREEN checks. | Tim exact approval request. |
| `PRODUCT_REPO_GATE` | Product repo access or mutation is required. | Use TSF-local evidence only; draft read-only or mutation approval packet. | Exact repo/path/scope approval is missing. | Yes | Need to inspect NWR canonical checkout beyond approved scope. | Product access approval packet. |
| `DATA_DISCOVERY_GAP` | Coverage looks too narrow, source availability is unclear. | Run source discovery over local artifacts, data dirs, scripts, loaders, docs, fixtures, and cache references. | Public data, install, credentials, or product mutation is required without approval. | Sometimes | NWR historical run found only 4 seasons for a 26-season target. | Provenance map and recovery report. |
| `SOURCE_PROVENANCE_GAP` | Output exists but source path, trust, row count, or seasons are unclear. | Build a provenance table before claims. | Provenance requires private/credentialed data or mutation. | Sometimes | Unknown whether player_stats, PBP, roster, or snap-count data fed a packet. | Source provenance map. |
| `PROMPT_SCOPE_FLAW` | Prompt led Codex to review/document instead of build the unblock artifact. | Patch prompt language, define finish line, and rerun once if safe. | Rerun requires restricted work not approved. | Sometimes | Prompt said use local data but did not require source discovery. | Prompt patch or narrowed work order. |
| `SCRIPT_LOGIC_FLAW` | Script is safe but too shallow, misclassifies data, or omits required checks. | Patch script in sandbox/TSF-local scope and rerun once. | Patch would affect production/canonical behavior without approval. | Sometimes | Historical generator hard-coded four artifacts. | Fixed script plus validation report. |
| `VALIDATION_FAILURE` | Tests, diff check, row checks, schema checks, or scoring checks fail. | Investigate failure, repair once inside scope, rerun focused validation. | Repair needs install, secret, proof run, mutation, or unsafe command. | Sometimes | Sample fantasy scoring recalculation mismatches output. | Validation failure or repair report. |
| `TOOLING_ENVIRONMENT_GAP` | Required local tool/library is missing. | Use already bundled runtime if available; otherwise classify install gate. | Install is needed and not approved. | Yes if install needed | Pandas/parquet support missing from default Python but available in bundled runtime. | Environment diagnosis and allowed-runtime note. |
| `MISSING_LOCAL_DATA` | Data is not present locally after source discovery. | Produce partial packet with caveats or exact acquisition request. | Continuing requires public/private data acquisition. | Sometimes | No-download recovery cannot reach full seasons. | Partial foundation plus acquisition approval packet. |
| `PUBLIC_DATA_REQUIRED` | Full result needs public download/import. | Stop and request exact public acquisition approval unless already approved. | Download/import is not explicitly approved. | Yes unless pre-approved | nflverse player_stats/PBP/players/roster/snap-count sources needed for parity. | Public acquisition approval packet. |
| `INSTALL_REQUIRED` | Package/tool install is needed. | Stop with install approval packet or choose no-install alternative. | No exact install approval exists. | Yes | Parquet engine unavailable and no bundled runtime exists. | Install gate packet. |
| `CREDENTIAL_OR_SECRET_REQUIRED` | Auth, token, payment, private account, or secret would be needed. | Stop; do not inspect or use credentials. | Any secret access is required. | Yes | Vendor data requires API key. | Credential/secret gate packet. |
| `SCOPE_DRIFT` | Lane starts doing tuning/app/product work instead of the approved artifact. | Narrow scope, produce current artifact, or stop. | Useful artifact requires new scope. | Sometimes | Historical foundation starts deciding model weights. | Scope correction note or stop report. |
| `UNSAFE_OPERATION_REQUESTED` | Requested action is destructive or out of authority. | Refuse/hold and produce safe alternative or exact approval packet. | Action remains unsafe even with current context. | Yes | Reset/clean/delete beyond exact sandbox path. | RED stop report. |
| `AMBIGUOUS_STATE` | Dirty worktree, unknown sandbox, unclear branch, or conflicting source truth. | Reconcile state from local evidence; preserve before cleanup. | Classification cannot be made safely. | Sometimes | Existing sandbox path might contain unrelated work. | Dirty-state reconciliation. |
| `ARTIFACT_PRESERVATION_NEEDED` | Useful outputs may be lost before cleanup/rerun. | Zip/copy allowed artifacts, verify open/content/checksum, then cleanup exact path if approved. | Preservation cannot be verified or cleanup path is ambiguous. | Sometimes | Preserve old TSF partial packet before deleting failed sandbox. | Preservation packet and checksum report. |

## Main Worked Example

NWR historical foundation miss:

- Original issue: `DATA_DISCOVERY_GAP`, `SOURCE_PROVENANCE_GAP`,
  `PROMPT_SCOPE_FLAW`.
- Wrong behavior: report partial coverage after checking only four hard-coded
  local artifacts.
- Correct behavior: preserve packet, diagnose the source discovery miss, rerun
  with provenance, escalate public data acquisition only when needed, and reach
  parity after exact approval.
- Expected artifacts: preserved zip, root cause report, source provenance map,
  comparison report, public acquisition approval request, parity packet.

## Matrix Use Rule

Future TSF lanes should classify blockers with this matrix before asking Tim,
rerunning, or declaring RED. If the blocker class points to a safe artifact,
build that artifact. If it points to a true gate, stop before execution and ask
for exact approval.
