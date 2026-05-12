---
id: "011"
title: "Release AAB build and signing"
status: "done"
updated: 2026-05-12
---

## Why
Publishing to the Play Store requires a signed Android App Bundle. The signing key must be kept out of the repo.

## What
Keystore credentials managed via `android/key.properties` (gitignored, example provided). CI injects `KEYSTORE_*` / `KEY_*` secrets. `flutter build appbundle --release` with Sentry DSN and feedback worker URL injected via `--dart-define`.
