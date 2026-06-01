# Stage 12 Phase 5 Prompt: Budget And Overnight View

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 5 only: Budget and Overnight View.

Goal:
Define the dashboard view for rate limits, budget mode, overnight runs, safe landing, and resume status.

The view should show:
- budget level
- rate governor decision
- selected ships
- active overnight window
- next check time
- safe landing status
- reset estimate/source
- resume eligibility
- resume attempts used
- ships paused for rate limits
- morning report link

Required warning states:
- healthy
- cautious
- low
- critical
- exhausted
- reset_pending
- recovered

Guardrails:
- Do not fabricate exact budget numbers.
- Unknown budget must be labeled unknown/conservative.
- Do not implement actual scheduling.
- Do not expose private account details.

Acceptance:
- Budget/Overnight view spec exists.
- It maps to Stage 10 rate governor and resume metadata.
- It includes examples for critical budget safe landing and recovered resume.

Proof:
Show spec path and example states.
```

## Notes

This view should prevent "just because I'm away does not mean spend everything."

## Implemented Budget / Overnight View

The control-room report shows:

```text
Level: <Stage 10 governor level>
Decision: <Stage 10 governor decision>
Reason: <short human-readable reason>
```

Recognized warning states:

| Level | Dashboard Treatment |
| --- | --- |
| healthy | Bounded dry-run/run suggestions may be shown if other gates pass. |
| cautious | Prefer status-only suggestions. |
| low | Block new model-heavy work. |
| critical | Show safe landing as the top action. |
| exhausted | Wait for reset; no implementation suggestion. |
| reset_pending | Wait for reset or manual recovered signal. |
| recovered | Resume only when Stage 10 eligibility is green. |
| unknown | Conservative status-only mode. |

Critical budget example:

```text
Budget: critical -> SAFE_LAND_NOW
Next: let safe landing stand; resume only after recovered evidence.
```

Recovered example:

```text
Budget: recovered -> ALLOW_RUN
Next: show dry-run selected ship; still require selected scope and clean state.
```
