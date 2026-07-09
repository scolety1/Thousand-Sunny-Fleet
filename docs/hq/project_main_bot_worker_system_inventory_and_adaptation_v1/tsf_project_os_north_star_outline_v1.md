# TSF Project OS North Star Outline V1

## Project Vision

Thousand Sunny Fleet should become Tim's local project operating system. Tim should talk to one Project Main Bot per project, not manually route work among prompts, docs, packets, branches, validators, and workers.

The system should feel simple from Tim's side:

```text
Tim -> Translator Helper -> Project Main Bot -> TSF Runtime Kernel -> Specialized Workers -> Verifier/Preservation -> HQ only for major choke points
```

## Current Status

TSF now has many real pieces:

- foreground mission schema and lifecycle runner
- preflight validator
- approval ledger
- worker instruction adapter stub
- post-run verifier
- preservation packet writer
- HQ escalation packet schema
- autonomy envelope
- blocker recovery loop
- safe stop matrix
- specialized lane taxonomy
- project management packet guidance
- external auditor role prompts
- static console and inbox concepts

What is missing is one unified Project Main Bot role that owns project goal, state, routing, worker assignment, and loop prevention.

## Target Operating Model

1. Tim speaks normally.
2. Translator Helper converts that into mission intent.
3. Project Main Bot checks current project state and Phase 0 source trace.
4. Project Main Bot selects a worker role.
5. TSF kernel validates mission packet and approvals.
6. Worker executes only bounded scope.
7. Verifier fails closed or passes evidence.
8. Preservation worker writes handoff.
9. HQ is used only for major strategic choke points.
10. Tim sees concise status and exact approval text only when needed.

## Bot Hierarchy

- Project Main Bot: owner of one project state and routing.
- Translator Helper: natural-language and packet-shape bridge.
- Context / Memory Steward: freshness and source trace steward.
- Parallel Lane Coordinator: collision and sequencing planner.
- Specialized Workers: bounded executors or reviewers.
- Verifier / Preservation: closeout and evidence layer.
- ChatGPT/API HQ Judge: strategic judge for major choke points only.

## Worker Roles

The preserved V1 roles are:

1. Project Main Bot
2. Translator Helper Bot
3. Context / Memory Steward
4. Parallel Lane Coordinator
5. Organizer Worker
6. Builder Worker
7. UI Builder Worker
8. AI Builder Worker
9. Stats/Data Worker
10. Tester Worker
11. Auditor Worker
12. Export Creator Worker
13. Researcher / Source Tracer Worker
14. Verifier Worker
15. Refactor Worker
16. Documentation Worker
17. Release / Preservation Worker
18. ChatGPT/API HQ Escalation Judge

## Authority Model

The Project Main Bot can decide routine routing and safe TSF-local control-plane work. Workers can decide implementation details only inside mission scope. The verifier decides whether evidence satisfies the packet. HQ gives strategic advice only. Tim approves true restricted gates.

## Approval Philosophy

Approval should be exact, rare, and tied to one action. TSF should not ask Tim to arbitrate routine technical choices. It should ask Tim for product direction, protected repo access, publication, deployments, installs, secrets, proof runs, all-fleet, background runners, or promotions of source truth and model behavior.

## Communication Model

Tim-facing output should be short:

- verdict
- what changed
- what was reused
- what is blocked
- what validation ran
- exact next approval text if needed

Worker-facing output should be structured:

- mission packet
- role
- allowed reads/writes
- forbidden actions
- expected artifacts
- verifier contract
- stop conditions

## Long-Term UI Idea

The Operator Console should display the Project Main Bot state, mission queue, approval gaps, worker results, verifier state, and preservation packets. It should not execute commands directly until a separate runtime bridge exists and passes security review.

## Near-Term Implementation Path

1. Add role id and parent/owner fields to mission packets.
2. Add a Project Main Bot packet adapter that creates mission packets from mission intent.
3. Add role-profile validation to preflight.
4. Add lane-collision validator from mission allowed writes.
5. Add context freshness input to mission authoring.
6. Add HQ escalation packet writer for strategic choke points.

## What Must Not Be Forgotten

- Existing assets must be traced before building.
- Product repo work needs exact approval.
- Canonical NWR is protected.
- Normal NWR packets are separate.
- Review-only evidence is not production approval.
- UI labels and generated packets are not authority.
- Local commits are not push approval.
- Persistent runners and APIs wait until the foreground path is trusted.
