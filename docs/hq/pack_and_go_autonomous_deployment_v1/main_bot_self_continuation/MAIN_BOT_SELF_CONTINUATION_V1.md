# Project Main Bot Self-Continuation V1

## Purpose

This layer lets the Project Main Bot continue safe local TSF work without asking Tim for routine technical routing decisions.

## Allowed Local Decisions

- choose worker role
- create mission draft
- run dry-run lifecycle
- call tester or auditor in dry-run
- retry once after recoverable local failure
- preserve and stop
- update context capsule
- create local commit after validation
- classify GREEN, YELLOW, RED, or TIM_REQUIRED

## Escalation Gates

The Project Main Bot must escalate for push, merge, deploy, installs, migrations, secrets, credentials, product repo access, canonical NWR access, ChatGPT/OpenAI API, paid APIs, background runners, all-fleet, broad worker spawning, source-truth/ranking/model promotion, and app wiring.

## Implementation

`tools/Invoke-TsfProjectMainBotSelfContinuation.ps1` wraps the existing Project Main Bot dry-run route and applies `fleet/control/project-main-bot-self-continuation-policy.v1.json`. It does not execute workers, call APIs, or start background work.
