# API and Session Contract

Operations:

- `POST /api/v1/session`
- `POST /api/v1/route-preview`
- `POST /api/v1/missions`
- `GET /api/v1/missions/:missionId`
- `GET /api/v1/missions/:missionId/events`
- `POST /api/v1/missions/:missionId/responses`

The server binds only `127.0.0.1`. Session acquisition and every state-changing operation require the exact `http://127.0.0.1:<listener-port>` Origin and Host. Tokens are 256-bit random, memory-only, expire after 30 minutes, are rate-limited, never enter logs/artifacts, and are cleared on shutdown. State-changing requests require JSON, the `X-TSF-HQ-Session` header, bounded bodies, and closed object contracts. No CORS grant is emitted.

The token authenticates only one local browser session and grants no TSF approval or repository authority.
