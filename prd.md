# PRD: Cosmic Match — A Space-Themed Match-3 Mobile Game

**Version:** 1.0  
**Author:** Alex  
**Status:** Draft  
**Target Platform:** Android (Flutter + Flame engine)

---

## 1. Overview

Cosmic Match is a casual match-3 puzzle game with a cosmic/space theme. Players match planets, stars, and nebulae on a grid to clear them and progress through levels. The game is designed to be **glanceable** — playable in short sessions, while commuting or watching TV, requiring no sustained attention.

---

## 2. Goals

- Ship a polished, publishable Android game on the Play Store
- Build a reusable factory workflow for Claude Code to generate the project end-to-end
- Have fun and learn the mobile game publishing process
- Potential future monetisation (optional, post-launch)

---

## 3. Non-Goals (V1)

- iOS version (future)
- Multiplayer
- Rhythm or real-time mechanics
- In-app purchases (to be evaluated post-launch)
- Backend / leaderboards (future)

---

## 4. Target Audience

Casual mobile gamers who want something to play in short bursts — commuters, people watching TV, anyone wanting a low-stakes, satisfying experience.

---

## 5. Core Gameplay

### 5.1 The Grid
- Standard 8x8 grid
- 6 tile types: Planet (red), Planet (blue), Star (yellow), Nebula (purple), Moon (white), Comet (orange)
- Tiles fall from the top to fill empty spaces (gravity mechanic)

### 5.2 Matching Rules
- Swap two adjacent tiles (horizontal or vertical)
- Match 3 or more of the same tile in a row or column to clear them
- Invalid swaps snap back
- Chain reactions (cascades) occur when falling tiles create new matches

### 5.3 Match Bonuses
| Match Size | Effect |
|---|---|
| 3 tiles | Basic clear |
| 4 in a row | Creates a "Pulsar" tile — clears entire row when matched |
| 4 in an L/T shape | Creates a "Black Hole" tile — clears 3x3 area |
| 5 in a row | Creates a "Supernova" tile — clears all tiles of one type |

### 5.4 Level Structure
- Each level has a specific **goal** (e.g. "Clear 30 Planets", "Reach 5,000 points", "Clear all asteroid tiles")
- A **move limit** creates light pressure without stress
- Stars awarded (1-3) based on score or moves remaining

---

## 6. Progression

- 50 levels at launch
- Levels grouped into "galaxies" (sets of 10), each with a slightly different visual palette
- Difficulty ramps gently: bigger goals, fewer moves, obstacle tiles introduced gradually

### 6.1 Obstacle Tiles (introduced progressively)
- **Asteroid** (level 5+): Must be matched adjacent to it to clear
- **Ice Comet** (level 15+): Frozen tile, needs 2 matches next to it
- **Dark Matter** (level 30+): Immovable blocker tile

---

## 7. Visuals & Theme

- **Style:** Clean, colourful, slightly cartoon-ish space art. Think mobile-friendly, not photorealistic.
- **Tile designs:** Each tile is a distinct shape AND colour (accessibility)
- **Backgrounds:** Deep space — stars, galaxies, nebulae — per "galaxy" chapter
- **Animations:** Satisfying pop/burst on match, cascade glow effect, gentle idle animations on tiles
- **Name inspiration:** The constellation Lyra is the first "galaxy" chapter

---

## 8. Audio

- Ambient space soundscape (background, subtle)
- Satisfying match sound effects (different for 3, 4, 5+ matches)
- **No sound required for gameplay** — fully mute-friendly

---

## 9. UI / UX

### Main Screens
- **Home screen:** Play button, level select, settings
- **Level select:** Galaxy map with locked/unlocked levels and star ratings
- **Game screen:** Grid, current score, move counter, goal tracker, pause button
- **Level complete:** Stars earned, score, next level / replay buttons
- **Level failed:** Moves exhausted, replay / quit buttons

### UX Principles
- One tap = select tile, second tap (adjacent) = swap
- No tutorials beyond a brief first-level overlay
- No forced ads or interruptions in V1
- Portrait orientation only

---

## 10. Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter |
| Game Engine | Flame (Flutter game engine) |
| Platform | Android |
| State Management | Riverpod or Bloc |
| Local Storage | Hive (level progress, settings) |
| CI/CD | GitHub Actions |
| Hosting/Distribution | Google Play Store |

---

## 11. Milestones

| Milestone | Description |
|---|---|
| M1 — Core Loop | Working grid, swap mechanic, match detection, gravity, score |
| M2 — Levels | Level goals, move counter, win/lose states, level select |
| M3 — Polish | Animations, sound effects, full tile art, bonus tiles |
| M4 — Content | 50 levels, 5 galaxy chapters, obstacle tiles |
| M5 — Ship | Play Store listing, icon, screenshots, privacy policy |

---

## 12. Success Criteria (V1)

- Successfully published on Google Play Store
- Core loop feels satisfying to play
- 50 levels completable
- No crashes on standard Android devices (Android 8+)

---

## 13. Future Considerations (Post V1)

- iOS port
- Daily challenge levels
- Leaderboards
- Cosmetic unlockables (tile skins, themes)
- Optional rewarded ads / one-time purchase to remove ads
- Power-ups (extra moves, shuffle, bomb)
