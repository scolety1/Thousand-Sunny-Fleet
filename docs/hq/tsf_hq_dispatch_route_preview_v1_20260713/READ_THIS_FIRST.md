# TSF HQ Dispatch Route Preview V1

Status: Milestone 1 source-bound explanation and preview-hygiene correction complete and locally validated against feature base `7fe9c176177d5d2c613238d375fdb45e6fe783dc`.

Authority posture: `PREVIEW_ONLY_NOT_AUTHORITY`.

This milestone provides only:

- `GET /health`
- `GET /api/v1/registries`
- `POST /api/v1/route-preview`

The production listener is fixed to `127.0.0.1:4317`. The foreground server
accepts no runtime arguments or environment overrides, uses Node platform
libraries only, and installs no package.

Start the optional foreground surface from the repository root:

```powershell
node .\tools\hq-dispatch\v1\server.mjs
```

The route-preview endpoint accepts exactly one JSON field:

```json
{
  "natural_request": "Review a bounded TSF-local documentation change."
}
```

Node performs protocol and closed-field validation, then invokes exactly one
fixed PowerShell wrapper through an absolute executable path with
`shell: false`. The wrapper receives JSON through standard input, accepts no
runtime arguments, and calls existing canonical sources for classification,
the registered default role, and model resolution.

The response requires `tsf_hq_dispatch_route_explanation_v1`, a closed
source-bound contract covering project/lane, classification, role and fit,
model/effort, access, reads, writes, prohibitions, approvals, clarifications,
stop conditions, and authority exclusions. Every section contains a reason
code, wrapper-formatted summary, and canonical source bindings with observed
values or hashes plus explicit assurance. The summaries are not represented
as prose emitted by the canonical router.

The access proposal is explicitly
`TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION`, with canonical draft read/write
scopes, `NO_NETWORK`, and `ROUTE_PREVIEW_ONLY_NO_EXECUTION`. It grants no
authority.

The registry endpoint projects only TSF role, model-routing, skill, and
setup/action sources. Plugin registries are not read or projected; only fixed
deny states such as `plugin_access_enabled: false` and
`plugin_registry_projected: false` are returned.

Preview artifacts are non-mission records written only beneath:

```text
.codex-local/hq-dispatch/preview/
```

The directory is covered by the repository's `.codex-local/` ignore rule.
Natural request text is used in memory for classification but is not echoed or
persisted. Artifacts use exclusive create-new semantics, retry a new
server-generated GUID at most eight times after a collision, and never
overwrite an existing file. Corrected artifacts accumulate until bounded local
cleanup and never become canonical evidence.

This correction deleted nine ignored legacy artifacts that retained a
top-level `natural_request` field. Only filenames and pre-cleanup SHA-256
values are recorded in the validation packet; raw request values were not
displayed or copied. Post-cleanup validation found zero remaining raw-request
fields.

The implementation does not submit or execute a mission, create a queue
record, invoke lifecycle or admission, mutate approval state, call Codex,
start the Codex app-server, inspect plugin state, load plugin code, access
credentials, connect externally, inspect another repository, or start a
background process.

See:

- [FILE_INVENTORY.md](FILE_INVENTORY.md) for the implementation scope.
- [SOURCE_MAP.md](SOURCE_MAP.md) for source bindings and boundaries.
- [VALIDATION.md](VALIDATION.md) and [VALIDATION.json](VALIDATION.json) for executed coverage and cleanup evidence.
- [KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md](KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md) for explicit non-goals.
- [SHA256SUMS.txt](SHA256SUMS.txt) for canonical LF-normalized packet hashes.
