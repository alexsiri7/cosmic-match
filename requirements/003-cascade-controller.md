---
id: "003"
title: "Cascade controller"
status: "done"
updated: 2026-05-12
---

## Why
Matches can chain — new matches formed by falling tiles should trigger further clears. The cascade depth must be bounded to prevent infinite loops or runaway animation.

## What
`CascadeController` tracking cascade depth. Cap at 20; no-op beyond max. FSM transitions: `cascading → matching → falling → idle` (no direct `cascading → idle` edge).
