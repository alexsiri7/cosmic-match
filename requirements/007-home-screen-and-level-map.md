---
id: "007"
title: "Home screen and level map"
status: "done"
updated: 2026-05-12
---

## Why
Players need an entry point and a way to navigate between levels (or the game session in M1).

## What
`HomeScreen` as the app entry point. `MapScreen` for level selection. Navigation managed via `_Screen` enum + `_buildScreen()` in `main.dart`.
