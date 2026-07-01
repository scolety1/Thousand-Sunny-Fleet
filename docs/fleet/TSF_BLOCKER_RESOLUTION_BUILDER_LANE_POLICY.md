# TSF Blocker-Resolution Builder Lane Policy

Prepared: 2026-06-30

Evidence only; not executable authority or approval.

## Purpose

TSF lanes must stay safe without turning safe review into paperwork gravity.
When a lane discovers a prerequisite or blocker, the next question is not only
"is this safe to merge?" The next question is "what concrete artifact would
unblock the next step?"

The process can be safe, but inefficient. TSF should not spend a long run
merging layer after layer of review packets that all prove "not approved yet"
when the next useful move is to build the missing artifact.

This policy is docs/tests/harness-only. It does not approve product repo work,
archived project reactivation, push, merge, deploy, installs, migrations,
secrets/auth/payments work, proof runs, remote access, all-fleet commands,
overnight/background runners, package sending, runtime command binding, lock
deletion, permission widening, or broader authority.

## Observed Failure Mode

In a separate Codex workflow, the process stayed conservative and safe, but
spent too much time running review/merge lanes that documented blockers one
layer at a time instead of switching earlier into blocker-resolution builder
lanes.

The pattern:

- each discovered prerequisite became its own lane
- many lanes produced docs or CSV review packets proving "not approved yet"
- HQ merged those packets safely, but each merge added overhead
- when a lane found a blocker, the next lane often documented the blocker again
  instead of directly building the artifact needed to remove it
- HQ waited too long to ask what artifact would unblock the next step
- progress was real, but the process optimized for proof packets before
  artifact builders

The useful work was still useful: source admissions, sidecars, labels, display
context, and parity packets advanced the work. The true remaining blockers were
narrowed to missing player-week zero eligibility and return/special TD scoring semantics.
The mistake was not unsafe work. The mistake was too much safe
paperwork before attacking the final blockers.

## Wrong Finish Line Failure Mode

The wrong finish line can turn a useful review-only phase into endless proof
work. In the NFLVerse example, full scoring parity became the gate, even though the useful thing is lagged factual usage.

When the useful artifact is review-only and intentionally incomplete, TSF must
define the finish line as "done enough" for that phase instead of proving every
possible field. A phase is done enough when it has the agreed artifact, field
map, missingness behavior, validation summary, source mappings, guardrails, and
closeout of what remains blocked or intentionally excluded.

For a review-only data phase, the builder should produce an actual review-only dataset artifact, not another "should we?" report.

No app wiring, model logic, or rankings belong in a review-only source/data
phase unless Tim explicitly approves that scope.

Routes are not blocking. TPRR and YPRR are out unless a rights-cleared upload exists. Preserve missingness; do not create proxy route fields, participation hacks, or fake certainty.

## Checkpoint Merge Rule

Merge only at checkpoints.

Completed evidence packets that all feed one builder should be batch-reviewed as
one checkpoint, not merged as separate mini-events. A lane can finish locally
without forcing HQ to merge immediately. Merge churn is overhead unless it
unblocks an independent builder or closes a safety risk.

Batch merge the completed evidence packets, then start one builder lane, not more research.

## Exclude And Move On Rule

Prefer exclude and move on over investigate forever.

If a field, source, or metric is not required for the phase finish line and
cannot be safely admitted now, explicitly close it for the phase. Do not let an
unresolved optional field reopen the phase.

YELLOW is acceptable when it means safe, review-only, incomplete by design.

No more lanes unless they produce one of: dataset, schema, validator, field map, sidecar, or merge-ready policy artifact.

## Required Lane Declaration

Every lane must declare its unblock artifact.

Each lane report must answer:

- unblock artifact: what artifact, validator, policy matrix, source admission,
  sidecar, parity result, fixture, or code path would unblock the next step?
- builder enabled: which next builder can act after this lane?
- blocker removed or narrowed: which blocker did this lane remove, or how did
  it narrow the next build?
- review-only reason: if the lane cannot produce or enable an unblock artifact,
  why not?
- exact next builder: if this lane is review-only, which exact builder should
  run next?

If a lane cannot name an unblock artifact and cannot explain why review-only is
necessary, it should stop and redirect rather than produce another packet.

## No Blocker-Only Lane Rule

No blocker-only lane unless the blocker cannot be attacked directly.

Examples:

- If the blocker is missing zero eligibility, build a zero eligibility artifact.
- If the blocker is unclear return/special TD semantics, build a policy matrix
  or scoring semantics resolver.
- If the blocker is parity uncertainty, build or rerun the parity artifact.
- Do not write a second report that merely restates the same missing artifact.

A blocker-only lane is acceptable only when:

- the blocker requires Tim/HQ to choose policy or scope before any builder can
  proceed
- the blocker is a safety boundary such as secrets, auth, payments, deploy,
  migration, package install, archived project reactivation, product repo
  mutation, or remote access
- the lane's output is a policy matrix or validator that directly enables the
  builder

## Batch Review-Only Docs

Batch review-only docs.

Do not merge five separate docs packets when they are all prerequisites to one
builder. Let lanes produce artifacts, then HQ reviews the batch. Review-only
packets should be grouped unless separating them removes a real risk or
unblocks independent builders.

## Parallel Lane Rule

Use parallel lanes only when they produce independent artifacts.

Good parallel lanes:

- player-week universe builder
- return/special TD policy resolver
- scoring parity rerun prep

Bad parallel lanes:

- three lanes that all restate the same source-policy blocker
- three packet-only lanes that all conclude "not approved yet"
- one builder lane blocked behind another lane that has not produced its
  unblock artifact

## HQ Redirect Question

HQ should ask after every lane: "Can the next lane build, or are we just documenting?"

If the answer is "just documenting," stop and redirect unless the lane is
producing a policy matrix, validator, or exact human decision packet needed by a
builder.

## Artifact Preference

Prefer artifact-producing lanes over packet-producing lanes.

A useful lane should ideally create one of:

- a usable review-only artifact that directly enables a builder
- a validator
- a policy matrix
- a source admission that removes a concrete blocker
- a fixture or sidecar
- a parity result
- a bounded builder work order with exact allowed files and checks

Packet-producing lanes are not bad, but a packet is progress only when it
removes a blocker, narrows the next build, or prevents an unsafe build.

## Yellow Is Not Progress By Itself

Do not confuse safe with complete.

A YELLOW packet may be safe to merge, but it is not durable progress unless it removes a blocker or narrows the next build.

Final lane reports must say one of:

- durable progress: artifact produced or blocker removed
- narrowed progress: next builder and unblock artifact are now exact
- safe but not progress: packet merged without removing or narrowing a blocker
- redirected: lane stopped because it was about to document instead of build

## Final Report Addendum

Any TSF lane that touches blockers should add:

- unblock artifact
- builder enabled
- blocker removed or narrowed
- phase finish line and whether this lane moved it closer
- review-only reason, if any
- whether the next lane can build now
- whether any packet-only follow-up should be batched
- fields/scope explicitly excluded for this phase

Short version: build the next needed artifact or directly unblock the builder that will.
