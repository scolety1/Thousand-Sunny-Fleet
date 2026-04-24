# Task Queue Update Template

Use this when ChatGPT Pro returns new tasks.

## Rules

- Keep only safe unattended tasks as `- [ ]`.
- Do not use `- [ ]` for manual or blocked items.
- Every task must include forbidden scope.
- Keep tasks small enough for one Codex round.

## EasyLife Task Shape

```md
- [ ] EasyList tiny cleanup: make one copy-only or spacing-only improvement in a specific EasyList UI area. Do not change logic, routing, auth, Firebase, data structure, dependencies, deployment, generated output, TASK_QUEUE.md, or NIGHTLY_REPORT.md.
```

## Restaurant Demo Task Shape

```md
- [ ] Wine list preview polish: improve fake wine list copy, spacing, or sample rows so the demo feels more useful to a restaurant owner on a phone. Do not add backend, auth, payment, tracking, email sending, deployment, secrets, API keys, or real customer data.
```
