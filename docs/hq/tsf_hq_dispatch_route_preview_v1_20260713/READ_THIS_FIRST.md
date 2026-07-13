# TSF HQ Dispatch Route Preview V1

Status: Milestone 1 implementation complete and locally validated against `origin/main` at `7fe9c176177d5d2c613238d375fdb45e6fe783dc`.

Authority posture: `PREVIEW_ONLY_NOT_AUTHORITY`.

This milestone adds a thin foreground HTTP surface for three operations:

- `GET /health`
- `GET /api/v1/registries`
- `POST /api/v1/route-preview`

The production listener is fixed to `127.0.0.1:4317`. The foreground server accepts no runtime arguments and reads no caller-provided environment overrides. It uses Node platform libraries only and installs no package.

Start the operator surface from the repository root:

```powershell
node .\tools\hq-dispatch\v1\server.mjs
```

The route-preview endpoint accepts exactly one JSON field:

```json
{
  "natural_request": "Review a bounded TSF-local documentation change."
}
```

Node performs protocol and closed-field validation, then invokes exactly one fixed PowerShell wrapper through an absolute executable path with `shell: false`. The wrapper receives JSON through standard input, accepts no runtime arguments, and calls the existing canonical sources for classification, default worker role, and model resolution. The returned preview explains the classification, role, model/effort recommendation, access scope, restrictions, stop conditions, and non-authority boundary.

The response explains the classification, proposed worker role, model/effort resolution, and authority boundary. The registry endpoint projects only TSF role, model-routing, skill, and setup/action sources. Plugin registries are not read or projected; the response exposes only the fixed deny states `plugin_access_enabled: false` and `plugin_registry_projected: false`.

Preview artifacts are non-mission records written only beneath:

```text
.codex-local/hq-dispatch/preview/
```

The directory is already covered by the repository’s `.codex-local/` ignore rule. Natural request text is used in memory for canonical classification but is not echoed in the response or persisted in the preview artifact. The implementation does not submit or execute a mission, create a queue record, invoke lifecycle or admission, mutate an approval ledger, call Codex, start the Codex app-server, read a plugin registry, inspect plugin state, load plugin code, access credentials, authenticate, connect externally, inspect another repository, or start a background process.

See:

- [FILE_INVENTORY.md](FILE_INVENTORY.md) for the exact implementation scope.
- [SOURCE_MAP.md](SOURCE_MAP.md) for canonical inputs and boundaries.
- [VALIDATION.md](VALIDATION.md) and [VALIDATION.json](VALIDATION.json) for executed coverage.
- [KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md](KNOWN_LIMITATIONS_AND_MILESTONE_2_DEFERRALS.md) for explicit non-goals.
- [SHA256SUMS.txt](SHA256SUMS.txt) for the implementation packet hashes.
