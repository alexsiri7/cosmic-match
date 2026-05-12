---
id: "002"
title: "Special tile patterns (Pulsar, Black Hole, Supernova)"
status: "done"
updated: 2026-05-12
---

## Why
Pure 3-in-a-row match-3 becomes repetitive quickly. Special tiles created by larger matches add strategic depth and spectacle.

## What
Pattern detector with strict priority order: 5-in-a-row → Supernova, L/T shape → Black Hole, 4-in-a-row → Pulsar, 3-in-a-row → basic clear. Tiles claimed by a higher-priority pattern are excluded from lower-priority passes.
