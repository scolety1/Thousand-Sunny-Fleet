# Command-Capable Dry-Run Mission Drafting V1

Verdict: GREEN_COMMAND_CAPABLE_DRY_RUN_MISSION_DRAFTING_COMPLETE

## Purpose

The console mission draft helper lets Tim convert a local request fixture or request string into a draft-only TSF mission packet preview.

## Boundary

- Draft generation only.
- No mission execution.
- No worker execution.
- No queue execution.
- No API calls.
- No browser-side file writes.

## Helper

`tools/New-TsfConsoleMissionDraft.ps1`

The helper reuses `tools/New-TsfProjectMainBotMissionDraft.ps1` and maps the existing classification into console-safe values:

- `SAFE_LOCAL_MISSION` -> `SAFE_DRAFT_ONLY`
- `NEEDS_TIM_APPROVAL` -> `NEEDS_TIM_APPROVAL`
- `NEEDS_CHATGPT_HQ` -> `NEEDS_CHATGPT_HQ`
- `BLOCKED_UNSAFE` -> `BLOCKED_UNSAFE`

## Output

Drafts are written under `tests/fixtures/fleet/operator-console/draft-missions/` unless a caller provides a safer explicit output path.
