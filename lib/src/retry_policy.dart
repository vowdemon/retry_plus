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
import 'runtime.dart';
import 'stop.dart';
import 'timeout_strategy.dart';

/// A reusable retry policy facade for async and sync operations.
final class RetryPolicy<T> {
  /// Creates a retry policy.
  RetryPolicy({
    RetryStrategy<T>? retry,
    StopStrategy? stop,
    DelayStrategy? delay,
    RetryPredicate<T>? retryIf,
    void Function(RetryEvent<T> event)? onRetry,
    void Function(RetryEvent<T> event)? onGiveUp,
    this.timeout,
    this.fallback,
    this.circuitBreaker,
    RetryRuntime? runtime,
    DateTime Function()? clock,
    Future<void> Function(Duration delay, CancellationToken? cancellationToken)?
        sleeper,
    double Function()? random,
  })  : retry = retry ??
            RetryStrategy<T>(
              stop: stop,
              delay: delay,
              retryIf: retryIf,
              onRetry: onRetry,
              onGiveUp: onGiveUp,
            ),
        runtime = runtime ??
            RetryRuntime(clock: clock, sleeper: sleeper, random: random);

  /// Retry strategy used by this policy.
  final RetryStrategy<T> retry;

  /// Optional timeout strategy.
  final TimeoutStrategy<T>? timeout;

  /// Optional fallback strategy.
  final FallbackStrategy<T>? fallback;

  /// Optional circuit breaker strategy.
  final CircuitBreakerStrategy? circuitBreaker;

  /// Runtime dependencies for executions.
  final RetryRuntime runtime;

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
    final strategies = <PipelineStrategy<T>>[];

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

    return RetryPipeline<T>(strategies: strategies, runtime: runtime);
  }
}

/// Executes [operation] once with a temporary [RetryPolicy].
RetryFuture<T> retry<T>(
  FutureOr<T> Function() operation, {
  int? attempts,
  StopStrategy? stop,
  DelayStrategy? delay,
  RetryPredicate<T>? retryIf,
  void Function(RetryEvent<T> event)? onRetry,
  void Function(RetryEvent<T> event)? onGiveUp,
  TimeoutStrategy<T>? timeout,
  FallbackStrategy<T>? fallback,
  CircuitBreakerStrategy? circuitBreaker,
  CancellationToken? cancellationToken,
}) {
  return RetryPolicy<T>(
    stop:
        stop ?? (attempts == null ? null : StopStrategy.afterAttempt(attempts)),
    delay: delay,
    retryIf: retryIf,
    onRetry: onRetry,
    onGiveUp: onGiveUp,
    timeout: timeout,
    fallback: fallback,
    circuitBreaker: circuitBreaker,
  ).execute(operation, cancellationToken: cancellationToken);
}
