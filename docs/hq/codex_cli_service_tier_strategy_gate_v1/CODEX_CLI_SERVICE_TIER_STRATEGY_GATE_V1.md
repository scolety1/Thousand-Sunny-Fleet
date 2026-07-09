# Codex CLI Service-Tier Strategy Gate V1

## Verdict

`GREEN_SERVICE_TIER_STRATEGY_READY_FOR_FIXTURE_RETRY`

## Decision

Recommended strategy:

`GREEN_RETRY_WITH_SERVICE_TIER_FAST_OVERRIDE`

Recommended next worker command shape:

`codex exec -c service_tier=fast --sandbox workspace-write --ephemeral --cd "C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet" --output-last-message <scratch-output-file> --json -`

The next retry should use normal user config, preserve the trusted TSF project entry and Windows elevated sandbox config, and override only `service_tier` to `fast`.

## Evidence

- Branch containment passed.
- Starting HEAD matched `9971ccbd321601f7bbefad80d73dc490f2106df8`.
- Worktree was clean.
- `codex --version` returned `codex-cli 0.124.0`.
- `codex exec --help` exited `0`.
- `codex exec -c service_tier=fast --help` exited `0`.
- `codex exec -c service_tier=flex --help` exited `0`.
- `codex exec -c service_tier=fast --sandbox workspace-write --ephemeral --cd <TSF repo> --help` exited `0`.
- `codex exec -c service_tier=flex --sandbox workspace-write --ephemeral --cd <TSF repo> --help` exited `0`.

## Why Fast

Both `fast` and `flex` are parser/help-clean. However, prior execution evidence already showed `flex` can still fail in the real runtime path, while `null` was rejected during config parsing. The safest next one-shot retry should therefore preserve normal config and use the parser-clean `fast` override.

## Config Trace

Only non-secret config keys were inspected. The active config path is `C:\Users\codex-agent\.codex\config.toml`.

Relevant redacted config facts:

- Top-level `service_tier` is currently `"flex"`.
- TSF project trust entry exists for `C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet`.
- Windows sandbox config includes `sandbox = "elevated"`.
- No auth files, tokens, API keys, credentials, account IDs, or endpoints were printed or copied.

## Guardrails

- Worker prompt executed: no
- Fixture artifact created: no
- Config edited: no
- API called: no
- Background runner started: no
- Product repo mutated: no
- Canonical NWR mutated: no
- Push/merge/deploy/install/migration/secrets/PrivateLens/all-fleet: no

## Next Step

If Tim approves, run exactly one fixture-only foreground worker retry with normal user config and `-c service_tier=fast`. Do not retry from this packet alone.
