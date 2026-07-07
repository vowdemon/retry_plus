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
    this.error,
    this.metadata = const <String, Object?>{},
  });

  /// Event kind.
  final PipelineEventType type;

  /// Optional error associated with this event.
  final Object? error;

  /// Extra event metadata.
  final Map<String, Object?> metadata;
}
