# TSF Overnight Draft Batch V1

Prepared: 2026-07-02

Evidence only; draft queue only; not executable authority or approval.

## What This Is

TSF Overnight Draft Batch V1 is a sleep-safe/away-safe draft-preparation batch.
It creates approval packets, follow-up work-order drafts, and a morning decision
queue so Tim can decide quickly later.

## What This Is Not

This is not:

- product repo inspection
- PrivateLens inspection
- implementation approval
- push approval
- deploy approval
- install or migration approval
- secrets/auth/payments approval
- proof-run approval
- all-fleet approval
- background/overnight runner approval
- archived project reactivation

## How Tim Uses It

1. Open `fleet/status/draft-queue/morning-decision-queue.md`.
2. Pick one decision, if any.
3. Copy the exact approval language from the relevant packet.
4. Edit scope if needed.
5. Send the exact approval to Codex.

## Why Drafts Are Not Approvals

Drafts are prepared text. They do not prove current repo state, approve
restricted gates, or authorize implementation. Codex must still verify live git
state, current files, validation commands, and exact Tim approval before acting.

Generated drafts are proposals, not approval. Status files are evidence, not
permission to mutate product repos. Console links are static guidance only.

## Moving From Draft To Explicit Approval

To use a draft:

- name the action
- name the repo/path
- name the branch
- name allowed commands
- name allowed files or read-only scope
- name stop conditions
- name expiration

If any field is missing, Codex should stop and request a consolidated approval
packet instead of acting.

## Ignoring Drafts Safely

It is safe to ignore any draft. Ignored drafts do not expire into action, do not
queue background work, and do not create permission for future Codex sessions.
