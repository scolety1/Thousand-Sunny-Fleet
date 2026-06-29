Problem: Static console copy drifted from phrases protected by regression tests.

Cause: A quiet wording polish removed exact return-triage language that older tests still required.

Fix: Restore the required phrase in read-only UI copy while keeping the new section calm.

How to catch earlier next time: After any console copy edit, run the static prototype phrase checks before the full suite.

Test/check to add: Assert required console phrases and scan for executable hooks in the same regression block.

Applies to which projects/tools: Fleet Console, Daily Driver Pack, Coder Upgrade Pack, and any static TSF console section.
