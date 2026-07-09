import 'dart:async';

import 'cancellation.dart';
import 'exceptions.dart';
import 'pipeline.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Context passed to timeout hooks.
final class TimeoutContext<T> {
  /// Creates timeout context.
  const TimeoutContext({
    required this.timeout,
    required this.error,
    required this.pipelineContext,
  });

  /// Timeout duration that expired.
  final Duration timeout;

  /// Timeout error produced by this strategy.
  final RetryTimeoutException error;

  /// Shared retry execution context.
  final RetryPipelineContext<T> pipelineContext;
}

/// Strategy that limits execution time.
final class TimeoutStrategy<T> extends RetryPipelineStrategy<T> {
  TimeoutStrategy(Duration duration, {super.name, this.onTimeout})
      : duration = _checkPositiveDuration(duration, 'duration'),
        durationGenerator = null,
        _source = Object();

  TimeoutStrategy._({
    this.duration,
    this.durationGenerator,
    super.name,
    this.onTimeout,
  }) : _source = Object();

  /// Creates a position-scoped timeout with a generated duration.
  factory TimeoutStrategy.generated(
    FutureOr<Duration?> Function(RetryPipelineContext<T> context) duration, {
    String? name,
    FutureOr<void> Function(TimeoutContext<T> context)? onTimeout,
  }) {
    return TimeoutStrategy<T>._(
      durationGenerator: duration,
      name: name,
      onTimeout: onTimeout,
    );
  }

  /// Position-scoped timeout duration.
  final Duration? duration;

  /// Generates a timeout duration for one strategy execution.
  final FutureOr<Duration?> Function(RetryPipelineContext<T> context)?
      durationGenerator;

  /// Hook invoked when this timeout strategy expires.
  final FutureOr<void> Function(TimeoutContext<T> context)? onTimeout;

  final Object _source;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    final timeout = duration ?? await durationGenerator?.call(context);
    if (timeout == null) {
      return next();
    }
    _checkPositiveDuration(timeout, 'timeout');
    context.throwIfCancelled();
    try {
      return await context.timeout<T>(
        next(),
        timeout,
        strategy: name,
        source: _source,
      );
    } on RetryTimeoutException catch (error) {
      if (identical(error.source, _source)) {
        await context.telemetry?.emit<T>(
          type: TelemetryEventType.timeoutTimedOut,
          strategyName: name,
          error: error,
          attributes: <String, Object?>{'timeout': timeout},
        );
        await onTimeout?.call(
          TimeoutContext<T>(
            timeout: timeout,
            error: error,
            pipelineContext: context,
          ),
        );
      }
      rethrow;
    } on RetryCancelledException {
      rethrow;
    }
  }
}

Duration _checkPositiveDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, name, 'must be positive');
  }
  return duration;
}
