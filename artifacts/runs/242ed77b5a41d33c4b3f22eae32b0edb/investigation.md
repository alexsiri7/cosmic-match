# Investigation: Bug: Test feedback

**Issue**: #127 (https://github.com/alexsiri7/cosmic-match/issues/127)
**Type**: BUG
**Investigated**: 2026-04-29T10:30:00Z

### Assessment

| Metric | Value | Reasoning |
|--------|-------|-----------|
| Severity | LOW | This is a "Test feedback" issue, likely used for verifying the feedback system; no critical breakage reported. |
| Complexity | LOW | The issue is a placeholder for testing the feedback flow, involving only the feedback service and sheet. |
| Confidence | HIGH | The feedback system is well-documented and the codebase exploration confirms its implementation details. |

---

## Problem Statement

The user is reporting "Test feedback" in issue #127. This appears to be a verification task to ensure the feedback submission pipeline (Flutter app → Cloudflare Worker → GitHub) is functioning correctly. The issue body contains context about app version, OS, and device.

---

## Analysis

### Root Cause / Change Rationale

The "bug" is likely a test case to verify the end-to-end feedback flow. There is no actual logic error reported, but the existence of the issue suggests the system *is* working (as it successfully created the issue). 

However, looking at the codebase, I noticed a potential conflict:
- `FeedbackService` and `FeedbackQueueService` both use the same Hive box name `'feedback_queue'`.
- `FeedbackService` uses `PendingFeedback` model.
- `FeedbackQueueService` uses `FeedbackItem` model.
- If both are active, they will corrupt each other's data in Hive.

### Evidence Chain

WHY: Feedback submission might fail or behave unexpectedly.
↓ BECAUSE: Two different services are competing for the same Hive box with different data structures.
  Evidence: `lib/services/feedback_service.dart:12` - `static const _boxName = 'feedback_queue';`
  Evidence: `lib/services/feedback_queue_service.dart:7` - `static const _boxName = 'feedback_queue';`

↓ BECAUSE: `FeedbackService` uses `PendingFeedback` which is a simple Map-based storage.
  Evidence: `lib/services/pending_feedback.dart`

↓ ROOT CAUSE: Architectural redundancy/overlap between the Cloudflare Worker path and the direct GitHub path.
  Evidence: `lib/services/feedback_service.dart` (Worker path) vs `lib/services/feedback_queue_service.dart` (GitHub path).

### Affected Files

| File | Lines | Action | Description |
|------|-------|--------|-------------|
| `lib/services/feedback_service.dart` | 12 | UPDATE | Rename box to `feedback_worker_queue` to avoid collision. |

### Integration Points

- `lib/main.dart` initializes `FeedbackService`.
- `lib/screens/feedback_sheet.dart` uses `FeedbackService` via the `onSubmit` callback.

---

## Implementation Plan

### Step 1: Isolate Worker Queue

**File**: `lib/services/feedback_service.dart`
**Lines**: 12
**Action**: UPDATE

**Current code:**
```dart
static const _boxName = 'feedback_queue';
```

**Required change:**
```dart
static const _boxName = 'feedback_worker_queue';
```

**Why**: To prevent data corruption between the Worker-based feedback system and the direct GitHub feedback system (which uses `FeedbackQueueService`).

---

### Step 2: Add Logging to Feedback Submission

**File**: `lib/services/feedback_service.dart`
**Lines**: 127-130
**Action**: UPDATE

**Current code:**
```dart
      if (response.statusCode == 201) {
        gameLogger.d('FeedbackService: posted successfully');
        return true;
      }
```

**Required change:**
```dart
      if (response.statusCode == 201) {
        final respBody = jsonDecode(response.body);
        gameLogger.i('FeedbackService: posted successfully. Issue: ${respBody['url']}');
        return true;
      }
```

**Why**: To better track the results of feedback submissions in logs.

---

## Validation

### Automated Checks

```bash
flutter analyze
flutter test test/services/feedback_service_test.dart
```

### Manual Verification

1. Open the feedback sheet in the app.
2. Submit a "Test feedback" with an annotation.
3. Check logs to see the success message and the URL of the created issue.
4. Verify that no errors occur if the `feedback_queue` box was previously used by the other service.

---

## Scope Boundaries

**IN SCOPE:**
- Isolating the Hive box for `FeedbackService`.
- Improving logging for successful submissions.

**OUT OF SCOPE:**
- Refactoring the entire feedback system into a single service (should be a separate architectural task).
- Changing the `FeedbackSheet` UI.

---

## Metadata

- **Investigated by**: Claude
- **Timestamp**: 2026-04-29T10:30:00Z
- **Artifact**: `/mnt/ext-fast/cosmic-match/artifacts/runs/242ed77b5a41d33c4b3f22eae32b0edb/investigation.md`
