# Golden Gameplan Vision

Codex Fleet should become a bounded autonomous software studio.

The final system should be able to:

1. Run a ship through a bounded task batch.
2. Build, test, inspect, and screenshot the result.
3. Write canonical run evidence.
4. Package that evidence for review.
5. Accept validated external task packets.
6. Decide whether to run again, repair, park, or ask for taste.
7. Pause safely when rate limits or safety rules require it.
8. Resume when it is safe to continue.
9. Let the user check status and steer from a phone.

The desired human role is captain and editor, not terminal babysitter.

## North Star Loop

```text
Task queue
  -> bounded fleet run
  -> build/test/runtime/visual evidence
  -> RUN_RESULT.json
  -> audit package
  -> external review or local decision
  -> validated task packet
  -> decision: RUN_AGAIN / REPAIR / PARK / USER_TASTE_GATE
```

## What Autonomy Means Here

Autonomy means the fleet can continue through normal, expected situations:

- a clean run with remaining tasks
- a failed build that can be repaired safely
- a ship that should park because it is done
- a subjective design moment that needs user taste
- a rate-limit pause that should resume later
- a stale or blocked ship that should report clearly

Autonomy does not mean the fleet can do anything it wants.

## Non-Negotiables

- Preserve user work.
- Do not touch dirty repos blindly.
- Do not delete, reset, merge, push, deploy, or change production systems without explicit approval.
- Do not automate sensitive backend, auth, payment, migration, secret, or deployment work without the required gates.
- Do not keep running vague polish loops when no material progress is happening.
- Do not hide failures. Failed evidence is still evidence.

## Product Standard

The fleet should produce useful, understandable software, not motion.

For websites and demos, this means:

- simple first screen
- one clear audience
- one primary job per screen
- details available without dumping everything at once
- real mobile usability
- screenshots as proof

For analytical software, this means:

- deterministic formulas
- fixture expectations
- source quality notes
- confidence and uncertainty language
- no fake confidence

