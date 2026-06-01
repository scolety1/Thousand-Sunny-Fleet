# Golden Gameplan Stage 7: Product Quality Contracts

## Purpose

Stage 7 teaches the fleet what "good enough to show a human" means before it keeps coding.

The fleet has been able to make things that are technically running, but the user has repeatedly called out a deeper problem:

```text
The sites are pretty, but overwhelming.
Everything is visible at once.
The main user job is not obvious.
The app feels like a demo of features instead of a finished product.
```

Stage 7 turns product usefulness, simplicity, hierarchy, and first-screen clarity into explicit contracts.

## Why This Matters

Without product contracts, the fleet can pass build/tests and still produce something confusing.

The decision engine from Stage 6 can only make good decisions if it knows whether:

- the first screen makes sense
- the main user job is visible
- secondary features are easy to find but not dumped on the first page
- copy is clear instead of vague or trendy
- the demo looks like a real customer could use it
- the product should run again or stop at a taste gate

Stage 7 supplies those definitions.

## Stage 7 Outcome

At the end of Stage 7, every active product ship should be able to define:

- audience
- primary job
- first-screen promise
- primary action
- secondary actions
- information hierarchy
- what must be hidden, deferred, or moved behind navigation
- mobile expectation
- demo data expectation
- product done contract
- taste gate trigger

## Non-Goals

Do not implement these in Stage 7:

- Redesigning real ships.
- Launching product runs.
- Auto-fixing websites.
- Full visual QA automation.
- External audit loop execution.
- Deployment or publishing.

This stage defines contracts and prompts. Later runs use them.

## Contract Files

Use these contract concepts unless implementation finds better names:

```text
DEMO_PROMISE.md
FIRST_SCREEN_CONTRACT.md
PRODUCT_QUALITY_CONTRACT.md
INFORMATION_HIERARCHY_CONTRACT.md
MOBILE_CONTRACT.md
DONE_CONTRACT.md
TASTE_GATE_CONTRACT.md
```

## Core Quality Rules

The fleet should learn these as first-class rules:

1. One audience per first screen.
2. One primary job per demo.
3. One primary action above the fold.
4. Secondary tools should be reachable, not dumped.
5. The first screen should create orientation, not overload.
6. Pretty is not enough if the product is confusing.
7. Demo data should feel realistic for the customer.
8. Copy should use concrete nouns, not vague pitch language.
9. Mobile must be checked for customer-facing demos.
10. If deterministic gates pass but taste is subjective, stop at taste gate.

## Demo Types

The contracts should support different product lanes:

### Customer-Facing Hospitality

Examples:

- restaurant website
- wine list
- private events inquiry
- guest-facing menu

First-screen expectation:

```text
Brand, place, offer, mood, and one obvious action.
```

### Manager-Facing Operations

Examples:

- manager brief
- order sheet
- checklist
- training hub

First-screen expectation:

```text
Today, status, priority, and one clear next action.
```

### Analytical Software

Examples:

- Niners War Room
- margin lab
- pricing model
- forecast tool

First-screen expectation:

```text
Current answer, confidence, key drivers, and audit trail.
```

### Personal Productivity

Examples:

- EasyLife
- task organizer
- notes/calendar assistant

First-screen expectation:

```text
What needs attention now and what can be safely done next.
```

## Phase List

1. Product Contract Templates
2. First-Screen Contract
3. Information Hierarchy Contract
4. Simplicity and Overload Gate
5. Demo Lane Profiles
6. Done Contract and Taste Gate
7. Product Evidence in Run Results
8. Stage 7 Integration Check

## Acceptance For Stage 7

Stage 7 is complete when:

- Contract templates exist.
- Product lanes are defined.
- First-screen quality can be checked from a contract.
- Overwhelming all-on-one-page layouts can be flagged.
- Done and taste-gate criteria are explicit.
- The decision engine can use product-quality evidence later.
- No product app code was changed as part of defining the stage.

## Hand-Off To Stage 8

Stage 8 will wrap the state, decision, and product-quality layers into a bounded autonomy command.

## Implementation Status

Status: GREEN

Implemented:
- reusable product-quality contract templates
- first-screen and information hierarchy contracts
- simplicity/overload gate
- lane profiles for hospitality, manager operations, analytical software, personal productivity, and local-business websites
- done/taste gate distinction
- product-quality evidence schema and sample fixture verdicts
- Stage 7 tests in `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.

Stage 7 did not edit real product app code, launch ships, rewrite task queues, or implement Stage 8 execution behavior.
