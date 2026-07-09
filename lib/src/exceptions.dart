/// Thrown when a timeout strategy expires.
final class RetryTimeoutException implements Exception {
  /// Creates a retry timeout exception.
  const RetryTimeoutException({
    this.message,
    this.strategy,
    this.timeout,
    this.source,
  });

  /// Optional timeout message.
  final String? message;

  /// Optional strategy name that produced this timeout.
  final String? strategy;

  /// Timeout duration that expired.
  final Duration? timeout;

  /// Internal source token for the strategy that produced this timeout.
  final Object? source;

  @override
  String toString() {
    return 'RetryTimeoutException: timeout${message == null ? '' : ' ($message)'}';
  }
}

/// Thrown when a circuit breaker rejects execution.
final class CircuitOpenException implements Exception {
  /// Creates a circuit-open exception.
  const CircuitOpenException([
    this.message = 'Circuit breaker is open',
    this.retryAfter,
  ]);

  /// Human-readable error message.
  final String message;

  /// Duration after which the circuit may allow a probe, when known.
  final Duration? retryAfter;

  @override
  String toString() => 'CircuitOpenException: $message';
}

/// Thrown when a rate limiter rejects execution.
final class RateLimitRejectedException implements Exception {
  /// Creates a rate-limit rejection exception.
  const RateLimitRejectedException({
    this.message = 'Rate limiter rejected execution',
    this.retryAfter,
  });

  /// Human-readable error message.
  final String message;

  /// Duration after which the caller may retry, when known.
  final Duration? retryAfter;

  @override
  String toString() => 'RateLimitRejectedException: $message';
}
