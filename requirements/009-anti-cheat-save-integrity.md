---
id: "009"
title: "Anti-cheat / save integrity controls (SEC-008)"
status: "done"
github_issue: 8
updated: 2026-05-12
---

## Why
Client-side games are vulnerable to trivial manipulation (injecting taps during animations, setting scores to max, editing save files). Basic mitigations protect the experience without server infrastructure.

## What
Four controls: FSM Input Gate (drops tap/swipe input when `phase != idle`), Score Clamp (clamps to 999,999,999), Cascade Depth Limit (cap at 20), CRC32 Save Integrity (resets tampered save data to initial).
