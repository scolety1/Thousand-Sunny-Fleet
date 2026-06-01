# Product-Specific Controlled Launch Checklist

Use this checklist before Codex Fleet touches a real demo or product repo. Audit
packages can prove the harness is safe; they do not automatically approve
product-specific work.

## Launch Gate

Every product launch request must name:

- explicit ship
- explicit repo path
- repo cleanliness status
- lane profile or safety lane
- demo promise
- first-screen contract
- acceptance command
- rollback plan
- budget limit
- latest audit package path
- captain approval

If any item is missing, the decision is `BLOCK_PRODUCT_LAUNCH`.

## Never Approve From Vague Requests

Reject requests like:

- "launch all"
- "reset the whole cellar fleet"
- "make it beautiful"
- "fix everything"
- "run whatever is next"

Rewrite them into one selected ship, one lane, one target, one acceptance check,
and one rollback plan before work begins.

## Universal Preflight

Before approving any real product work:

- Confirm the ship is explicitly selected.
- Confirm the repo is clean, or every dirty file is owned and documented.
- Confirm no active PID, safe-stop, heartbeat, or lock state is ambiguous.
- Confirm the latest audit package path exists or is intentionally not needed.
- Confirm the task packet is validated if the work came from an external audit.
- Confirm the budget is known and not in low-token or weekly-preview pause.
- Confirm the acceptance command is deterministic.
- Confirm rollback/no-op behavior is documented.
- Confirm no merge, push, deploy, publish, or manual lock deletion is requested.

## Hospitality Customer

Use for public restaurant, bar, wine-list, catering, event, or hospitality
websites.

Required approval fields:

- explicit ship
- customer-facing audience
- restaurant or venue brand example
- lane profile: `docs/templates/product-quality/lane-profiles/hospitality-customer-website.md`
- demo promise
- first-screen contract
- primary action, such as view menu, reserve, inquire, or browse wine list
- mobile first-screen expectation
- acceptance command
- rollback plan
- screenshot or preview evidence path

First-screen requirements:

- show the actual restaurant/product signal immediately
- show one primary action
- show only enough menu/story/location context to orient the visitor
- hide deep menus, policies, private admin, setup, and dense data tables behind
  clear navigation

Do not approve if the request is only "make it beautiful" without lane/profile,
demo promise, first-screen contract, and acceptance command.

## Manager/Internal

Use for restaurant operator, manager, staff, shift, inventory, prep, or service
brief tools.

Required approval fields:

- explicit ship
- manager/internal audience
- lane profile: `docs/templates/product-quality/lane-profiles/manager-internal-restaurant-tool.md`
- current shift or operating context
- primary decision or action for the manager
- first-screen contract
- acceptance command
- rollback plan
- data fixture or mocked data source
- evidence path for mobile or tablet readability if relevant

First-screen requirements:

- show staffing/demand pulse
- show attention queue or approvals/exceptions
- show service risk
- show one-tap controls or clear next actions
- push historical BI, setup, permissions, exports, and admin settings deeper

Do not approve passive dashboards with no action path.

## Analytical

Use for scoring tools, models, forecasts, dashboards, formula work, and decision
support.

Required approval fields:

- explicit ship
- analytical audience
- formula/source-of-truth note
- expected inputs and sample fixture data
- expected outputs and golden values
- acceptance command
- rollback plan
- audit package path or evidence bundle
- known limitations

First-screen requirements:

- show the core question being answered
- show result summary and confidence/assumptions
- show inputs used for the calculation
- keep raw tables, formula derivations, and exports available but not dominant

Do not approve if formulas, fixtures, or expected outputs are missing.

## Backend-Sensitive

Use for backend, auth, payments, deployment, migrations, package/dependency
changes, production data, or external API contracts.

Required approval fields:

- explicit ship
- sensitive domain named
- architecture or safety approval path
- migration/API/dependency/auth/payment/deploy gate evidence as applicable
- acceptance command
- rollback plan
- budget limit
- audit package path
- explicit captain approval for the sensitive scope

First-screen requirements:

- not applicable unless a user-facing surface is part of the task
- if a UI is involved, include the selected lane's first-screen contract too

Do not approve backend-sensitive work from mobile-only approval, raw shell, stale
audit packets, missing rollback, or broad file globs.

## Maintenance

Use for docs, tests, fixture upkeep, harness cleanup, lint repairs, evidence
packaging, or non-product runtime maintenance.

Required approval fields:

- explicit ship or harness repo
- maintenance target
- expected behavior change, or "no runtime behavior change"
- acceptance command
- rollback plan
- audit/evidence path if the repo is dirty
- budget limit

First-screen requirements:

- not applicable unless visible product surfaces are touched
- if visible UI is touched, switch to the matching product lane checklist

Do not approve broad cleanup, generated output churn, lock deletion, dependency
changes, or product redesign hidden inside maintenance work.

## Approval Record

Record the approval in this shape:

```text
Ship:
Repo:
Lane:
Repo cleanliness:
Demo promise:
First-screen contract:
Acceptance command:
Rollback plan:
Budget:
Audit package:
Captain approval:
Stop if:
```

## Product Launch Verdicts

- GREEN: every required field is present, repo state is understood, acceptance
  is deterministic, rollback is clear, and captain approval is explicit.
- YELLOW: deterministic checks are ready but product taste, copy, or lane choice
  needs captain review.
- RED: scope is broad, repo state is ambiguous, packet evidence is invalid,
  rollback is missing, budget is unsafe, or sensitive domains lack approval.
