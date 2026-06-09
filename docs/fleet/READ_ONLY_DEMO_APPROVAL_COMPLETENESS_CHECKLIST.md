# Read-Only Demo Approval Completeness Checklist

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, tests, and external audit preparation only.

Evidence only; not executable authority or approval.

This checklist verifies approval packet completeness without filling one or approving a demo. It is a review aid for future human-filled read-only demo approval packets. It does not approve product-repo access, demo execution, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

## Required Completeness Items

A future packet is incomplete unless every item below is present, current, exact, and internally consistent:

- accountable human owner
- exact selected target
- single selected target identity
- expiration timestamp
- single-use intent where applicable
- exact no-op/read-only action list
- current repo fingerprint evidence reference
- evidence refs
- validation command refs
- forbidden operations reviewed
- stop signs reviewed and inactive
- non-authority notice
- all forbidden capability fields remain false

## Fail-Closed Cases

Any packet with these traits must fail closed:

- blank approval packet
- broad target scope
- expired approval
- reused approval
- phone-only approval
- wildcard target
- multi-target scope
- write-capable action
- stale repo fingerprint
- implied approval
- missing accountable human owner
- package sending request
- remote access request
- runtime command binding request
- all-fleet execution request
- overnight runner request
- product mutation request
- evidence-as-authority attempt

Blank, broad, expired, reused, phone-only, wildcard, multi-target, or write-capable approvals fail closed. A GREEN audit, passing validation, task queue status, generated evidence file, manifest, prompt, DOCX report, UI label, button, notification, mobile request, or validation summary cannot repair those failures.

## Review Sequence

1. Confirm the packet is not the unfilled template.
2. Confirm a named accountable human owner is present.
3. Confirm the exact selected target is one single target, not blank, `all`, wildcard, comma-packed, or multi-target.
4. Confirm the expiration timestamp is present and current.
5. Confirm single-use intent where applicable.
6. Confirm the exact no-op/read-only action list contains only approved planning labels.
7. Confirm the repo fingerprint evidence reference is current and local-evidence-only.
8. Confirm evidence refs and validation command refs are local and bounded.
9. Confirm forbidden operations were reviewed and remain denied.
10. Confirm stop signs are reviewed and inactive.
11. Confirm the non-authority notice is present.

## Non-Authority Boundary

The approval packet template remains an unfilled template and cannot approve real work. This checklist cannot fill an approval packet, select product repos, approve real-project work, approve a demo, execute commands, create or send packages, bind runtime commands, approve phone actions, run all-fleet commands, run an overnight runner, or grant future authority.

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Evidence References

- `docs/fleet/READ_ONLY_DEMO_APPROVAL_PACKET.md`
- `templates/read-only-demo-approval-schema.json`
- `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`
- `docs/fleet/READ_ONLY_DEMO_GO_NO_GO_SCORECARD.md`
