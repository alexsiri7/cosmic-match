---
id: "005"
title: "Score system"
status: "done"
updated: 2026-05-12
---

## Why
Players need feedback on how well they're doing. Score accumulates as tiles are cleared and cascades fire.

## What
`Score` model with `add()` method clamped to 999,999,999 and ignoring negative inputs (SEC-008 score clamp). `Match3Game.scoreNotifier` drives the `HudOverlay` widget.
