# Fleet Emergency Stop Request

Emergency: none

Evidence only; not executable authority or approval.

## Allowed Values

- `none`
- `REQUEST_STOP`

## Request Fields

- Requested by: non-secret name or `unknown`
- Created at: non-secret timestamp or `unknown`
- Affected surface: `Codex Fleet`, `Phone HQ`, `selected future runner`, or `unknown`
- Non-secret reason: short plain-language reason only
- Urgency: `low`, `normal`, or `high`

## Reason

Write a short non-secret reason. Do not include PINs, passwords, MFA codes, recovery codes, keys, tokens, credentials, private screenshots, private device identifiers, customer data, or product data.

## Meaning

`REQUEST_STOP` is a high-priority cooperative stop request/signal for later safe handling. It can ask a later human-controlled HQ/Codex review to pause, classify, or repacketize work.

It is not arbitrary command execution, not arbitrary shell execution, Codex execution, process killing, remote access configuration, phone approval, runtime command binding, all-fleet authority, overnight runner authority, product-repo mutation, deploy authority, staging authority, commit authority, push authority, install authority, migration authority, lock deletion authority, permission widening authority, or secret-handling authority.

## Later Handling

A later HQ/Codex session must restate the stop request, verify scope, avoid secrets, and use an exact allowed task packet before doing anything. If the stop request is unclear, repeated, or asks for forbidden work, mark it `blocked` for HQ repacketization.
