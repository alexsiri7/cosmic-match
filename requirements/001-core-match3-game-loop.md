---
id: "001"
title: "Core match-3 game loop (M1)"
status: "done"
github_issue: 39
updated: 2026-05-12
---

## Why
The fundamental mechanic — swap adjacent tiles, match 3+ in a row, clear them, drop remaining tiles — is the entire game. Nothing else ships without it.

## What
Flutter + Flame match-3 game loop with a finite-state machine (`GamePhase`: idle → swapping → matching → falling → cascading → matching). Tap and swipe gesture input. Tile grid world rendered via Flame components.
