import 'outcome.dart';
export 'pipeline_event.dart';
import 'retry_predicate.dart';
import 'retry_context.dart';

/// Type of retry lifecycle event.
enum RetryEventType {
  /// Another attempt will be scheduled.
  retry,

  /// No more attempts will be scheduled.
  giveUp,
}

/// Lifecycle metadata emitted by retry hooks.
final class RetryEvent<T> {
  const RetryEvent._(this.type, this.attempt);

  /// Creates a retry event.
  const RetryEvent.retry(RetryAttempt<T> attempt)
      : this._(RetryEventType.retry, attempt);

  /// Creates a give-up event.
  const RetryEvent.giveUp(RetryAttempt<T> attempt)
      : this._(RetryEventType.giveUp, attempt);

  /// Event kind.
  final RetryEventType type;

  /// Full retry attempt metadata for this event.
  final RetryAttempt<T> attempt;

  /// Full retry context for this event.
  RetryContext<T> get context => attempt.context;

  /// Zero-based retry index.
  int get retryIndex => attempt.retryIndex;

  /// One-based attempt number.
  int get attemptNumber => attempt.attemptNumber;

  /// Elapsed time since execution started.
  Duration get elapsed => attempt.elapsed;

  /// Duration of the attempt that produced this event.
  Duration get attemptDuration => attempt.attemptDuration;

  /// Outcome from the attempt that produced this event.
  AttemptOutcome<T> get outcome => attempt.outcome;

  /// Delay planned before the next attempt.
  Duration get nextDelay => attempt.nextDelay;
}
