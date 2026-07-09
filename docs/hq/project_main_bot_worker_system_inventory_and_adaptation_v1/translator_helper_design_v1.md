# Translator Helper Design V1

## Purpose

The Translator Helper turns Tim's natural language into TSF mission intent and turns worker/kernel output back into plain-language status. It exists so Tim does not have to become the manual router between prompt, packet, worker, verifier, and HQ.

## Tim Natural Language To Mission Intent

The helper should extract:

- project or lane
- requested outcome
- whether this is research, trace, docs, validation, implementation, review, or publication
- likely existing assets to trace first
- allowed reads and writes if stated
- hard forbidden actions
- expected artifacts
- validation expectations
- stop conditions
- true Tim gates

If Tim gives broad language, the helper should narrow it to one mission intent rather than asking a cluster of tiny technical questions.

## Mission Intent To Structured Packet

The helper should feed `tools/New-TsfMissionPacket.ps1` or the existing mission schema with:

- `mission_id`
- `project_id`
- `repo_path`
- `lane`
- `mission_type`
- role id
- allowed reads
- allowed writes
- forbidden reads
- forbidden writes
- forbidden actions
- expected artifacts
- preflight checks
- postrun checks
- stop conditions
- approval requirements
- HQ escalation policy

It should not skip Phase 0 source trace for any build-like request.

## Technical Output To Tim Summary

The helper should compress worker/kernel output into:

- verdict
- what changed
- what was reused
- what is blocked
- what validation ran
- what Tim must approve, if anything
- exact next safe prompt

It should preserve caveats without making Tim read raw logs.

## Ambiguity Handling

The helper should resolve routine ambiguity from TSF-local evidence:

- file naming mismatches
- whether a docs/control-plane artifact is enough
- whether a worker should be source tracer, builder, tester, auditor, or verifier
- whether a YELLOW artifact can be preserved and moved forward

It should ask Tim only when:

- product direction is genuinely ambiguous
- the requested project/repo cannot be identified
- a restricted action is required
- cross-lane expansion is required
- evidence conflicts and local source trace cannot resolve it

## When Not To Ask Tim

Do not ask Tim to pick:

- a routine worker role when evidence is enough
- a file name for a TSF-local report
- whether to validate JSON/CSV/Markdown artifacts
- whether to preserve a local handoff packet
- whether to continue safe TSF-local docs/control-plane synthesis

## Output Contract

The Translator Helper must output one of:

- structured mission intent ready for packet authoring
- a compact Tim question with exact missing authority
- a refusal/blocked note when requested work is outside scope
- a Tim-readable summary of completed worker/verifier output

Every output must preserve that evidence is not approval.
