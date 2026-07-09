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

/// A reusable retry facade for async and sync operations.
final class Retry<T> {
  /// Creates a retry facade.
  Retry({
    RetryStrategy<T>? retry,
    String? retryName,
    DelayPolicy? delay,
    RetryIf<T>? retryIf,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onRetry,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onGiveUp,
    this.timeout,
    this.fallback,
    this.circuitBreaker,
    this.telemetry = const TelemetryOptions(),
    this.pipelineKey,
  }) : retry = retry ??
            RetryStrategy<T>(
              name: retryName,
              delay: delay,
              retryIf: retryIf,
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
