import 'dart:async';

import 'package:clock/clock.dart';

import 'cancellation.dart';
import 'events.dart';
import 'retry_context.dart';
import 'retry_future.dart';

/// Strategy interface for wrapping pipeline execution.
///
/// Callers can implement this interface to add custom ordered behavior to a
/// [RetryPipeline].
abstract interface class RetryPipelineStrategy<T> {
  /// Executes this strategy around [next].
  Future<T> execute(RetryContext<T> context, Future<T> Function() next);
}

/// Lower-level engine that applies ordered strategies to an operation.
final class RetryPipeline<T> {
  /// Creates a retry pipeline.
  RetryPipeline({
    List<RetryPipelineStrategy<T>> strategies = const [],
    this.onEvent,
  }) : strategies = List<RetryPipelineStrategy<T>>.unmodifiable(strategies);

  /// Ordered strategies wrapping the operation.
  final List<RetryPipelineStrategy<T>> strategies;

  /// Optional pipeline event observer.
  final void Function(PipelineEvent event)? onEvent;

  /// Executes [operation] through the pipeline.
  RetryFuture<T> execute(
    FutureOr<T> Function() operation, {
    CancellationToken? cancellationToken,
  }) {
    final context = RetryContext<T>.execution(
      startedAt: clock.now(),
      cancellationToken: cancellationToken ?? CancellationToken(),
      onEvent: onEvent,
    );
    final completer = Completer<T>();

    scheduleMicrotask(() {
      _run(operation, context, completer);
    });

    return _PipelineRetryFuture<T>(context, completer.future);
  }

  Future<void> _run(
    FutureOr<T> Function() operation,
    RetryContext<T> context,
    Completer<T> completer,
  ) async {
    context.emit(const PipelineEvent(type: PipelineEventType.started));

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
      context.emit(const PipelineEvent(type: PipelineEventType.completed));
      context.setPhase(RetryPhase.completed);
      completer.complete(result);
    } catch (error, stackTrace) {
      final cancelled = isCancellationError(error, context.cancelToken);
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

  final RetryContext<T> _context;
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
