import 'dart:async';

import 'cancellation.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Context passed to fallback callbacks.
final class FallbackContext<T> implements OutcomeContext<T> {
  /// Creates fallback context.
  const FallbackContext({
    required this.outcome,
    required this.elapsed,
    required this.pipelineContext,
  });

  /// Final outcome being handled.
  @override
  final StrategyOutcome<T> outcome;

  /// Final failure being handled, or `null` for a result outcome.
  Object? get failure => OutcomeContextAccess<T>(this).error;

  /// Stack trace captured with [failure], or `null` for a result outcome.
  StackTrace? get stackTrace => OutcomeContextAccess<T>(this).stackTrace;

  /// Elapsed pipeline time.
  @override
  final Duration elapsed;

  /// Pipeline context.
  @override
  final RetryPipelineContext<T> pipelineContext;
}

/// Predicate that decides whether fallback handles a final failure.
///
/// Callers can extend this class or use [FallbackPredicate.where] to provide
/// domain-specific fallback decisions.
abstract class FallbackPredicate<T>
    extends ContextPredicate<FallbackContext<T>, FallbackPredicate<T>> {
  /// Creates a fallback predicate.
  const FallbackPredicate();

  /// Returns true when fallback should handle [context].
  @override
  FutureOr<bool> shouldHandle(FallbackContext<T> context);

  @override
  FallbackPredicate<T> build(
    FutureOr<bool> Function(FallbackContext<T> context) shouldHandle,
  ) {
    return _FallbackWherePredicate<T>(shouldHandle);
  }

  /// Handles every non-cancellation final outcome.
  ///
  /// [FallbackStrategy] bypasses cancellation before evaluating predicates.
  factory FallbackPredicate.any() {
    return _FallbackWherePredicate<T>((context) => !context.isCancellation);
  }

  /// Handles non-cancellation final exceptions.
  factory FallbackPredicate.exception() {
    return _FallbackWherePredicate<T>(
      (context) =>
          context.outcome is StrategyOutcomeError<T> && !context.isCancellation,
    );
  }

  /// Handles non-cancellation final exceptions matching [test].
  factory FallbackPredicate.exceptionWhere(
    FutureOr<bool> Function(Object error, StackTrace stackTrace) test,
  ) {
    return _FallbackWherePredicate<T>(
      (context) => switch (context.outcome) {
        StrategyOutcomeError(:final error, :final stackTrace)
            when !context.isCancellation =>
          test(error, stackTrace),
        _ => false,
      },
    );
  }

  /// Handles final failures matching [test].
  factory FallbackPredicate.where(
    FutureOr<bool> Function(FallbackContext<T>) test,
  ) {
    return _FallbackWherePredicate<T>(test);
  }

  /// Handles result outcomes matching [test].
  factory FallbackPredicate.result(FutureOr<bool> Function(T result) test) {
    return _FallbackWherePredicate<T>(
      (context) => switch (context.outcome) {
        StrategyOutcomeResult(:final result) => test(result),
        _ => false,
      },
    );
  }

  /// Handles final exceptions of type [E].
  static FallbackPredicate<T> exceptionType<E extends Object, T>() {
    return FallbackPredicate<T>.exceptionWhere((error, _) => error is E);
  }
}

/// Strategy that converts final pipeline failures into results.
///
/// Cancellation always bypasses fallback handling, even when [fallbackIf] is
/// [FallbackPredicate.any].
final class FallbackStrategy<T> extends RetryPipelineStrategy<T> {
  const FallbackStrategy._({
    required this.fallback,
    required this.fallbackIf,
    super.name,
    this.onFallback,
  });

  /// Creates fallback with a static [value].
  factory FallbackStrategy.value(
    T value, {
    String? name,
    FallbackPredicate<T>? fallbackIf,
    FutureOr<void> Function(FallbackContext<T> context)? onFallback,
  }) {
    return FallbackStrategy<T>._(
      fallback: (_) => value,
      fallbackIf: fallbackIf ?? FallbackPredicate<T>.exception(),
      name: name,
      onFallback: onFallback,
    );
  }

  /// Creates fallback with a [callback].
  factory FallbackStrategy.callback(
    FutureOr<T> Function(FallbackContext<T> context) callback, {
    String? name,
    FallbackPredicate<T>? fallbackIf,
    FutureOr<void> Function(FallbackContext<T> context)? onFallback,
  }) {
    return FallbackStrategy<T>._(
      fallback: callback,
      fallbackIf: fallbackIf ?? FallbackPredicate<T>.exception(),
      name: name,
      onFallback: onFallback,
    );
  }

  /// Computes fallback result.
  final FutureOr<T> Function(FallbackContext<T> context) fallback;

  /// Decides whether fallback applies.
  final FallbackPredicate<T> fallbackIf;

  /// Called before fallback produces a result.
  final FutureOr<void> Function(FallbackContext<T> context)? onFallback;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    try {
      final result = await next();
      final fallbackContext = FallbackContext<T>(
        outcome: StrategyOutcome<T>.result(result, context: context),
        elapsed: context.elapsed,
        pipelineContext: context,
      );
      if (!await fallbackIf.shouldHandle(fallbackContext)) {
        return result;
      }
      return _handleFallback(fallbackContext);
    } on RetryCancelledException {
      rethrow;
    } catch (error, stackTrace) {
      if (isCancellationError(error, context.cancelToken)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final fallbackContext = FallbackContext<T>(
        outcome: StrategyOutcome<T>.error(
          error,
          stackTrace,
          context: context,
        ),
        elapsed: context.elapsed,
        pipelineContext: context,
      );
      if (!await fallbackIf.shouldHandle(fallbackContext)) {
        rethrow;
      }
      return _handleFallback(fallbackContext);
    }
  }

  Future<T> _handleFallback(FallbackContext<T> context) async {
    await context.pipelineContext.telemetry?.emit<T>(
      type: TelemetryEventType.fallbackHandling,
      outcome: context.outcome,
      strategyName: name,
      error: _outcomeError(context.outcome),
      stackTrace: _outcomeStackTrace(context.outcome),
    );
    await onFallback?.call(context);
    try {
      final result = await fallback(context);
      await context.pipelineContext.telemetry?.emit<T>(
        type: TelemetryEventType.fallbackApplied,
        outcome: context.outcome,
        strategyName: name,
        error: _outcomeError(context.outcome),
        stackTrace: _outcomeStackTrace(context.outcome),
      );
      return result;
    } catch (error, stackTrace) {
      await context.pipelineContext.telemetry?.emit<T>(
        type: TelemetryEventType.fallbackFailed,
        outcome: context.outcome,
        strategyName: name,
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

Object? _outcomeError<T>(StrategyOutcome<T> outcome) {
  return switch (outcome) {
    StrategyOutcomeError(:final error) => error,
    _ => null,
  };
}

StackTrace? _outcomeStackTrace<T>(StrategyOutcome<T> outcome) {
  return switch (outcome) {
    StrategyOutcomeError(:final stackTrace) => stackTrace,
    _ => null,
  };
}

final class _FallbackWherePredicate<T> extends FallbackPredicate<T> {
  const _FallbackWherePredicate(this._callback);

  final FutureOr<bool> Function(FallbackContext<T>) _callback;

  @override
  FutureOr<bool> shouldHandle(FallbackContext<T> context) => _callback(context);
}
