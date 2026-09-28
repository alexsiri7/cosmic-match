---
created: '2026-09-28'
github_issue: null
id: '012'
status: draft
title: Adopt an OpenSpec specification as the statement of what Cosmic Match should
  be
updated: '2026-09-28'
---

## Why

Requirement files record changes, not what the project should be. Auditing Cosmic Match against them means replaying a change log, and their hand-kept status drifts: several here are recorded wrongly (002 special tiles and 007 home screen and level map are recorded done but only partly built; 006 and 009 still describe a CRC32 save check that the code replaced with HMAC-SHA256). A spec per capability, changed only through spec-change pull requests, gives one document to audit the code against and lets Lachesis derive status from the work itself — the same move Lachesis made in its own requirement 030.

## What

The repository holds its specification in OpenSpec format under openspec/specs/, one file per capability: board-and-matching, crash-reporting, in-app-feedback, levels-and-progression, release-and-distribution, save-integrity, scoring, screens-and-theme, special-tiles. The specs are validated in CI on every pull request and push to the default branch. From then on, work starts as spec changes, and the existing requirement files are superseded by the spec.

## Issues

_None yet._