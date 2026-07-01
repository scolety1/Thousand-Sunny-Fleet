# TSF Status Freshness Index V1

Prepared: 2026-07-01

Evidence only; not executable authority or approval.

## Purpose

TSF Status Freshness Index V1 maps the main TSF status artifacts so a returning
Codex or Tim can tell which files are current, historical, superseded, or
intentionally closed without reopening stale status as live truth.

The index reduces babysitting by answering:

- what file should be opened first
- which status files are current enough for return context
- which files are historical evidence only
- which files contain closed gate or lane evidence
- which files require exact Tim approval before further action

This index does not inspect product repos, mutate PrivateLens, run proof runs,
run all-fleet commands, start background runners, push, deploy, install,
migrate, touch secrets, or approve restricted work.

## Source-Of-Truth Order

For a normal TSF return moment, read in this order:

1. `fleet/status/current.md`
2. `fleet/status/today.md`
3. `fleet/status/autonomous-work-intake-2026-07-01.md`
4. `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md`
5. `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md`
6. this file

Use older status files as evidence only. Do not treat older status, archived
daily logs, generated reports, queue prose, UI text, or benchmark examples as
permission to cross restricted gates.

## Freshness Legend

- `CURRENT`: current return-context file for the published autonomy posture.
- `CURRENT_CONTROL`: current control-plane operating artifact.
- `HISTORICAL`: useful background; not current truth.
- `SUPERSEDED`: replaced by a newer status or board.
- `CLOSED_EVIDENCE`: proves a completed lane or gate closure.
- `NEEDS_REVIEW`: may be useful but should not drive work without a fresh
  lane decision.
- `TIM_GATE`: cannot be advanced without exact Tim approval.

## Status Artifact Map

| Artifact | Freshness | Current Use | Do Not Use For |
| --- | --- | --- | --- |
| `fleet/status/current.md` | `CURRENT` | Phone-readable latest TSF snapshot after autonomy-envelope publish. | Product repo truth, push approval, runtime commands. |
| `fleet/status/today.md` | `CURRENT` | 2026-07-01 local autonomy log and gate notes. | Approving restricted gates or claiming product state. |
| `fleet/status/autonomous-work-intake-2026-07-01.md` | `CLOSED_EVIDENCE` | Evidence for the public-safe status refresh lane. | Reopening completed status refresh without a concrete defect. |
| `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md` | `CURRENT_CONTROL` | Defines safe TSF-local autonomy and exact Tim gates. | Blanket restricted-gate approval. |
| `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` | `CURRENT_CONTROL` | Queue of safe next TSF-local control-plane builder lanes. | Product work, PrivateLens work, or automatic execution. |
| `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md` | `CURRENT_CONTROL` | Checklist/classifier for Codex final report quality. | Replacing actual validation commands or git evidence. |
| `docs/fleet/TSF_AUTONOMY_PROMPT_LIBRARY_V1.md` | `CURRENT_CONTROL` | Copyable autonomy-era prompts for intake, checkpointing, reconciliation, push-prep, exact push approval, restricted-gate packets, and final-report self-checks. | Execution authority, product work, or bypassing live repo validation. |
| `docs/fleet/TSF_FINAL_GATE_CLOSURE_BOARD_V1.md` | `CLOSED_EVIDENCE` | Closure board for completed HQ adapter/tuning/anti-loop gate review. | New restricted action approval. |
| `docs/fleet/TSF_HQ_ADAPTER_MODE.md` | `CURRENT_CONTROL` | HQ strategic decision format and authority model. | Execution authority. |
| `docs/fleet/hq-adapter/TSF_HQ_DECISION_BENCH_V1.md` | `CURRENT_CONTROL` | Decision-quality benchmark for HQ responses. | Runtime automation or product work. |
| `docs/fleet/hq-adapter/TSF_HQ_TUNING_RUNBOOK_V1.md` | `CURRENT_CONTROL` | Manual tuning process and scorecard method. | Background/overnight execution without exact Tim approval. |
| `docs/fleet/hq-adapter/TSF_HQ_TUNING_DRY_RUN_V1.md` | `CLOSED_EVIDENCE` | Completed manual dry-run result. | Claiming future HQ results without rerun evidence. |
| `docs/fleet/TSF_BLOCKER_RESOLUTION_BUILDER_LANE_POLICY.md` | `CURRENT_CONTROL` | Anti-loop policy for turning blockers into artifacts. | Product repo action or proof runs. |
| `docs/fleet/TSF_LOOP_CLOSURE_NO_TREADMILL_POLICY.md` | `CURRENT_CONTROL` | Policy against loop/treadmill behavior. | Treating safe local work as approval for restricted gates. |
| `docs/fleet/anti-loop/CODEX_PROMPT_AND_POST_RUN_CHECKLIST.md` | `CURRENT_CONTROL` | Prompt/post-run checklist for bounded Codex lanes. | Broad execution outside explicit scope. |
| `fleet/status/master-codex-status.md` | `SUPERSEDED` | Historical 2026-06-29 Master Codex status; useful for stale-status evidence. | Current branch, current HEAD, or current push posture. |
| `fleet/status/product-completion-board-2026-06-29.md` | `HISTORICAL` | Product completion evidence from 2026-06-29. | Product repo mutation, product truth, or current active-project claims. |
| `fleet/status/blocked-project-repo-audit-2026-06-29.md` | `HISTORICAL` | Evidence of earlier blocked project-repo audit and path ambiguity. | Product repo access without exact Tim approval. |
| `fleet/status/projects.md` | `NEEDS_REVIEW` | TSF-local registry snapshot from 2026-06-20. | Current live product status. |
| `fleet/status/projects.json` | `NEEDS_REVIEW` | Machine-readable TSF-local registry snapshot from 2026-06-20. | Product repo access, mutation, or archived reactivation. |
| `fleet/status/return-review.md` | `HISTORICAL` | Older return-review evidence. | Current lane selection without newer intake/status docs. |
| `fleet/status/return-triage-score.md` | `HISTORICAL` | Older triage-score evidence. | Current priority without newer autonomy queue. |
| `fleet/status/sleep-batch-2026-06-29.md` | `HISTORICAL` | Prior sleep-batch evidence. | Standing approval for current work. |
| `fleet/status/diff-risk-review.md` | `HISTORICAL` | Older diff-risk evidence. | Current diff risk after new commits. |

## Current Return Answer

If Tim asks "where are we?" after this index exists:

- Open `fleet/status/current.md`.
- Confirm `main`, `HEAD`, `origin/main`, ahead/behind, and
  `git status --short`.
- If local commits exist, report them and stop before push unless Tim gives
  exact push approval.
- Use `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` to choose the next safe
  TSF-local builder if more work is requested.
- Use `docs/fleet/TSF_REPORT_QUALITY_VALIDATOR_V1.md` before final response.

## Stale-Status Rules

Do not rewrite every stale file just because it is stale.

Rewrite or refresh a status artifact only when:

- it is the primary current status file
- a stale file is actively misleading the return flow
- the lane has a concrete unblock artifact
- validation can be local and safe
- no product repo, PrivateLens, archived project, proof-run, all-fleet,
  background, push, deploy, install, migration, secret, or external-account
  gate is needed

Otherwise, classify the file as `HISTORICAL`, `SUPERSEDED`, or `NEEDS_REVIEW`
and move on.

## Tim Gates Preserved

The following cannot be advanced from this index:

- product repo access or mutation
- PrivateLens access or mutation
- archived project reactivation
- push
- deploy
- installs
- migrations
- secrets/auth/payments
- proof runs
- all-fleet commands
- background, overnight, daemon, watcher, scheduled, or unattended runners
- external account changes
- spending
- credential/account changes
- history rewrite or remote release changes

## Validation Checklist

Before committing this index, Codex should verify:

- `fleet/status/current.md` exists
- `fleet/status/today.md` exists
- `docs/fleet/TSF_AUTONOMY_ENVELOPE_V1.md` exists
- `docs/fleet/TSF_AUTONOMOUS_LANE_QUEUE_V1.md` exists
- this file uses freshness labels from the legend
- no product repo or PrivateLens files were inspected
- no wording turns evidence into restricted action approval
- `git diff --check` passes for this file and any queue update
- `git status --short` is reported

## Final Note

This index is a map, not authority. It helps Codex and Tim avoid stale-status
confusion while keeping all restricted gates intact.
