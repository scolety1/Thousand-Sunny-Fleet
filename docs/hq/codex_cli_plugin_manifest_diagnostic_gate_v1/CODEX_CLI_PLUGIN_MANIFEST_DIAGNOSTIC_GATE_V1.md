# Codex CLI Plugin Manifest Diagnostic Gate V1

## Verdict

YELLOW_PLUGIN_WARNING_DIAGNOSED_TIM_APPROVAL_NEEDED

## Summary

The Codex CLI worker retry was not run in this gate. The diagnostic traced the prior `codex exec` failure to a Codex-local cached plugin manifest warning for the `template-creator` plugin.

The manifest file exists and parses as JSON:

`C:\Users\codex-agent\.codex\plugins\cache\openai-primary-runtime\template-creator\26.630.12135\.codex-plugin\plugin.json`

The issue is not a TSF repo file, product repo file, canonical NWR file, secret, credential, API key, or network setting. It is a local cached Codex plugin manifest with `interface.defaultPrompt` containing 4 entries while the observed CLI warning says the maximum supported value is 3.

## Diagnostic Evidence

- Repo branch: `work/tsf-pack-and-go-autonomous-deployment-v1-20260709`
- Starting HEAD: `76f4c8eba61af0a1aa6fb37a40d290c2a75f0e20`
- Initial worktree: clean
- Codex CLI version: `codex-cli 0.124.0`
- `codex exec --help`: exit code `0`, no stderr
- Codex config service tier: `service_tier = "flex"`
- Prior worker gate observed one failed `codex exec` attempt and did not retry
- Prior worker gate verifier failed closed because the expected fixture artifact was missing

## Warning Source

The prior worker gate recorded:

`plugin manifest warning observed; no JSON events or final message produced`

The redacted warning trace points to:

`C:\Users\codex-agent\.codex\plugins\cache\openai-primary-runtime\template-creator\26.630.12135\.codex-plugin\plugin.json`

The manifest contains 4 default prompts:

1. `Create a personal template from this document`
2. `Create a personal template from this presentation`
3. `Create a personal template from this spreadsheet`
4. `Update this personal artifact template`

The plugin manifest inventory found this as the only cached plugin manifest with `defaultPrompt` count greater than 3.

## Fix Decision

A narrow fix appears available: back up the manifest, then reduce `interface.defaultPrompt` from 4 entries to 3 entries so the manifest matches the CLI-supported maximum.

The fix was not performed in this gate. The allowed fix language covers malformed JSON/TOML/YAML or stale path references, while this issue is a schema compatibility problem in a Codex-local cached plugin manifest outside the TSF repo. Because the prompt says to stop if uncertainty exists, this packet preserves the exact evidence and requests Tim approval before editing the plugin cache.

## Exact Tim Approval Text For Next Gate

`Tim approves backing up and editing only C:\Users\codex-agent\.codex\plugins\cache\openai-primary-runtime\template-creator\26.630.12135\.codex-plugin\plugin.json to reduce interface.defaultPrompt from 4 entries to the first 3 entries, with no auth, credential, API key, endpoint, token, account, install, network, product repo, canonical NWR, push, merge, deploy, migration, PrivateLens, all-fleet, or background-runner changes. After the edit, run parser/help diagnostics only. Do not run a real codex exec worker retry unless separately approved.`

## Guardrails

No real `codex exec` worker execution was invoked in this gate. No API call, background runner, push, merge, deploy, install, migration, secrets, PrivateLens, all-fleet command, product repo mutation, canonical NWR mutation, normal NWR packet read, app wiring, rankings, formulas, source-truth promotion, recommendation, or hidden-sort change occurred.

## Recommended Next Step

Run a narrow Tim-approved plugin manifest fix gate, then a separate Tim-approved fixture-only worker retry gate if the CLI starts cleanly after the manifest fix.
