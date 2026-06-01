# Stage 4 Audit Prompt

Use this prompt after Stage 4 implementation is complete and an audit package is
created.

```text
You are auditing Codex Fleet after Golden Gameplan Stage 4: Task Packet Ingestion.

Context:
Codex Fleet is a local orchestration system for AI coding projects called ships.
Stage 4 was supposed to let the fleet safely ingest structured task packets from
external ChatGPT agents or humans, without blindly obeying unsafe output.

Stage 4 goals:
1. Task packet schema exists.
2. Packet storage preserves original input.
3. Packet validator rejects malformed, stale, duplicate, unknown-project, and
   forbidden-scope packets.
4. External tasks must satisfy Task Contract V2.
5. Valid tasks can be appended safely to the correct ship queue.
6. Rejected tasks do not mutate queues.
7. Ingest reports are written in Markdown and JSON.
8. Replay/stale protection prevents accidental duplicate application.
9. No ship is launched automatically by packet ingestion.

Audit the attached package and answer:

1. Is Stage 4 complete enough to start Stage 5?
2. Can a malicious or vague packet mutate TASK_QUEUE.md?
3. Are stale commit checks strong enough?
4. Are duplicate packet/task protections strong enough?
5. Are rejection reports useful enough to debug bad packets?
6. Are task-quality checks strict enough?
7. Are tests covering failure paths, or only happy paths?
8. What is the smallest patch list before Stage 5?

Output format:
- Verdict: GREEN / YELLOW / RED
- Top blockers
- Evidence cited by file
- Unsafe ingestion risks
- Missing tests
- Recommended patch order
- Decision: proceed to Stage 5 or stop

Do not suggest state-machine or decision-engine features unless ingestion itself
is safe. Focus on safe acceptance/rejection of external tasks.
```

