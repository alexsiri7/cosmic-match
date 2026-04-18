# CLAUDE.md

## Commands

```bash
# Analyse
flutter analyze

# Test
flutter test

# Build (debug APK)
flutter build apk --debug

# Build (release AAB) — requires android/key.properties (see android/key.properties.example)
flutter build appbundle --release
# To enable Sentry crash reporting, add: --dart-define=SENTRY_DSN=<your-dsn>
# (CI injects this automatically via the SENTRY_DSN secret)

# Generate Hive adapters (run after adding new Hive types)
dart run build_runner build --delete-conflicting-outputs

# Dependency changes — always recommit pubspec.lock after running pub get/upgrade
# (see SECURITY.md §11.1 for full lockfile policy)
flutter pub get
```

## Project Layout

```
lib/
  game/           # Flame game, FSM, world, components
                  #   Input/FSM enums (GamePhase, SwipeDirection) defined in match3_game.dart
    theme/        # Tile color palette constants (kTilePalette — derived from TileType.colorValue;
                  #   kTileGlowPalette — derived from TileType.glowValue, used for selection border;
                  #   kTileSelectedOverlay — transparent, selection drawn by _GlowBorder stroke;
                  #   cosmic_theme.dart — Lyra galaxy tokens: kCosmicInk, kCosmicNebulaA/B, kCosmicAccent, kBoardBackdrop, kGridLine)
  models/         # Pure data: Score, TileType, LevelProgress
  screens/        # Flutter screens: HomeScreen, MapScreen, GameScreen, modals
                  # Navigation: _Screen enum + _buildScreen() in main.dart
  services/       # Hive persistence (ProgressService) and key management (KeyService)
  widgets/        # Flutter overlay widgets (HudOverlay — driven by Match3Game.scoreNotifier)
test/             # Unit tests mirror lib/ structure
```

## Architecture Invariants

### FSM Transitions (`lib/game/match3_game.dart`)

`_validTransitions` is the single source of truth for legal `GamePhase` transitions.
When adding a new phase, update the map — illegal transitions assert in debug and reset
to idle in release builds.

```
idle → swapping → matching → falling → cascading → matching
                ↳ idle (invalid swap)              ↳ falling → idle (no new matches)
```

Note: there is no `cascading → idle` direct edge by design. A cascade that ends cleanly
must pass through `matching → falling → idle`.

### Pattern Detection Priority (`lib/game/pattern_detector.dart`)

Detection passes run in strict priority order. **Do NOT reorder**:

1. 5-in-a-row → Supernova
2. L/T shape → Black Hole
3. 4-in-a-row → Pulsar
4. 3-in-a-row → basic clear

Tiles consumed by a higher-priority pass are added to the `claimed` set and skipped by
lower-priority passes, preventing double-counting.

### CRC32 Persistence Contract (`lib/models/level_progress.dart`, `lib/services/progress_service.dart`)

`LevelProgress.toMap()` must always include a `crc` field computed over all other fields
using `_canonicalize()` (key-sorted representation). `ProgressService._isValid()` rejects
any map missing or mismatching the CRC and resets to `LevelProgress.initial()`.

When adding new fields to `LevelProgress`:
- Include them in `toMap()` before computing the CRC
- The canonicalized format sorts keys alphabetically, so insertion order does not matter

**Cipher invariant**: `ProgressService` accepts an optional `HiveAesCipher` (SEC-004).
A box opened with a cipher cannot later be opened without one (and vice-versa). For V1
there are no existing users, so this is safe. In future migrations, ensure the cipher
parameter is consistent across all `ProgressService` instantiation sites.

### SEC-008 Integrity Controls

Four mitigations protect against trivial client-side manipulation (see SECURITY.md §1.1):

| Control | Location | Behaviour |
|---------|----------|-----------|
| FSM Input Gate | `GridTile.onTapDown`, `GridTile.onDragStart` | Drops all tap and swipe input when `phase != idle` |
| Score Clamp | `Score.add()` | Clamps to 999,999,999; ignores negative inputs |
| Cascade Depth Limit | `CascadeController.increment()` | Caps at 20; no-op beyond max |
| CRC32 Save Integrity | `LevelProgress.toMap()` / `ProgressService._isValid()` | Resets tampered save data |
