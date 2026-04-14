# cosmic-match

A space-themed match-3 mobile game built with Flutter + Flame.

## Status

Milestone M1 (core game loop) — draft / in progress.

## Requirements

- Flutter >= 3.41.0
- Dart SDK >= 3.0.0

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate Hive adapters
```

## Running Tests

```bash
flutter test
```

## Running on Device

```bash
flutter run                       # debug, attached device
flutter build apk --debug         # debug APK
```
