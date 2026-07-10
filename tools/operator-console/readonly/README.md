# TSF Operator Console Read-Only

Open `index.html` directly in a browser to view the local TSF status dashboard. This V1 is static and read-only.

It does not run missions, call Codex, call APIs, start a server, start a background runner, or mutate the repo.

The research page is `READ_ONLY_PREVIEW` backed by `FIXTURE_DATA`. The export, report-file import, and deterministic synthesis scripts are `SCRIPT_BACKED_NOT_UI_WIRED`; the page does not invoke them. Returned ZIP import is not implemented. Import performs `BASIC_CONTENT_SCREENING` and `BASIC_CITATION_PRESENCE`, not claim-to-source citation verification.

Phase 3 adds generated JSON under `data/`. Until then, the console uses `sample-status.json` or embedded fallback data.
