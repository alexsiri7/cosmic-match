# Error Handling Findings: PR #132

**Reviewer**: error-handling-agent
**Date**: 2026-04-29T10:30:00Z
**Error Handlers Reviewed**: 7

---

## Summary

The PR introduces a new `FeedbackService` for worker-based feedback submission. While it includes extensive `try-catch` blocks and logging, it fails to adhere to the project's **CRC32 Persistence Contract** for Hive models. Additionally, several brittle error handling patterns in both Dart and Python code could lead to duplicate data submission or masked API failures.

**Verdict**: REQUEST_CHANGES

---

## Findings

### Finding 1: CRC32 Persistence Contract Violation

**Severity**: CRITICAL
**Category**: data-integrity
**Location**: `lib/models/pending_feedback.dart:25`

**Issue**:
The `PendingFeedback` model is stored in a Hive box but does not implement the mandatory CRC32 integrity check defined in `CLAUDE.md`. This makes the local feedback queue vulnerable to silent corruption or tampering.

**Evidence**:
```dart
// lib/models/pending_feedback.dart
Map<String, dynamic> toMap() {
  return {
    'id': id,
    'type': type,
    'message': message,
    'screenshotB64': screenshotB64,
    'appVersion': appVersion,
    'os': os,
    'device': device,
    'createdAt': createdAt.toIso8601String(),
  };
}
```

**Hidden Errors**:
This missing control could silently hide:
- Disk corruption affecting stored feedback items.
- Manual tampering with the Hive box.
- Schema mismatch errors when reading back malformed maps.

**User Impact**:
Users might lose feedback items without knowing, or the app might crash/behave unexpectedly if `PendingFeedback.fromMap` attempts to parse corrupted data (e.g., invalid `createdAt` string).

---

#### Fix Suggestions

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| A | Implement CRC32 in `toMap` and `_isValid` check in `FeedbackService` | Follows codebase standard exactly; high reliability. | Requires `archive` dependency and extra logic. |
| B | Use `FeedbackItem` instead of `PendingFeedback` | Reuses existing compliant model. | `FeedbackItem` fields might not perfectly match Worker requirements. |

**Recommended**: Option A

**Reasoning**:
Aligns with SEC-008 and the established patterns in `LevelProgress` and `FeedbackItem`.

**Recommended Fix**:
```dart
// lib/models/pending_feedback.dart
Map<String, dynamic> toMap() {
  final data = <String, dynamic>{
    'id': id,
    // ... other fields ...
  };
  data['crc'] = getCrc32(canonicalize(data).codeUnits);
  return data;
}

static String canonicalize(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  return keys.map((k) => '$k:${data[k]}').join(',');
}
```

**Codebase Pattern Reference**:
```dart
// SOURCE: lib/models/feedback_item.dart:43-45
data['crc'] = getCrc32(canonicalize(data).codeUnits);
return data;
```

---

### Finding 2: Post-Success Exception causing Duplicate Enqueue

**Severity**: HIGH
**Category**: silent-failure
**Location**: `lib/services/feedback_service.dart:128-142`

**Issue**:
If the worker returns `201 Created` but the body is not valid JSON or lacks the `url` key, `jsonDecode` or the map access will throw. This exception is caught by the broad `catch (e, stack)` on line 141, which returns `false` (triggering a local enqueue).

**Evidence**:
```dart
// lib/services/feedback_service.dart
if (response.statusCode == 201) {
  final respBody = jsonDecode(response.body); // RISKY: Might throw
  gameLogger.i('FeedbackService: posted successfully. Issue: ${respBody['url']}'); // RISKY: Key might be missing
  return true;
}
// ...
} catch (e, stack) {
  gameLogger.w('FeedbackService: POST failed — queuing', error: e, stackTrace: stack);
  return false; // ERROR: Post actually succeeded, but we queue it again!
}
```

**Hidden Errors**:
- `FormatException`: Invalid JSON from worker.
- `TypeError`: `respBody` is not a Map.
- `NullThrownError`/`TypeError`: `url` key is missing or not a string.

**User Impact**:
The feedback is successfully created on GitHub/Worker, but the app thinks it failed and queues it locally. When the queue flushes, a **duplicate** issue will be created.

---

#### Fix Suggestions

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| A | Wrap `respBody` logic in a nested try-catch or null-check | Prevents success-path errors from triggering failure logic. | Slightly more verbose. |
| B | Return `true` before logging details | Guaranteed no duplicates if HTTP 201 received. | Lose logging info if it fails. |

**Recommended**: Option A

**Recommended Fix**:
```dart
if (response.statusCode == 201) {
  try {
    final respBody = jsonDecode(response.body);
    gameLogger.i('FeedbackService: posted successfully. Issue: ${respBody?['url']}');
  } catch (e) {
    gameLogger.i('FeedbackService: posted successfully (could not parse response metadata)');
  }
  return true;
}
```

---

### Finding 3: Broad Retries for Permanent Failures (Non-400 4xx)

**Severity**: MEDIUM
**Category**: poor-user-feedback
**Location**: `lib/services/feedback_service.dart:134-140`

**Issue**:
The service only drops items for `400 Bad Request`. Other 4xx status codes like `403 Forbidden` (Auth failure) or `404 Not Found` (Wrong URL) are treated as temporary network errors and retried.

**Evidence**:
```dart
if (response.statusCode == 400) {
  gameLogger.w('FeedbackService: worker returned 400 — dropping item');
  return true;
}

gameLogger.w('FeedbackService: worker returned ${response.statusCode} — will retry');
return false;
```

**Hidden Errors**:
- Authentication failures (401/403).
- Misconfigured endpoints (404/405).

**User Impact**:
Permanent configuration errors will lead to the feedback queue being stuck, retrying forever on every connectivity change, wasting battery and data.

---

### Finding 4: Insecure Image Deletion in Upload Script

**Severity**: MEDIUM
**Category**: unsafe-fallback
**Location**: `store-listing/upload_listing.py:54-55`

**Issue**:
A broad `except Exception` in the image cleanup loop assumes any error means "no images to clear." This masks actual API or authentication failures.

**Evidence**:
```python
# store-listing/upload_listing.py
try:
    svc.edits().images().deleteall(...).execute()
except Exception as e:
    print(f"No existing {img_type} ({e})")
```

**Hidden Errors**:
- `googleapiclient.errors.HttpError`: 403 Forbidden (Auth), 404 Package Not Found, 429 Rate Limit.
- Network connectivity issues.

**User Impact**:
If the developer's credentials expire or permissions are revoked, the script will print "No existing phoneScreenshots" and then proceed to fail later (or worse, partially succeed if only some methods are restricted), leading to a confusing debug experience.

---

## Error Handler Audit

| Location | Type | Logging | User Feedback | Specificity | Verdict |
|----------|------|---------|---------------|-------------|---------|
| `feedback_service.dart:81` | try-catch | GOOD | NONE | BROAD | PASS |
| `feedback_service.dart:106` | try-catch | GOOD | NONE | BROAD | FAIL (Finding 2) |
| `feedback_service.dart:148` | try-catch | GOOD | NONE | SPECIFIC | PASS |
| `upload_listing.py:49` | try-except| OK | NONE | TOO BROAD | FAIL (Finding 4) |

---

## Statistics

| Severity | Count | Auto-fixable |
|----------|-------|--------------|
| CRITICAL | 1 | Yes |
| HIGH | 1 | Yes |
| MEDIUM | 2 | Yes |
| LOW | 0 | - |

---

## Silent Failure Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Duplicate Feedback Issues | HIGH | Developer noise, redundant issues | Fix Finding 2 (Return true on 201) |
| Infinite Retry Loop | MEDIUM | Battery/Data drain | Fix Finding 3 (Handle 4xx specifically) |
| Data Corruption | LOW | Lost feedback data | Fix Finding 1 (Implement CRC32) |

---

## Patterns Referenced

| File | Lines | Pattern |
|------|-------|---------|
| `lib/models/feedback_item.dart` | 43 | `data['crc'] = getCrc32(canonicalize(data).codeUnits);` |
| `lib/services/progress_service.dart` | 52-57 | `_isValid` check before loading Hive data |

---

## Positive Observations
- Connectivity listener is properly disposed in `FeedbackService`.
- `flushQueue` uses a concurrency gate (`_flushing`) to prevent overlapping attempts.
- Hive models are correctly mapped using `fromMap` even when broad catches are used.

---

## Metadata

- **Agent**: error-handling-agent
- **Timestamp**: 2026-04-29T10:30:00Z
- **Artifact**: `/mnt/ext-fast/cosmic-match/artifacts/runs/242ed77b5a41d33c4b3f22eae32b0edb/review/error-handling-findings.md`
