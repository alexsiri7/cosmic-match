/// What happened to a feedback submission, as reported to the player.
enum FeedbackOutcome {
  /// The worker accepted the report (201).
  sent,

  /// The POST failed in a retryable way; the report is stored for a later flush.
  queued,

  /// The rate limiter refused the submission before any POST; nothing was stored.
  rateLimited,

  /// The report was rejected or could not be stored; nothing will retry it.
  notSent,
}

/// [issueNumber] is set only for [FeedbackOutcome.sent] when the worker linked
/// an issue in `kFeedbackIssuesRepo`.
typedef FeedbackResult = ({FeedbackOutcome outcome, int? issueNumber});
