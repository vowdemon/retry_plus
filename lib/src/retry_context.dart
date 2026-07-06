import 'outcome.dart';

/// Metadata for a retry attempt.
final class RetryContext<T> {
  /// Creates retry attempt metadata.
  const RetryContext({
    required this.attemptNumber,
    required this.elapsed,
    required this.outcome,
    this.nextDelay = Duration.zero,
  });

  /// One-based attempt number.
  final int attemptNumber;

  /// Elapsed time since the policy started execution.
  final Duration elapsed;

  /// Outcome of the latest attempt.
  final AttemptOutcome<T> outcome;

  /// Delay planned before the next attempt.
  final Duration nextDelay;

  /// Returns a copy with updated fields.
  RetryContext<T> copyWith({Duration? nextDelay}) {
    return RetryContext<T>(
      attemptNumber: attemptNumber,
      elapsed: elapsed,
      outcome: outcome,
      nextDelay: nextDelay ?? this.nextDelay,
    );
  }
}
