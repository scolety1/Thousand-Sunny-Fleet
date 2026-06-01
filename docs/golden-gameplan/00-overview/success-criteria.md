# Golden Gameplan Success Criteria

Codex Fleet is considered successful when it can run meaningful software work
without constant supervision while still stopping for the right reasons.

## System-Level Success

- Every run produces canonical machine-readable evidence.
- Every ship has a lifecycle state.
- Every state transition is explainable.
- External audit packages can be generated on demand.
- External task packets can be validated before ingestion.
- The fleet can decide `RUN_AGAIN`, `REPAIR`, `PARK`, or `USER_TASTE_GATE`.
- Overnight mode can safe-land before rate limits are exhausted.
- Rate-limit pauses can resume automatically when policy allows.
- The captain can check status from a phone and send safe commands.

## Reliability Success

- Unrelated safe-stop requests do not block unrelated ships.
- Failed experiments still write failure evidence.
- Long loops have retry caps or time caps.
- Missing repos are not misclassified as dirty repos.
- Heartbeat and lock cleanup avoids false stale detection.
- Ship lock names do not collide.
- Project base branches come from configuration instead of assumptions.

## Product Quality Success

For website and demo ships:

- The first screen is clear in under ten seconds.
- The primary audience and promise are obvious.
- The page avoids information overload.
- Secondary details are easy to find but not dumped onto the first screen.
- Mobile screenshots are part of the evidence.
- Visual, copy, and accessibility checks are recorded.

For analytical ships:

- Formula specs and fixture expectations are explicit.
- Tests cover core formulas.
- Confidence language is tied to evidence.
- Source quality and missing data are visible.
- External audit packets can challenge the model without changing code directly.

## Operator Success

The captain should be able to ask:

```text
How is the fleet doing?
What is stuck?
What finished?
What needs taste?
What should run next?
Are we low on limits?
When will paused ships resume?
```

and receive a short, accurate answer.

## Final Acceptance

The final system should support this workflow:

```text
Select ships and mission
  -> run bounded work
  -> safe-land or complete
  -> package evidence
  -> audit externally if needed
  -> import validated tasks
  -> run again, repair, park, or ask for taste
```

If the fleet cannot explain what happened, it is not done.

## Safety Acceptance

The Golden Gameplan is not complete if any implementation path can:

- launch all ships by accident
- execute remote commands without local validation
- resume from low-budget pause without eligibility checks
- ingest external task packets without schema validation
- run destructive tests on real product repos by default
- claim exact rate-limit status without a real local signal

