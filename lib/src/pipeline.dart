import 'dart:async';

import 'package:clock/clock.dart';

import 'cancellation.dart';
import 'outcome.dart';
import 'retry_pipeline_context.dart';
import 'retry_future.dart';
import 'telemetry.dart';

/// Strategy base class for wrapping pipeline execution.
///
/// Callers can extend this class to add custom ordered behavior to a
/// [RetryPipeline].
abstract class RetryPipelineStrategy<T> {
  /// Creates a pipeline strategy.
  const RetryPipelineStrategy({this.name});

  /// Optional strategy instance name used in telemetry source.
  final String? name;

  /// Executes this strategy around [next].
  Future<T> execute(RetryPipelineContext<T> context, Future<T> Function() next);
}

/// Lower-level engine that applies ordered strategies to an operation.
final class RetryPipeline<T> {
  /// Creates a retry pipeline.
  RetryPipeline({
    List<RetryPipelineStrategy<T>> strategies = const [],
    this.telemetry = const TelemetryOptions(),
    this.pipelineKey,
  }) : strategies = List<RetryPipelineStrategy<T>>.unmodifiable(strategies);

  /// Ordered strategies wrapping the operation.
  final List<RetryPipelineStrategy<T>> strategies;

  /// Telemetry options.
  final TelemetryOptions telemetry;

  /// Optional stable pipeline key used in telemetry source.
  final String? pipelineKey;

  /// Executes [operation] through the pipeline.
  RetryFuture<T> execute(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
    String? operationKey,
  }) {
    final startedAt = clock.now();
    final context = RetryPipelineContext<T>.execution(
      startedAt: startedAt,
      cancellationToken: cancellationToken ?? CancellationToken(),
      telemetry: TelemetrySink(
        options: telemetry,
        source: TelemetrySource(
          pipelineKey: pipelineKey,
          operationKey: operationKey,
        ),
        startedAt: startedAt,
        now: clock.now,
      ),
    );
    final completer = Completer<T>();

    scheduleMicrotask(() {
      _run(operation, context, completer);
    });

    return _PipelineRetryFuture<T>(context, completer.future);
  }

  Future<void> _run(
    FutureOr<T> Function() operation,
    RetryPipelineContext<T> context,
    Completer<T> completer,
  ) async {
    await context.telemetry?.emit<T>(type: TelemetryEventType.pipelineStarted);

    Future<T> invokeOperation() async {
      context.setPhase(RetryPhase.attempting);
      context.throwIfCancelled();
      return Future<T>.sync(operation);
    }

    var next = invokeOperation;
    for (final strategy in strategies.reversed) {
      final inner = next;
      next = () => strategy.execute(context, inner);
    }

    try {
      final result = await next();
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.pipelineSucceeded,
        outcome: StrategyOutcome<T>.result(result, context: context),
        duration: context.elapsed,
      );
      context.setPhase(RetryPhase.completed);
      completer.complete(result);
    } catch (error, stackTrace) {
      final cancelled = isCancellationError(error, context.cancelToken);
      await context.telemetry?.emit<T>(
        type: cancelled
            ? TelemetryEventType.pipelineCancelled
            : TelemetryEventType.pipelineFailed,
        outcome: StrategyOutcome<T>.error(error, stackTrace, context: context),
        error: error,
        stackTrace: stackTrace,
        duration: context.elapsed,
      );
      context.setPhase(cancelled ? RetryPhase.cancelled : RetryPhase.failed);
      completer.completeError(error, stackTrace);
    }
  }
}

final class _PipelineRetryFuture<T> implements RetryFuture<T> {
  _PipelineRetryFuture(this._context, this._future);

  final RetryPipelineContext<T> _context;
  final Future<T> _future;

  @override
  CancellationToken get cancelToken => _context.cancelToken;

  @override
  RetryPhase get phase => _context.phase;

  @override
  void cancel([Object? reason]) {
    _context.cancelToken.cancel(reason);
  }

  @override
  Stream<T> asStream() => _future.asStream();

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return _future.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _future.whenComplete(action);
  }
}
