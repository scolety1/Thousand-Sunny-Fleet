# Translator Helper Contract V1

The Translator Helper converts:

`	ext
Tim natural language -> normalized intent -> mission draft -> Tim-readable result summary
`

It does not call an LLM runtime, invoke Codex CLI, execute commands, or approve work. It normalizes intent into a Project Main Bot mission draft and classifies whether the request is safe, needs main bot review, needs Tim approval, needs HQ strategy, or is blocked unsafe.

It should ask Tim only for true authority or product-direction blockers. Routine worker routing, file naming, validation selection, and TSF-local docs/control-plane choices should be handled locally.
