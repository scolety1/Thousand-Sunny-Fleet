# Operator Console Skeleton Decision V1

## Decision

Start with a local read-only static console skeleton generated from TSF filesystem state. Do not build Tauri, Electron, a web server, or a command-capable console yet.

## Why

The current TSF kernel is foreground and filesystem-backed. A read-only console can inspect queue state, context capsules, recent reports, validation summaries, and blocked gates without adding network/server behavior or new packages.

## First Screen

- active project and branch
- mission queue counts
- latest Project Main Bot decision
- blocked TIM_REQUIRED gates
- latest validation packet
- next recommended action

## Must Not Do Yet

- execute commands
- edit missions
- approve gates
- push, merge, deploy, install, migrate, access secrets, or start runners
- call ChatGPT/OpenAI API
- spawn workers

## Future Gate Needed

A separate Operator Console implementation gate should approve the actual technology path and whether it remains read-only or gains command capabilities.
