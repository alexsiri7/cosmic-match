---
id: "010"
title: "Sentry crash reporting"
status: "done"
updated: 2026-05-12
---

## Why
Release builds may crash in ways that don't reproduce locally. Sentry captures exceptions automatically without sending PII or game content.

## What
`sentry_flutter` integrated with `dropUnactionableEvents` filter (drops channel-buffer Abort errors and Google Fonts CDN fetch failures). DSN injected at build time via `--dart-define=SENTRY_DSN`. Blank DSN disables Sentry (opt-in for releases).
