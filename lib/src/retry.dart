import 'dart:async';

import 'cancellation.dart';
import 'circuit_breaker_strategy.dart';
import 'delay.dart';
import 'fallback_strategy.dart';
import 'pipeline.dart';
import 'retry_predicate.dart';
import 'retry_future.dart';
import 'retry_strategy.dart';
import 'telemetry.dart';
import 'timeout_strategy.dart';

/// Executes [operation] with one-off retry configuration.
RetryFuture<T> retry<T>(
  FutureOr<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(milliseconds: 200),
  double delayFactor = 2,
  Duration? maxDelay = const Duration(seconds: 5),
  Jitter? jitter,
  RetryIf<T>? retryIf,
  FutureOr<void> Function(RetryAttemptContext<T> attempt)? onRetry,
  FutureOr<void> Function(RetryAttemptContext<T> attempt)? onGiveUp,
  TimeoutStrategy<T>? timeout,
  FallbackStrategy<T>? fallback,
  CircuitBreaker? circuitBreaker,
  TelemetryOptions telemetry = const TelemetryOptions(),
  String? pipelineKey,
  CancellationToken? cancellationToken,
  String? operationKey,
}) {
  return Retry<T>(
    maxRetries: maxRetries,
    delay: DelayPolicy.exponential(
      initial: initialDelay,
      factor: delayFactor,
      max: maxDelay,
      jitter: jitter,
    ),
    retryIf: retryIf,
    onRetry: onRetry,
    onGiveUp: onGiveUp,
    timeout: timeout,
    fallback: fallback,
    circuitBreaker: circuitBreaker,
    telemetry: telemetry,
    pipelineKey: pipelineKey,
  ).execute(
    operation,
    cancellationToken: cancellationToken,
    operationKey: operationKey,
  );
}

/// A reusable retry facade for async and sync operations.
final class Retry<T> {
  /// Creates a retry facade.
  Retry({
    int maxRetries = 3,
    DelayPolicy? delay,
    RetryIf<T>? retryIf,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onRetry,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onGiveUp,
    this.timeout,
    this.fallback,
    this.circuitBreaker,
    this.telemetry = const TelemetryOptions(),
    this.pipelineKey,
  }) : retry = RetryStrategy<T>(
          delay: delay,
          retryIf: retryIf == null
              ? RetryIf<T>.exception() & RetryIf<T>.maxRetries(maxRetries)
              : retryIf & RetryIf<T>.maxRetries(maxRetries),
          onRetry: onRetry,
          onGiveUp: onGiveUp,
        );

  /// Retry strategy used by this facade.
  final RetryStrategy<T> retry;

  /// Optional timeout strategy.
  final TimeoutStrategy<T>? timeout;

  /// Optional fallback strategy.
  final FallbackStrategy<T>? fallback;

  /// Optional shared circuit breaker.
  final CircuitBreaker? circuitBreaker;

  /// Telemetry options.
  final TelemetryOptions telemetry;

  /// Optional stable pipeline key used in telemetry source.
  final String? pipelineKey;

  /// Executes [operation] under this retry facade.
  RetryFuture<T> call(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
    String? operationKey,
  }) {
    return execute(
      operation,
      cancellationToken: cancellationToken,
      operationKey: operationKey,
    );
  }

  /// Executes an async [operation] under this retry facade.
  RetryFuture<T> execute(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
    String? operationKey,
  }) {
    return _buildPipeline().execute(
      operation,
      cancellationToken: cancellationToken,
      operationKey: operationKey,
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
    if (timeout != null) {
      strategies.add(timeout!);
    }
    strategies.add(retry);

    return RetryPipeline<T>(
      strategies: strategies,
      telemetry: telemetry,
      pipelineKey: pipelineKey,
    );
  }
}
