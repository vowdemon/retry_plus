import 'outcome.dart';
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

/// Type of pipeline lifecycle event.
enum PipelineEventType {
  /// Pipeline execution started.
  started,

  /// Pipeline execution completed successfully.
  completed,

  /// Pipeline execution failed.
  failed,

  /// Pipeline execution was cancelled.
  cancelled,

  /// A retry will be scheduled.
  retry,

  /// Retry gave up.
  giveUp,

  /// Fallback produced a result.
  fallback,

  /// Timeout occurred.
  timeout,

  /// Circuit breaker opened.
  circuitOpened,

  /// Circuit breaker moved to half-open.
  circuitHalfOpen,

  /// Circuit breaker closed.
  circuitClosed,

  /// Circuit breaker rejected execution.
  circuitRejected,
}

/// Metadata emitted by pipeline execution and strategies.
final class PipelineEvent {
  /// Creates a pipeline event.
  const PipelineEvent({
    required this.type,
    this.message,
    this.error,
    this.metadata = const <String, Object?>{},
  });

  /// Event kind.
  final PipelineEventType type;

  /// Optional event message.
  final String? message;

  /// Optional error associated with this event.
  final Object? error;

  /// Extra event metadata.
  final Map<String, Object?> metadata;
}
