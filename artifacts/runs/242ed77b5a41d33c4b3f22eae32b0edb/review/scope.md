# PR Review Scope: #132

**Title**: Fix feedback service box collision and improve logging
**URL**: https://github.com/alexsiri7/cosmic-match/pull/132
**Branch**: ci/store-listing-v2 → main
**Author**: alexsiri7
**Date**: 2026-04-29

---

## Pre-Review Status

| Check | Status | Notes |
|-------|--------|-------|
| Merge Conflicts | ✅ None | MERGEABLE |
| CI Status | ⏳ Pending | 2 checks pending |
| Behind Base | ✅ Up to date | 0 commits behind |
| Draft | 📝 Draft | This is a draft PR |
| Size | ✅ Normal | 16 files, +52/-203 |

---

## Changed Files

| File | Type | Additions | Deletions |
|------|------|-----------|-----------|
| `.github/workflows/setup-store-listing.yml` | config | +1 | -1 |
| `lib/services/feedback_service.dart` | source | +3 | -2 |
| `pubspec.lock` | config | +8 | -0 |
| `store-listing/upload_listing.py` | source | +26 | -186 |
| `test/services/feedback_service_test.dart` | test | +14 | -14 |
| `store-listing/screenshots/*.png` | asset | +0 | -0 |

**Total**: 16 files, +52 additions -203 deletions

---

## File Categories

### Source Files (2)
- `lib/services/feedback_service.dart`
- `store-listing/upload_listing.py`

### Test Files (1)
- `test/services/feedback_service_test.dart`

### Configuration (2)
- `.github/workflows/setup-store-listing.yml`
- `pubspec.lock`

### Assets (11)
- `store-listing/screenshots/*.png` (Icons and screenshots)

---

## Review Focus Areas

Based on changes, reviewers should focus on:

1. **Service Integrity**: Renaming the Hive box in `feedback_service.dart` to avoid collisions.
2. **Logging Improvements**: Enhanced logging for feedback submission URLs.
3. **Script Refactoring**: Significant cleanup/refactoring in `store-listing/upload_listing.py` (-186 lines).
4. **Test Alignment**: Verification that `feedback_service_test.dart` covers the box name change and logging logic.
5. **CRC32 Contract**: Check if any Hive model changes require CRC32 updates (though mostly box name changed).

---

## CLAUDE.md Rules to Check

- **CRC32 Persistence Contract**: Ensure any Hive-backed changes maintain integrity.
- **Dependency changes**: `pubspec.lock` was modified; verify it aligns with `pubspec.yaml`.
- **FSM Transitions**: Unlikely to be impacted, but verify if `FeedbackService` interacts with game state.

---

## Workflow Context (if from automated workflow)

_No workflow artifacts found - this appears to be a manual PR._

---

## CI Details

- Analyze: pending
- Integration Tests: pending

---

## Metadata

- **Scope created**: 2026-04-29T10:00:00Z
- **Artifact path**: `/mnt/ext-fast/cosmic-match/artifacts/runs/242ed77b5a41d33c4b3f22eae32b0edb/review/`
