import 'retry_context.dart';
import 'timeout_strategy.dart';

/// Thrown when retrying stopped after retryable results were exhausted.
final class RetryExhaustedException<T> implements Exception {
  /// Creates a retry exhausted exception.
  const RetryExhaustedException({
    required this.lastResult,
    required this.attempts,
    required this.elapsed,
    required this.context,
  });

  /// Last retryable result returned by the operation.
  final T lastResult;

  /// Number of attempts performed.
  final int attempts;

  /// Elapsed time when retrying stopped.
  final Duration elapsed;

  /// Final retry context.
  final RetryContext<T> context;

  @override
  String toString() {
    return 'RetryExhaustedException: exhausted after $attempts attempts';
  }
}

/// Thrown when a timeout strategy expires.
final class RetryTimeoutException implements Exception {
  /// Creates a retry timeout exception.
  const RetryTimeoutException(this.scope, [this.message]);

  /// Timeout scope that expired.
  final TimeoutScope scope;

  /// Optional timeout message.
  final String? message;

  @override
  String toString() {
    final label = scope == TimeoutScope.perAttempt ? 'per-attempt' : 'overall';
    return 'RetryTimeoutException: $label timeout${message == null ? '' : ' ($message)'}';
  }
}

/// Thrown when a circuit breaker rejects execution.
final class CircuitOpenException implements Exception {
  /// Creates a circuit-open exception.
  const CircuitOpenException([this.message = 'Circuit breaker is open']);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'CircuitOpenException: $message';
}
