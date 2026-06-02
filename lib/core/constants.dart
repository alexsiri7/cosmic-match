import 'dart:typed_data';

/// 1x1 transparent PNG used as a fallback for screenshots.
final kTransparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
  0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

/// Minimum length (after trim) for a user-supplied feedback description.
/// Enforced both in the UI (`FeedbackSheet`) and the service (`FeedbackService`)
/// to keep low-signal reports out of the GitHub pipeline.
const int kMinFeedbackMessageLength = 10;

/// Maximum length (after trim) for a user-supplied feedback description (SEC-RPT-003).
/// Enforced both in the UI (`FeedbackSheet` via `TextField.maxLength`) and the
/// service (`FeedbackService`) — the UI cap prevents entry; the service guard
/// is belt-and-suspenders for any caller that bypasses the UI.
const int kMaxFeedbackMessageLength = 500;

/// Maximum size in bytes of the base64-encoded screenshot payload sent to the
/// Cloudflare Worker (SEC-RPT-003). 2 MB accommodates a typical annotated
/// screenshot with room to spare while preventing resource exhaustion.
const int kMaxScreenshotB64Bytes = 2 * 1024 * 1024; // 2 MB

/// Number of days after which feedback queue items are automatically
/// expired on app startup. Limits retention of user-generated content
/// in line with GDPR/CCPA data-minimisation principles.
const int kFeedbackQueueTtlDays = 7;

/// Minimum seconds between feedback submissions on the same device (SEC-RPT-008).
const int kFeedbackCooldownSeconds = 30;

/// Maximum feedback submissions allowed per hour per device (SEC-RPT-008).
const int kFeedbackMaxPerHour = 5;
