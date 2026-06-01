# Product Quality Contract

Purpose: define whether a ship is useful, understandable, and showable.

Required fields:
- Audience
- Primary job
- Demo lane
- Demo promise
- Proof artifact
- Primary path
- First-screen contract path
- Information hierarchy contract path
- Simplicity verdict
- Mobile verdict when user-facing
- Copy clarity note
- Realistic demo data note
- Done or taste-gate recommendation

Pass criteria:
- one audience
- one primary job
- one high-value outcome
- one representative proof artifact
- one primary first-screen action
- secondary tools reachable but staged
- primary, secondary, and tertiary content layers are explicit
- concrete copy with specific nouns
- realistic data for the domain
- deterministic proof still passes

## Promise -> Proof -> Path Gate

Every visible product demo must pass this gate before it can be called done:

```text
For [audience], this demo proves that [product] helps them [high-value outcome].

Promise: the first screen states the outcome in user language.
Proof: the first screen shows one realistic artifact, example, output, status, or
sample that makes the promise credible.
Path: the first screen gives one obvious primary CTA that starts the primary job.
```

This gate rejects feature dumping. A demo is not better because it exposes every
module, setting, chart, table, helper, admin note, and rare workflow on the first
screen. Show the representative payoff first, then stage the rest.

## Information Layers

Primary content belongs on the first screen:
- promise
- proof artifact
- primary CTA
- one short credibility or status signal

Secondary content belongs one step deeper or lower on the page:
- supporting examples
- alternate routes
- common filters
- brief explanation

Tertiary content must be deferred:
- advanced settings
- docs and specs
- admin-only controls
- rare workflows
- full feature inventory
- raw exports
- internal implementation notes

Failure example:
```text
Looks polished, but asks the user to inspect eight panels, three CTAs, and internal
admin notes before they know what the product is for.
```

Valid example:
```text
For a floor manager, this demo proves that Shift Ledger helps them catch the
three service risks that need action before dinner rush.

Promise: tonight's shift is safe to run if the attention queue is clear.
Proof: a realistic shift pulse card shows labor coverage, two approvals, and one
stock risk.
Path: the primary CTA opens "Review attention queue."

Secondary staffing and service tabs are reachable. Historical reports, payroll
exports, and setup rules are deferred.
```

Invalid example:
```text
The first screen shows sales, payroll export, vendor settings, full staff table,
menu admin, every alert, customer marketing copy, and three unrelated CTAs.
It looks complete, but the primary audience, proof artifact, and first action
are unclear.
```

Evidence:
- contract docs
- build/test/runtime proof
- screenshots
- reviewer verdict: PASS, PASS_WITH_NOTES, FAIL, or NEEDS_TASTE_REVIEW
