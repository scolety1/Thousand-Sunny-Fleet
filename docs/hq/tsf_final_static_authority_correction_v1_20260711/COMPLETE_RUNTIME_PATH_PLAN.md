# Complete Runtime Path Plan

New-TsfCompleteRuntimePathPlan is calculated before the first affected queue/lifecycle mutation. It covers:

- compact q/, l/, a/, p/, and staging paths;
- queue preflight, role, instruction, result, verifier, mission-registry, and context-update artifacts;
- fixed t01.json through t08.json transition evidence;
- transition temporary/backup and recovery markers;
- compact kernel-state snapshots s/s1 through s/s6;
- producer registry and registry temporary path;
- manifest/durable-result temporary and backup paths;
- admission, transaction, conflict, recovery, and atomic replacement templates.

Every path is checked for canonical containment, reparse containment, the 240 hard limit, and the 225 target. Missing required categories invalidate the plan.

The complete plan contains 93 typed paths. The maximum stressed path is 222 characters, logical type queue.kernel_state.s1. Raw mission, role, branch, run, and state descriptions cannot alter fixed filename length.
