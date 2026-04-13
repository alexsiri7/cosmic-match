# Cosmic Match — Product Requirements

## Overview

**Problem**: Casual gamers want a satisfying, low-commitment puzzle game for short play sessions (commuting, TV, downtime). Most match-3 games are bloated with ads, forced tutorials, and aggressive monetisation that ruins the casual experience.
**Solution**: A polished, space-themed match-3 puzzle game built with Flutter and Flame — 50 levels across 5 galaxy chapters, with bonus tiles, obstacle mechanics, and satisfying animations. No ads, no IAP in V1.
**Branch**: `ralph/cosmic-match`

---

## Goals & Success

### Primary Goal
Ship a polished, publishable Android match-3 game on the Google Play Store.

### Success Metrics
| Metric | Target | How Measured |
|--------|--------|--------------|
| Play Store publication | Published & approved | Store listing live |
| Core loop satisfaction | Feels satisfying to play | Manual playtesting |
| Level completeness | 50 levels completable | All levels tested end-to-end |
| Stability | No crashes on Android 8+ | Testing on standard devices |

### Non-Goals (Out of Scope)
- iOS version — future consideration after Android launch
- Multiplayer — not needed for casual single-player experience
- In-app purchases — to be evaluated post-launch
- Backend / leaderboards — future feature
- Rhythm or real-time mechanics — conflicts with glanceable design
- Power-ups — post V1 feature

---

## User & Context

### Target User
- **Who**: Casual mobile gamers
- **Role**: People looking for short-burst entertainment during commutes, TV watching, or downtime
- **Current Pain**: Existing match-3 games are bloated with aggressive ads, forced tutorials, and pay-to-win mechanics

### User Journey
1. **Trigger**: User has idle time (commute, waiting, watching TV)
2. **Action**: Opens app → selects level from galaxy map → plays match-3 puzzle by swapping tiles to meet level goal within move limit
3. **Outcome**: Level cleared with 1-3 stars, progress saved, moves to next level or replays for better score

---

## UX Requirements

### Interaction Model
- Portrait orientation only
- Tap to select tile, tap adjacent tile to swap
- No tutorials beyond brief first-level overlay
- No forced ads or interruptions

### Main Screens
| Screen | Purpose | Key Elements |
|--------|---------|-------------|
| Home | Entry point | Play button, level select, settings |
| Level Select | Galaxy map | Locked/unlocked levels, star ratings per level |
| Game | Core gameplay | 8x8 grid, score, move counter, goal tracker, pause |
| Level Complete | Victory | Stars earned, score, next level / replay buttons |
| Level Failed | Defeat | Moves exhausted, replay / quit buttons |

### States to Handle
| State | Description | Behavior |
|-------|-------------|----------|
| Empty | First launch, no progress | All levels locked except Level 1 |
| Loading | Level loading | Brief transition, load level config and grid |
| Playing | Active gameplay | Grid interactive, move counter decrementing |
| Paused | Pause button pressed | Overlay with resume/quit options |
| Win | Goal met with moves remaining | Star calculation, level complete screen |
| Lose | Moves exhausted before goal | Level failed screen with replay option |

---

## Technical Context

### Tech Stack
| Layer | Choice |
|-------|--------|
| Framework | Flutter |
| Game Engine | Flame (Flutter game engine) |
| Platform | Android (min SDK: Android 8 / API 26) |
| State Management | Riverpod |
| Local Storage | Hive |
| CI/CD | GitHub Actions |
| Distribution | Google Play Store |

### Architecture Notes
- **Project structure**: Standard Flutter project with Flame game widget embedded via `GameWidget`
- **Game components**: Flame `Component` tree — `CosmicMatchGame` (FlameGame) → `Board` → `Tile` components
- **Grid model**: 8x8 2D array of tile types, managed in a `BoardState` class
- **Level system**: JSON-based level configs defining goal type, target count, move limit, obstacles, and grid layout
- **State flow**: Riverpod providers manage app-level state (navigation, progress); Flame manages in-game state (board, score, moves)
- **Storage**: Hive boxes for level progress (stars, unlocked levels) and settings (sound on/off)
- **Tile types**: Enum with 6 base types (PlanetRed, PlanetBlue, Star, Nebula, Moon, Comet) + 3 bonus types (Pulsar, BlackHole, Supernova) + 3 obstacle types (Asteroid, IceComet, DarkMatter)
- **Match detection**: Scan rows and columns for 3+ consecutive same-type tiles; prioritise longer matches for bonus creation
- **Gravity**: Column-based drop, fill from top with random tiles, then re-scan for cascades

### Key Patterns (Flutter + Flame conventions)
- **Game class**: Extends `FlameGame` with `HasTappables` mixin for input handling
- **Components**: Each tile is a `PositionComponent` with `SpriteComponent` or shape rendering
- **Game loop**: Flame's `update(dt)` for animations and state transitions
- **Overlays**: Flame overlay system for Flutter widgets on top of game (menus, HUD)
- **Audio**: `flame_audio` package for SFX and background music
- **Storage**: `hive_flutter` for local persistence with type adapters

---

## Implementation Summary

### Story Overview
| ID | Title | Priority | Dependencies |
|----|-------|----------|--------------|
| US-001 | Project scaffolding & dependencies | 1 | — |
| US-002 | Tile model & grid data structure | 2 | US-001 |
| US-003 | Game board rendering | 3 | US-002 |
| US-004 | Tile selection & swap input | 4 | US-003 |
| US-005 | Match detection algorithm | 5 | US-002 |
| US-006 | Tile clearing & gravity | 6 | US-005, US-003 |
| US-007 | Cascade chain reactions | 7 | US-006 |
| US-008 | Score system & HUD | 8 | US-007, US-004 |
| US-009 | Level data model & loader | 9 | US-002 |
| US-010 | Move counter & goal tracking | 10 | US-009, US-008 |
| US-011 | Win/lose detection & screens | 11 | US-010 |
| US-012 | Home screen & navigation | 12 | US-001 |
| US-013 | Level select screen | 13 | US-012, US-009 |
| US-014 | Local storage with Hive | 14 | US-011, US-013 |
| US-015 | Bonus tile creation | 15 | US-005 |
| US-016 | Bonus tile activation effects | 16 | US-015, US-006 |
| US-017 | Obstacle tiles | 17 | US-006, US-009 |
| US-018 | Animations & visual effects | 18 | US-006, US-004 |
| US-019 | Audio system | 19 | US-008 |
| US-020 | Galaxy chapters & backgrounds | 20 | US-013 |
| US-021 | Level content pack (50 levels) | 21 | US-017, US-016, US-020 |
| US-022 | App polish & Play Store prep | 22 | US-021, US-019, US-018 |

### Dependency Graph
```
US-001 (scaffolding)
  ├→ US-002 (tile model)
  │    ├→ US-003 (board rendering)
  │    │    ├→ US-004 (swap input)
  │    │    │    ├→ US-008 (score + HUD)
  │    │    │    └→ US-018 (animations)
  │    │    └→ US-006 (clearing + gravity)
  │    │         ├→ US-007 (cascades)
  │    │         │    └→ US-008
  │    │         ├→ US-016 (bonus activation)
  │    │         ├→ US-017 (obstacles)
  │    │         └→ US-018
  │    ├→ US-005 (match detection)
  │    │    ├→ US-006
  │    │    └→ US-015 (bonus creation)
  │    │         └→ US-016
  │    └→ US-009 (level data)
  │         ├→ US-010 (moves + goals)
  │         │    └→ US-011 (win/lose)
  │         │         └→ US-014 (storage)
  │         ├→ US-013 (level select)
  │         │    ├→ US-014
  │         │    └→ US-020 (galaxies)
  │         └→ US-017
  └→ US-012 (home screen)
       └→ US-013

US-008 → US-010 → US-011 → US-014
US-008 → US-019 (audio)
US-021 (50 levels) ← US-017 + US-016 + US-020
US-022 (ship) ← US-021 + US-019 + US-018
```

---

## Validation Requirements

Every story must pass:
- [ ] `flutter analyze` — no errors or warnings
- [ ] `flutter test` — all tests pass
- [ ] App builds: `flutter build apk --debug`
- [ ] Manual verification of acceptance criteria

---

*Generated: 2026-04-13T23:50:00Z*
