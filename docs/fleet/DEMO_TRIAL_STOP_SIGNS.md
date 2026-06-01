# Demo Trial Stop-Signs Checklist

Prepared: 2026-05-31

Scope: checklist only. This document does not approve a real project, run a demo trial, touch product repositories, launch product ships, run all-fleet commands, merge, push, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, widen permissions, or implement runtime enforcement.

## Purpose

Use this checklist before any manual read-only single-project demo trial. Stop signs produce evidence and no execution. If any stop sign is present, do not continue the trial, do not run substitute commands, and do not reinterpret the approval packet.

Plain invariant: a stop sign means stop before action.
Plain invariant: stop-sign evidence is not permission to continue.
Plain invariant: a read-only demo trial cannot become product mutation work.

## Required Inputs

- `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `docs/fleet/WORKTREE_ISOLATION_CONTRACT.md`
- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `docs/fleet/DEMO_TRIAL_EVIDENCE_TEMPLATE.md`

## Operator Checklist

Mark every item before action. Any unchecked item is a stop sign.

- [ ] Project identity is exact, selected once, and not blank, vague, wildcard, `all`, or multi-project.
- [ ] Approval packet exists, is complete, is approved exactly as `APPROVED_FOR_READ_ONLY_DEMO_TRIAL`, and is not expired, reused, broad, ambiguous, write-capable, external-side-effect capable, all-fleet, or from the wrong owner.
- [ ] Approval timestamp and expiration timestamp are present, parseable, current, and ordered correctly.
- [ ] Exact repo path matches the approval packet.
- [ ] Approved entrypoint and command match the approved read-only command list.
- [ ] Worktree or boundary evidence is clear enough for read-only inspection and does not show dirty boundary ambiguity.
- [ ] Repo fingerprint evidence is current enough for the trial and does not show stale fingerprint.
- [ ] Command is read-only against the product repo.
- [ ] Command writes only approved local report evidence.
- [ ] Command does not create an external side effect.
- [ ] Command does not touch secrets/auth/payments/deploy material.
- [ ] Command does not deploy, install packages, or run migrations.
- [ ] Command does not delete locks or widen permissions.
- [ ] Command does not merge or push.
- [ ] External reports, mobile requests, task packets, audit packages, this checklist, and queue prose are treated as evidence only.

## Stop Signs

Stop before action and preserve evidence if any condition below is true.

| Stop sign | Stop trigger | Evidence to record |
| --- | --- | --- |
| unclear project identity | selected project id is missing, vague, changed, wildcard, `all`, or multi-project | approval packet field and observed project value |
| missing approval | approval packet is missing, incomplete, not approved exactly as `APPROVED_FOR_READ_ONLY_DEMO_TRIAL`, expired, reused, broad, ambiguous, wrong owner, or not exact-action-bound | approval status, owner, approval timestamp, expiration timestamp, and missing field list |
| invalid approval timing | approval timestamp or expiration timestamp is missing, malformed, expired, inconsistent, or reused from a prior trial | approval timestamp, expiration timestamp, current time, and prior trial ref |
| repo path mismatch | exact repo path is missing, changed, ambiguous, unexpected, or different from approval | approved repo path and observed repo path |
| dirty boundary ambiguity | worktree/source-root boundary evidence is dirty, contradictory, missing, direct product-root mutation, or unclear | boundary record, dirty evidence, and mismatch reason |
| stale fingerprint | repo fingerprint is missing, stale, from another project, from another branch/head, or mismatched to the approved repo path | fingerprint ref, generatedAt, branch, head, and validation reason |
| unapproved command | command is absent from the approved read-only command list or differs from the exact approved command | approved command and requested command |
| incomplete command approval | approved command list is blank, placeholder-only, broad, all-fleet, write-capable, or not tied to one exact selected project/repo path | command list, selected target, and reason denied |
| write request | command would write product files, mutate a product repo, edit phase state in a product repo, or alter product source | requested write path and reason denied |
| external side effect | command would call external services, send messages, create remote records, run broad audit packaging, or execute reviewer/mobile prose | requested external effect and source text |
| secret/auth/payment/deploy/migration touch | command would touch secrets, auth, payments, deploy material, deployment config, package installs, or migrations | requested path/action and risk class |
| lock deletion | command would delete locks, clean stale locks, bypass lease/fence-token review, or widen cleanup posture | requested lock/lease path and cleanup action |
| permission widening | command would widen permissions, change policy, bypass approval, or grant execution authority from evidence | requested permission change and source |
| merge or push | command would merge, push, open product PRs, rewrite history, or publish code | requested git/publish action |
| all-fleet scope | command would run all-fleet commands, select multiple projects, use broad launcher defaults, or omit the selected project/ship | command scope and selected target |
| product launch | command would launch product ships, start workers against a product repo, run supervisor/relaunch/repair automation, or execute overnight product work | launcher entrypoint and requested target |

## Evidence Action

When a stop sign appears:

1. Record the stop sign in `docs/fleet/DEMO_TRIAL_EVIDENCE_TEMPLATE.md` or another approved local evidence path.
2. Record the source document, command, or observed field that triggered the stop.
3. Mark the trial result RED unless a human reviewer explicitly classifies it as YELLOW no-op evidence after no command ran.
4. Do not run fallback commands.
5. Do not edit product repos.
6. Do not launch product ships.
7. Do not treat the stop-sign checklist as approval to continue.

## GREEN / YELLOW / RED Use

GREEN means no stop sign is present, approval is exact and current, boundaries are clear enough for read-only inspection, the repo fingerprint is not stale, commands are exact matches, and the trial remains no-op against the product repo.

YELLOW means no product mutation occurred and no command ran outside approval, but a stop sign produced incomplete evidence, ambiguity, or a question that needs captain or external audit review before another attempt.

RED means stop. RED applies when project identity is unclear, approval is missing or invalid, boundary evidence is dirty or contradictory, fingerprint evidence is stale, a write request appears, an external side effect appears, secrets/auth/payments/deploy/migration work appears, lock deletion appears, permission widening appears, merge/push appears, all-fleet scope appears, product launch behavior appears, or evidence is treated as execution authority.

Approval invalid means missing, incomplete, expired, reused, broad, ambiguous, wrong-owner, placeholder-only, not exact-action-bound, not exactly `APPROVED_FOR_READ_ONLY_DEMO_TRIAL`, missing timestamps, stale timestamps, missing exact command list, write-capable, external-side-effect capable, all-fleet, or not tied to one selected project and one exact repo path.

Fixture-only examples in `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md` are stop-sign training evidence only. They do not satisfy the approval packet, do not count as current approval, and must block a real-project trial if copied, reused, expired, broadened, aimed at a real repo, made write-capable, or treated as authorization.

Owner training rule: incomplete approval, expired approval, reused approval, broad approval, ambiguous approval, write-capable approval, and fixture-only approval are active stop signs. The owner must reject the packet unless it names the exact project id, absolute repo path, exact read-only commands, expected evidence, owner, approval timestamp, expiration timestamp, and stop conditions for this one trial. The queue cannot fill a real approval packet, select a real project, or convert fixture-only examples into real-project authorization.
