import 'outcome.dart';
export 'pipeline_event.dart';
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
  const RetryEvent._(this.type, this.context);

  /// Creates a retry event.
  const RetryEvent.retry(RetryContext<T> context)
      : this._(RetryEventType.retry, context);

  /// Creates a give-up event.
  const RetryEvent.giveUp(RetryContext<T> context)
      : this._(RetryEventType.giveUp, context);

  /// Event kind.
  final RetryEventType type;

  /// Full retry context for this event.
  final RetryContext<T> context;

  /// One-based attempt number.
  int get attemptNumber => context.attemptNumber;

  /// Elapsed time since execution started.
  Duration get elapsed => context.elapsed;

  /// Outcome from the attempt that produced this event.
  AttemptOutcome<T> get outcome => context.outcome;

  /// Delay planned before the next attempt.
  Duration get nextDelay => context.nextDelay;
}
