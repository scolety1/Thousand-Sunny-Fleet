# Chatroom UI Shell V1

Verdict: GREEN_OPERATOR_CONSOLE_CHATROOM_UI_SHELL_COMPLETE

## Purpose

The chatroom shell gives Tim a local ChatGPT-like surface for Project Main Bot interaction without mission execution, Codex invocation, API calls, or repo mutation from the browser.

## Behavior

- Tim can type a message locally.
- The Project Main Bot panel returns deterministic local guidance.
- The UI creates a draft mission preview JSON in memory.
- The UI shows GREEN/YELLOW/RED/TIM_REQUIRED style badges.
- The UI shows approval and next-safe-action panels.
- Copy buttons copy the draft or an HQ prompt to the clipboard.
- Sample conversation playback is local and deterministic.

## Execution Boundary

This shell has no command bridge. It does not write files, submit queue items, call Codex, call an API, start a server, start a background runner, or mutate the repo.
