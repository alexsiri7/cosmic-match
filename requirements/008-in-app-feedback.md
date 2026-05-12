---
id: "008"
title: "In-app feedback with screenshot annotation"
status: "done"
github_issue: 108
updated: 2026-05-12
---

## Why
During development and early access, collecting annotated bug reports directly from the game (without requiring the user to leave the app) accelerates iteration.

## What
`FeedbackSheet` bottom-sheet with screenshot capture and annotation overlay (red freehand strokes). `FeedbackService` submits to a Cloudflare Worker (`feedback.alexsiri7.workers.dev`). Offline queue (`FeedbackQueueService`) persists unsent reports via Hive when connectivity is unavailable.
