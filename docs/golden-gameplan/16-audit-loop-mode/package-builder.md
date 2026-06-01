# Audit Loop Package Builder

`invoke-audit-loop-package.ps1` builds compact, metadata-driven audit packages for optional Audit Loop Mode.

This is separate from the broader Golden Gameplan audit package flow. It is for projects that explicitly opt into the HouseOS-style external review loop pattern.

## Command

```powershell
.\invoke-audit-loop-package.ps1 `
  -MetadataPath .\path\to\audit-loop-metadata.json `
  -OutRoot .\out\audit-loop `
  -AuditId fixture-audit-loop `
  -MaxFiles 20
```

Use `-NoZip` for fixture tests or local inspection without creating an archive.

## Inputs

The command reads `templates/audit-loop-metadata-schema.json` shaped metadata:

- `repository`
- `safeDataSources`
- `forbiddenDataSources`
- `auditPackageFiles`
- `maxTasks`
- `riskTier`
- `acceptedLimitations`

Only files declared in `auditPackageFiles` are candidates for inclusion.

## Safety Behavior

The builder rejects:

- Absolute paths in `auditPackageFiles`
- Parent traversal
- `.env`
- `.git`
- `node_modules`
- `dist`
- `build`
- `.codex-local/locks`
- secret, token, credential, or private-key-like paths
- files outside declared `safeDataSources`
- paths matching declared `forbiddenDataSources`

Skipped files are recorded in `manifest.json` and `PACKAGE_REPORT.md`. They are not silently included.

## Outputs

Each package contains:

- `metadata/audit-loop-metadata.json`
- `files/...` for allowed high-signal files
- `prompts/external-audit-prompt.md`
- `PACKAGE_REPORT.md`
- `manifest.json`
- optional zip archive

## Max-File Warning

`-MaxFiles` does not delete evidence. It records a warning when included files exceed the requested review size. This keeps packaging honest while letting the captain decide whether to trim or send the larger package.

## Non-Goals

- Does not launch ships.
- Does not inspect product repos unless metadata explicitly points at one and policy allows it.
- Does not bypass runtime scope policy.
- Does not parse unstructured audit reports.
- Does not import or execute task packets.
