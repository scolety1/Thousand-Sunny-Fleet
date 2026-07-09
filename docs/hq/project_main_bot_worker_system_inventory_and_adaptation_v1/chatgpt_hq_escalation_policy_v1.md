# ChatGPT HQ Escalation Policy V1

## Purpose

ChatGPT/API HQ is a strategic judge for major choke points. It is not a routine router, worker executor, approval authority, or replacement for the TSF kernel.

This lane creates policy only. It does not call an API and does not create credentials.

## Use ChatGPT/API HQ For

- major architecture switch
- ambiguous YELLOW where local evidence supports more than one safe path
- source-truth, ranking, model, formula, recommendation, or app-behavior promotion questions
- high-risk tradeoff with multiple valid local paths
- repeated blocker or loop after one bounded recovery pass
- approval framing when Tim must give exact authority
- conflicting worker reports that cannot be reconciled locally
- strategic finish-line selection when a phase risks becoming open-ended

## Do Not Use ChatGPT/API HQ For

- file existence checks
- obvious RED or GREEN decisions
- routine test failures
- artifact validation
- local branch or git status checks
- simple worker routing
- CSV/JSON parse checks
- markdown artifact existence checks
- normal Phase 0 trace classification
- routine preservation packets

## Required Input

Use the existing HQ escalation packet schema. The Project Main Bot should send only:

- mission summary
- preflight result
- verifier result
- blocker register
- changed files summary
- evidence snippets
- exact decision requested
- allowed verdicts
- required JSON response shape

Do not send raw logs or broad repo dumps unless a separate approved packet requires it.

## Authority Boundary

HQ output is strategic evidence. It cannot approve:

- push or merge
- deploy
- installs or migrations
- secrets, auth, payments, credentials, or account changes
- product repo access or mutation
- canonical NWR inspection or mutation
- normal NWR packet reads
- PrivateLens access or mutation
- proof runs
- all-fleet commands
- background runners
- model/ranking/formula/source-truth promotion
- app wiring or hidden sort
- API credentials or account setup

## Verdict Handling

- `GREEN`: Project Main Bot may continue with the named bounded local action if the kernel preflight allows it.
- `YELLOW`: Project Main Bot may preserve caveats, exclude non-blockers, and continue only within the named safe path.
- `RED`: stop and produce a RED packet or safer alternative.
- `TIM_REQUIRED`: stop and prepare exact Tim approval language.

## Escalation Anti-Loop Rule

Do not ask HQ to decide what local files exist, whether JSON parses, or whether a normal worker role fits. Use HQ only when a strategic choice would otherwise cause loop, overbuild, or unsafe promotion.
