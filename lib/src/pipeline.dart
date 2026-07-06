import 'cancellation.dart';
import 'events.dart';
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
    this.cancellationToken,
  });

  /// Runtime dependencies for this execution.
  final RetryRuntime runtime;

  /// Cancellation token for this execution.
  final CancellationToken? cancellationToken;

  /// Time at which execution started.
  final DateTime startedAt;

  /// Current attempt number.
  var attemptNumber = 0;

  /// Emits a pipeline event.
  void emit(PipelineEvent event) {
    runtime.emit(event);
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
  }) : strategies = List<PipelineStrategy<T>>.unmodifiable(strategies),
       runtime = runtime ?? RetryRuntime();

  /// Ordered strategies wrapping the operation.
  final List<PipelineStrategy<T>> strategies;

  /// Runtime dependencies used by the pipeline.
  final RetryRuntime runtime;

  /// Executes [operation] through the pipeline.
  Future<T> execute(
    Future<T> Function() operation, {
    CancellationToken? cancellationToken,
  }) async {
    final context = PipelineContext<T>(
      runtime: runtime,
      startedAt: runtime.clock(),
      cancellationToken: cancellationToken,
    );
    context.emit(const PipelineEvent(type: PipelineEventType.started));

    Future<T> invokeOperation() async {
      cancellationToken?.throwIfCancelled();
      return operation();
    }

    var next = invokeOperation;
    for (final strategy in strategies.reversed) {
      final inner = next;
      next = () => strategy.execute(context, inner);
    }

    try {
      final result = await next();
      context.emit(const PipelineEvent(type: PipelineEventType.completed));
      return result;
    } on RetryCancelledException catch (error) {
      context.emit(
        PipelineEvent(type: PipelineEventType.cancelled, error: error),
      );
      rethrow;
    } catch (error) {
      context.emit(PipelineEvent(type: PipelineEventType.failed, error: error));
      rethrow;
    }
  }
}
