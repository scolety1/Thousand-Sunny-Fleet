# Codex CLI Service-Tier Runtime Diagnostic V1

Verdict: `GREEN_SERVICE_TIER_STRATEGY_READY_FOR_FIXTURE_RETRY`

## Scope

This gate preserved the failed fixture-worker retry packet and diagnosed the local Codex CLI service-tier/runtime issue without running another worker mission.

No real `codex exec` worker retry was run in this gate.

## Starting State

- Repo: `C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet`
- Branch: `work/tsf-pack-and-go-autonomous-deployment-v1-20260709`
- Expected starting HEAD: `8203e0bac444b559cf98669f81b10ff403c0a39c`
- Failed retry packet path: `docs/hq/codex_cli_fixture_worker_retry_after_plugin_fix_v1/`

The only dirty state at the start of this gate was the failed retry evidence packet. It was committed locally as:

- `2765136d41ceec19c764d145c7c5e340424b66b0` - `docs: preserve failed Codex CLI fixture retry evidence`

## Evidence

- `codex --version` returned `codex-cli 0.124.0`.
- `codex exec --help` exited successfully.
- Active non-secret user config field found at `C:\Users\codex-agent\.codex\config.toml`: `service_tier = "flex"`.
- The preserved failed worker packet records `codex exec` exit code `1` and error `Unsupported service_tier: flex`.
- Local package text search did not expose accepted service-tier values.
- `codex exec --ignore-user-config --help` exited `0` with no stderr.
- `codex exec --help` documents `--ignore-user-config` as not loading `$CODEX_HOME/config.toml` while auth still uses `CODEX_HOME`.

## Config Layer Trace

The failure is best explained as a user-config service-tier value reaching the worker execution runtime:

1. User config contains `service_tier = "flex"`.
2. Help/parser diagnostics pass because they do not exercise the runtime service-tier path.
3. The real worker attempt fails before artifact creation with `Unsupported service_tier: flex`.
4. `--ignore-user-config` is available and help-tested cleanly, so it is the least invasive next fixture retry strategy.

Plugin warnings remain visible in the preserved failed packet and local runtime cache, but the current hard blocker is the service-tier rejection. The earlier plugin warning no longer prevents `codex exec --help` from exiting `0`.

## Strategy Decision

Decision: `IGNORE_USER_CONFIG_RECOMMENDED_FOR_FIXTURE`

Do not guess another service-tier value. Do not edit credentials, auth, endpoints, model settings, account data, or broad config. The next Tim-approved fixture retry should run the existing TSF-governed one-attempt worker path with `codex exec --ignore-user-config` so the invalid `service_tier = "flex"` line is bypassed while auth remains available through `CODEX_HOME`.

## Caveats

- `--ignore-user-config` has been validated only with `codex exec --help` in this gate; it has not been used for a real worker retry here.
- No accepted service-tier enum was found in local CLI help or package text.
- Runtime/temp plugin manifest warnings may still be noisy, but they are not the service-tier blocker preserved in the failed retry packet.

## Recommended Next Step

Run a separate, Tim-approved one-attempt fixture retry using the TSF-governed lifecycle and `codex exec --ignore-user-config`. Keep the same hard scope: one fixture artifact, no product repo, no canonical NWR, no API, no push, no merge, no background runners.
