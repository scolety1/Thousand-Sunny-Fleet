# Read-Only Demo Approval Packet Template

Prepared: 2026-06-03

Scope: future read-only demo readiness planning evidence only.

This packet is an unfilled template. It does not approve product-repo access, demo execution, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

Canonical notice: Evidence only; not executable authority or approval.

## Purpose

This template defines the minimum shape of a future human-filled approval packet for read-only demo readiness review. It is not approval by itself. A schema, template, queue entry, audit report, validation summary, generated evidence record, UI label, button, notification, mobile request, prompt, or DOCX report cannot fill this packet or approve a demo.

## Completeness Checklist

Use `docs/fleet/READ_ONLY_DEMO_APPROVAL_COMPLETENESS_CHECKLIST.md` to review whether a future human-filled packet is complete. The checklist verifies approval packet completeness without filling one or approving a demo. This approval packet remains an unfilled template and cannot approve real work.

## Required Fields

Every future packet must be filled by a human and must include all of these fields:

- `schemaVersion`
- `packetId`
- `approvalState`
- `humanOwner`
- `selectedTarget`
- `readOnlyOrNoOpActions`
- `repoFingerprintRef`
- `expiresAt`
- `stopSigns`
- `evidenceRefs`
- `validationCommands`
- `nonAuthorityNotice`
- `forbiddenCapabilities`
- `validationDecision`
- `denialReasons`

## Unfilled Template

```yaml
schemaVersion: 1
packetId: read-only-demo-approval-UNFILLED
approvalState: unfilled_template
humanOwner: ""
selectedTarget:
  targetType: ""
  targetId: ""
  singleTargetOnly: false
readOnlyOrNoOpActions: []
repoFingerprintRef: ""
expiresAt: ""
stopSigns: []
evidenceRefs: []
validationCommands: []
nonAuthorityNotice: "This unfilled template is evidence only and cannot approve or execute work."
forbiddenCapabilities:
  productRepoAccess: false
  demoExecution: false
  productMutation: false
  packageCreation: false
  packageSending: false
  remoteAccess: false
  runtimeCommandBinding: false
  phoneApproval: false
  allFleetExecution: false
  stagingCommitPushDeploy: false
  installsOrMigrations: false
  secretsAuthPaymentsDeployWork: false
  lockDeletionOrPermissionWidening: false
  nonMockUiImplementation: false
  futureAuthority: false
validationDecision: denied_unfilled_template
denialReasons:
  - missing-human-owner
  - missing-selected-target
  - missing-read-only-actions
  - missing-repo-fingerprint-ref
  - missing-expiration
```

## Valid Future Packet Requirements

A future read-only demo approval packet is valid for review only when it proves:

- exact human owner
- exact selected target
- exact read-only/no-op action list
- current repo fingerprint reference
- expiration timestamp
- stop signs
- evidence references
- validation command references
- non-authority notice
- all forbidden capability fields remain `false`

Even a valid packet remains evidence until a separate, bounded, human-approved implementation task exists. It cannot approve runtime command binding, package sending, product-repo access, demo execution, or future authority.

## Denial Vocabulary

The packet must fail closed for:

- `deny_blank_target`
- `deny_all_target`
- `deny_wildcard_target`
- `deny_multi_target`
- `deny_missing_owner`
- `deny_stale_fingerprint`
- `deny_phone_only_approval`
- `deny_reused_approval`
- `deny_write_capable_action`
- `deny_package_sending`
- `deny_command_binding`
- `deny_remote_access`
- `deny_evidence_as_authority`
- `denied_unfilled_template`

Blank, `all`, wildcard, comma-packed, or multi-target selected targets are denied. Missing owner, stale fingerprint, phone-only approval, reused approval, write-capable action, package-sending, command-binding, remote-access, and evidence-as-authority attempts are denied.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Stop Conditions

Stop and repacketize if a future task requires approving a real demo, filling approval for a real product, product-repo access, runtime command binding, package creation/sending, remote access, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or treating evidence as authority.
