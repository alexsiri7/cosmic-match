---
id: "006"
title: "Level progress persistence (Hive)"
status: "done"
github_issue: 21
updated: 2026-05-12
---

## Why
Progress must survive app restarts. On-device storage avoids any network dependency or privacy concerns.

## What
`LevelProgress` model persisted via Hive with AES cipher encryption (SEC-004). CRC32 integrity check: tampered save data is detected and reset to `LevelProgress.initial()`. Generated Hive adapters via `build_runner`.
