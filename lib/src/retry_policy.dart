import 'dart:async';

import 'cancellation.dart';
import 'circuit_breaker_strategy.dart';
import 'delay.dart';
import 'events.dart';
import 'fallback_strategy.dart';
import 'pipeline.dart';
import 'retry_predicate.dart';
import 'retry_future.dart';
import 'retry_strategy.dart';
import 'timeout_strategy.dart';

/// A reusable retry policy facade for async and sync operations.
final class RetryPolicy<T> {
  /// Creates a retry policy.
  RetryPolicy({
    RetryStrategy<T>? retry,
    DelayStrategy? delay,
    RetryIf<T>? retryIf,
    FutureOr<void> Function(RetryEvent<T> event)? onRetry,
    FutureOr<void> Function(RetryEvent<T> event)? onGiveUp,
    this.timeout,
    this.fallback,
    this.circuitBreaker,
    this.onEvent,
  }) : retry = retry ??
            RetryStrategy<T>(
              delay: delay,
              retryIf: retryIf,
              onRetry: onRetry,
              onGiveUp: onGiveUp,
            );

  /// Retry strategy used by this policy.
  final RetryStrategy<T> retry;

  /// Optional timeout strategy.
  final TimeoutStrategy<T>? timeout;

  /// Optional fallback strategy.
  final FallbackStrategy<T>? fallback;

  /// Optional circuit breaker strategy.
  final CircuitBreakerStrategy? circuitBreaker;

  /// Optional pipeline event observer.
  final void Function(PipelineEvent event)? onEvent;

  /// Executes an async [operation] under this policy.
  RetryFuture<T> execute(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
  }) {
    return _buildPipeline().execute(
      operation,
      cancellationToken: cancellationToken,
    );
  }

  RetryPipeline<T> _buildPipeline() {
    final strategies = <RetryPipelineStrategy<T>>[];

    if (fallback != null) {
      strategies.add(fallback!);
    }
    if (circuitBreaker != null) {
      strategies.add(circuitBreaker!.asStrategy<T>());
    }
    final overall = timeout?.overall;
    if (overall != null) {
      strategies.add(TimeoutStrategy<T>.overall(overall));
    }
    strategies.add(retry);
    final perAttempt = timeout?.perAttempt;
    if (perAttempt != null) {
      strategies.add(TimeoutStrategy<T>.perAttempt(perAttempt));
    }

    return RetryPipeline<T>(strategies: strategies, onEvent: onEvent);
  }
}

/// Executes [operation] once with a temporary [RetryPolicy].
RetryFuture<T> retry<T>(
  FutureOr<T> Function() operation, {
  DelayStrategy? delay,
  RetryIf<T>? retryIf,
  FutureOr<void> Function(RetryEvent<T> event)? onRetry,
  FutureOr<void> Function(RetryEvent<T> event)? onGiveUp,
  TimeoutStrategy<T>? timeout,
  FallbackStrategy<T>? fallback,
  CircuitBreakerStrategy? circuitBreaker,
  void Function(PipelineEvent event)? onEvent,
  CancellationToken? cancellationToken,
}) {
  return RetryPolicy<T>(
    delay: delay,
    retryIf: retryIf,
    onRetry: onRetry,
    onGiveUp: onGiveUp,
    timeout: timeout,
    fallback: fallback,
    circuitBreaker: circuitBreaker,
    onEvent: onEvent,
  ).execute(operation, cancellationToken: cancellationToken);
}
