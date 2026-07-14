# Executed Correction Validation Coverage

Validation date: `2026-07-14`

Starting commit: `e2f9d916c0f83f79e1cab5d3975440d921a96d9f`

Starting tree: `4cc7a1066cf58cd1f31d00732c11bad524a091d1`

Validated staged implementation tree: `958fd13589de1ea46d4e19c6220d138814e53127`

Branch: `work/tsf-hq-dispatch-route-preview-v1-20260713`

Authority posture: `PREVIEW_ONLY_NOT_AUTHORITY`

Network used: `false`

## Source-bound explanation and access contract

The response now requires `tsf_hq_dispatch_route_explanation_v1` with 12
closed explanation sections. Every section carries a bounded reason code,
human-readable summary, and one or more source bindings containing the source
path, source field, observed value or canonical JSON value hash, and one of the
four permitted assurance values.

Summaries are wrapper formatting over observed draft, registry, model-policy,
or fixed Milestone 1 facts. They are not represented as prose emitted by the
canonical router. The fixed role and `standard_patch` model request remain
honest defaults rather than adaptive role/model selection.

The discrete access proposal is:

- access level: `TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION`;
- read/write scopes: exact canonical draft output;
- network scope: `NO_NETWORK`;
- execution scope: `ROUTE_PREVIEW_ONLY_NO_EXECUTION`;
- authority granted: none.

## Suite results

### Node endpoint, browser-contract, and injection suite

- Command: `node .\tests\test-tsf-hq-dispatch-route-preview-v1.mjs`
- UTC start: `2026-07-14T05:38:32.2141709+00:00`
- UTC end: `2026-07-14T05:38:35.9739449+00:00`
- Exit code: `0`
- Assertions: `188`
- Deterministic result: `NODE_INTEGRATION_PASS assertions=188`
- Result SHA-256: `50f59c41941c39b578da04e213c26b2c4aa54b971ffdbb6d95e62c6c123c11a7`
- Raw-output SHA-256: `8d98912967ef7b6bf38251ec0d5d1112eef51459b22e570169652d13ae0bb9df`
- Target implementation/test tree: `deb6ac471eb9972f6be86852f0e27a78be0fec90`

This suite covers complete explanation and access semantics, canonical
project/role/model bindings, visible browser sections, prohibited controls,
newline, CRLF, quoting, shell metacharacters, traversal, environment-like
text, command fragments, malformed/oversized input, request non-persistence,
loopback binding, plugin exclusion, and canonical-state non-mutation.

### Project Main Bot role-foundation regression

- Command: `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-project-main-bot-role-foundation-tests.ps1`
- UTC start: `2026-07-14T05:37:38.4808153+00:00`
- UTC end: `2026-07-14T05:37:39.8120197+00:00`
- Exit code: `0`
- Assertions: `391`
- Deterministic result: `Project Main Bot role foundation tests passed.`
- Result SHA-256: `f90c312ae989ac51094321129cec5273890488fab90a8316bfd42c9d998df5a9`
- Raw-output SHA-256: `19e27ed679ee2e6c86bf6095de2ce3472245f90f818c6c96264e3bee012ae1a3`
- Target implementation/test tree: `deb6ac471eb9972f6be86852f0e27a78be0fec90`

The regression wrote only its documented ignored local test outputs. It did
not launch a worker, Codex, a queue executor, lifecycle, or an app-server.

### Durable-contract regression

- Command: `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-tsf-durable-contract-tests.ps1 -EvidenceRoot .codex-local\hq-dispatch\correction\durable-contract`
- UTC start: `2026-07-14T05:38:03.0565476+00:00`
- UTC end: `2026-07-14T05:38:12.1123821+00:00`
- Exit code: `0`
- Assertions: `33`
- Deterministic result: `Durable canonical contract tests passed: 33 assertions.`
- Result SHA-256: `6872445374d9bb0db229f20fcbcf3edb1366d45388a662491f018f62c6a0e4ef`
- Raw-output SHA-256: `6a47f173c4de9e7ac764428568c848f8f99dd05702a38b05ff5111ea40e6dce8`
- Target implementation/test tree: `deb6ac471eb9972f6be86852f0e27a78be0fec90`

This suite used temporary isolated fixture repositories and the declared
ignored evidence root. It verified that exactly one admission command is
exported but did not invoke admission, lifecycle, queue execution, or Codex.

### Focused PowerShell harness

- Command: `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-tsf-hq-dispatch-route-preview-v1-tests.ps1`
- UTC start: `2026-07-14T05:49:09.5921486+00:00`
- UTC end: `2026-07-14T05:49:16.4592335+00:00`
- Exit code: `0`
- Assertions: `262`
- Deterministic result: `TSF_HQ_DISPATCH_VALIDATION_PASS assertions=262 actions=71 enabled_actions=1 external_integrations=disabled`
- Result SHA-256: `fc620602b9f81ca4b30badf06703e0e3344cf96b264d710c34f79f193ef7fd43`
- Raw-output SHA-256: `e813af5214b6567b36b89c174a2f0249934a5fa46e2c47f917e1c445f07f775e`
- Target tree: `958fd13589de1ea46d4e19c6220d138814e53127`

The captured run covers closed schemas, explanation negative cases,
semantic bindings, exclusive-create collision behavior, plugin baseline
integrity, protected runtime paths, Node syntax, PowerShell parsing, packet
hashes, and `git diff --check`.

## Legacy preview cleanup

The cleanup enumerated direct `*.route-preview.json` children of only
`.codex-local/hq-dispatch/preview/`. Raw request values were not displayed,
copied, or written into evidence. Nine legacy files were classified
`LEGACY_RAW_REQUEST_ARTIFACT` and deleted:

| Filename | Pre-cleanup SHA-256 | Disposition |
| --- | --- | --- |
| `hq-preview-1a0d13ebbe8c4e09853406a650372f71.route-preview.json` | `f8350c5b0f11ac6b887b93d399426c1bfdb45fda9943d90945dbeeb54a3f6107` | DELETED |
| `hq-preview-55ee8e848dac43139d68290e34e0cd9c.route-preview.json` | `0a1bcaf9e2aacf6be9240678a6e81276652b84986eb40fedf6310a61c9b42f2d` | DELETED |
| `hq-preview-56a43facbe184b32b39b9730b4395abc.route-preview.json` | `4310081a013807922f8e1aa0ac44f944fc56a31b05f54e8f473c756abfb18d55` | DELETED |
| `hq-preview-ad5934d1feeb498b86fb53dc7735d74a.route-preview.json` | `44e5c5941991e0b727fa9764a609c1374544e35aed008ac97ec805a8bf13e1b1` | DELETED |
| `hq-preview-af3c2258df704df79d7c7a0e10d2ca6b.route-preview.json` | `5173aa9df45ed088987c3478f4c7e575983e9ac65c3eef465f1690a44486773e` | DELETED |
| `hq-preview-b6c50373a2a84dcdafe1b5a583b3affb.route-preview.json` | `a92f19e284e1e7bae848ffc339f0ffe932d0ce8e70a6da3331c984cd864ea688` | DELETED |
| `hq-preview-c30b0f0de84b40f2b9d20f8c73bc4680.route-preview.json` | `2416389c0df95d378b1a2a069d17854d2de0eecc659949573fdd733b804495ec` | DELETED |
| `hq-preview-d835595d3e4b44609b89b262da00a5d9.route-preview.json` | `7d830534f267be3f4a503b85cb34419c3bb3033001952c5dd5d819f98e6c5583` | DELETED |
| `hq-preview-e5eea7fc201b43beb0ab74c848d224a9.route-preview.json` | `bdc5428d0409a2524b9095691d7a0b893b255599eae7ca5584b1e8f899575002` | DELETED |

Post-cleanup verification found zero direct preview artifacts containing a
top-level `natural_request` field. Corrected artifacts were not deleted.

## Collision and persistence behavior

Artifact creation uses `FileMode.CreateNew`, never overwrite semantics. A
collision receives a new server-generated GUID for at most eight attempts,
then fails closed. A deterministic existing-file test proves the pre-existing
bytes and SHA-256 remain unchanged. Callers cannot provide an artifact ID or
path.

Current and future artifacts remain ignored, preview-only, noncanonical, and
contain no raw request text. The UI and operator documentation disclose that
corrected artifacts accumulate until bounded local cleanup.

## Operation absence proof

No mission, queue, lifecycle, verifier, preservation, admission, app-server,
Codex, approval, plugin, credential, remote-network, push, merge, deployment,
product, or unrelated-repository operation was performed by HQ Dispatch or by
this correction workflow. Validation-only fixture outputs remained ignored
and local.
