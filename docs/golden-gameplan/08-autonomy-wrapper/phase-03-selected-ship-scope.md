# Stage 8 Phase 3 Prompt: Selected Ship Scope

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 3 only: Selected Ship Scope.

Goal:
Make selected ship scope mandatory and safe.

The wrapper must require explicit ship selection or a named preset.

Valid scopes:
- one ship
- explicit ship list
- approved preset
- fixture-only test scope

Invalid scopes:
- implicit all ships
- dirty unowned ships
- archived ships
- production/high-risk ships without explicit approval
- ships outside configured projects

Scope validation should report:
- selected ships
- excluded ships
- exclusion reasons
- dirty/running warnings
- safe-to-touch status

Guardrails:
- Do not launch selected ships in this phase.
- Do not clean dirty repos.
- Do not override safe-stop requests.

Acceptance:
- Missing scope fails fast.
- Unknown ship fails fast.
- Fixture-only scope works.
- Dirty active ships are marked unsafe unless active PID owns work.

Proof:
Show scope validation examples.
```

## Notes

This is one of the big protections against accidental rate-limit drains.

## Implementation Status

Status: GREEN

`Test-FleetAutonomyScope` requires explicit `-Ship` or the approved `fixture-only` preset. Missing scope fails fast, unknown ships fail fast, max selected ships is bounded, and tests prove selected scope does not expand to all ships.
