import 'dart:async';

import 'cancellation.dart';
import 'events.dart';
import 'retry_future.dart';
import 'runtime.dart';

/// Strategy interface for wrapping pipeline execution.
///
/// Callers can implement this interface to add custom ordered behavior to a
/// [RetryPipeline].
abstract interface class PipelineStrategy<T> {
  /// Executes this strategy around [next].
  Future<T> execute(PipelineContext<T> context, Future<T> Function() next);
}

/// Shared context passed through pipeline strategies.
final class PipelineContext<T> {
  /// Creates pipeline context.
  PipelineContext({
    required this.runtime,
    required this.startedAt,
    required this.cancellationToken,
  });

  /// Runtime dependencies for this execution.
  final RetryRuntime runtime;

  /// Cancellation token for this execution.
  final CancellationToken cancellationToken;

  /// Time at which execution started.
  final DateTime startedAt;

  /// Current attempt number.
  var attemptNumber = 0;

  var _phase = RetryPhase.pending;

  /// Current retry execution phase.
  RetryPhase get phase => _phase;

  /// Emits a pipeline event.
  void emit(PipelineEvent event) {
    runtime.emit(event);
  }

  /// Updates the phase exposed by the returned retry future.
  void setPhase(RetryPhase phase) {
    _phase = phase;
  }

  /// Elapsed time since execution started.
  Duration get elapsed => runtime.clock().difference(startedAt);
}

/// Lower-level engine that applies ordered strategies to an operation.
final class RetryPipeline<T> {
  /// Creates a retry pipeline.
  RetryPipeline({
    List<PipelineStrategy<T>> strategies = const [],
    RetryRuntime? runtime,
  })  : strategies = List<PipelineStrategy<T>>.unmodifiable(strategies),
        runtime = runtime ?? RetryRuntime();

  /// Ordered strategies wrapping the operation.
  final List<PipelineStrategy<T>> strategies;

  /// Runtime dependencies used by the pipeline.
  final RetryRuntime runtime;

  /// Executes [operation] through the pipeline.
  RetryFuture<T> execute(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
  }) {
    final context = PipelineContext<T>(
      runtime: runtime,
      startedAt: runtime.clock(),
      cancellationToken: cancellationToken ?? CancellationToken(),
    );
    final completer = Completer<T>();

    scheduleMicrotask(() {
      _run(operation, context, completer);
    });

    return _PipelineRetryFuture<T>(context, completer.future);
  }

  Future<void> _run(
    FutureOr<T> Function() operation,
    PipelineContext<T> context,
    Completer<T> completer,
  ) async {
    context.emit(const PipelineEvent(type: PipelineEventType.started));

    Future<T> invokeOperation() async {
      context.setPhase(RetryPhase.attempting);
      context.cancellationToken.throwIfCancelled();
      return Future<T>.sync(operation);
    }

    var next = invokeOperation;
    for (final strategy in strategies.reversed) {
      final inner = next;
      next = () => strategy.execute(context, inner);
    }

    try {
      final result = await next();
      context.emit(const PipelineEvent(type: PipelineEventType.completed));
      context.setPhase(RetryPhase.completed);
      completer.complete(result);
    } catch (error, stackTrace) {
      final cancelled = isCancellationError(error, context.cancellationToken);
      context.emit(
        PipelineEvent(
          type: cancelled
              ? PipelineEventType.cancelled
              : PipelineEventType.failed,
          error: error,
        ),
      );
      context.setPhase(cancelled ? RetryPhase.cancelled : RetryPhase.failed);
      completer.completeError(error, stackTrace);
    }
  }
}

final class _PipelineRetryFuture<T> implements RetryFuture<T> {
  _PipelineRetryFuture(this._context, this._future);

  final PipelineContext<T> _context;
  final Future<T> _future;

  @override
  CancellationToken get cancelToken => _context.cancellationToken;

  @override
  RetryPhase get phase => _context.phase;

  @override
  void cancel([Object? reason]) {
    _context.cancellationToken.cancel(reason);
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
