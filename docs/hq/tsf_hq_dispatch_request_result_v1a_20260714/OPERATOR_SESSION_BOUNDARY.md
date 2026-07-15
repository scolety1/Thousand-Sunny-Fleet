# Operator Session Boundary

- Fixed listener: `127.0.0.1`.
- Acquisition: empty JSON POST from exact `http://127.0.0.1:<port>` Origin and matching Host.
- Token: 256 random bits, base64url, memory-only, 30-minute production TTL.
- Writes: exact Origin/Host, `application/json`, `X-TSF-HQ-Session`, 8 KiB body limit, and closed object schemas.
- Rate: 60 authenticated state-changing requests per rolling minute per session.
- Shutdown: sessions are invalidated and new sessions receive `503`.
- CORS: no `Access-Control-Allow-Origin` grant.

The token grants local browser-session access only. It grants no approval, repository, write, network, verification, admission, merge, deployment, or production authority.

Assertion coverage includes valid acquisition, wrong Origin/Host, missing/malformed/wrong/expired token, shutdown invalidation, rate limiting, malformed/oversized/non-JSON input, and absent permissive CORS.
