# Mission State Model V1

The V1 kernel standardizes filesystem mission states under `fleet/missions/`.

| State | Purpose |
| --- | --- |
| `drafted` | Mission packets drafted but not yet preflighted. |
| `preflight-pending` | Mission packets copied at preflight start. |
| `approved-for-worker` | Mission packets that passed preflight. |
| `running` | Foreground worker handoff prepared. No background runner is started. |
| `postrun-pending` | Worker output is ready for verification. |
| `completed` | Post-run verifier passed or completed with warning. |
| `blocked-tim-required` | Preflight or verifier failed closed or needs exact Tim approval. |
| `archived` | Closed historical mission packets. |

V1 copies packets between states rather than deleting or moving source files. That preserves evidence and avoids accidental loss.
