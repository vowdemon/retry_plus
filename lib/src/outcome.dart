import 'dart:async';

import 'cancellation.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';

/// Context that carries a strategy outcome and common execution metadata.
abstract interface class OutcomeContext<T> {
  /// Outcome observed by a strategy.
  StrategyOutcome<T> get outcome;

  /// Pipeline context active when [outcome] was observed.
  RetryPipelineContext<T> get pipelineContext;

  /// Elapsed pipeline time when [outcome] was observed.
  Duration get elapsed;
}

/// Captures the result or error from one attempt.
sealed class AttemptOutcome<T> {
  const AttemptOutcome();

  /// Creates a successful result outcome.
  const factory AttemptOutcome.result(T result) = AttemptOutcomeResult<T>;

  /// Creates an error outcome.
  const factory AttemptOutcome.error(Object error, StackTrace stackTrace) =
      AttemptOutcomeError<T>;
}

/// A successful attempt outcome.
final class AttemptOutcomeResult<T> extends AttemptOutcome<T> {
  const AttemptOutcomeResult(this.result);

  final T result;
}

/// A failed attempt outcome.
final class AttemptOutcomeError<T> extends AttemptOutcome<T> {
  const AttemptOutcomeError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// Captures a result or error observed by a pipeline strategy.
sealed class StrategyOutcome<T> {
  /// Creates a successful strategy outcome.
  factory StrategyOutcome.result(
    T result, {
    required RetryPipelineContext<T> context,
    Duration? elapsed,
    Map<String, Object?> metadata = const {},
  }) {
    return StrategyOutcomeResult<T>(
      result,
      context: context,
      elapsed: elapsed,
      metadata: metadata,
    );
  }

  /// Creates a failed strategy outcome.
  factory StrategyOutcome.error(
    Object error,
    StackTrace stackTrace, {
    required RetryPipelineContext<T> context,
    Duration? elapsed,
    Map<String, Object?> metadata = const {},
  }) {
    return StrategyOutcomeError<T>(
      error,
      stackTrace,
      context: context,
      elapsed: elapsed,
      metadata: metadata,
    );
  }

  StrategyOutcome._({
    required this.context,
    Duration? elapsed,
    this.metadata = const {},
  })  : elapsed = elapsed ?? context.elapsed,
        super();

  /// Shared pipeline execution context.
  final RetryPipelineContext<T> context;

  /// Elapsed pipeline time when this outcome was observed.
  final Duration elapsed;

  /// Strategy-specific metadata associated with this outcome.
  final Map<String, Object?> metadata;
}

/// A successful strategy outcome.
final class StrategyOutcomeResult<T> extends StrategyOutcome<T> {
  StrategyOutcomeResult(
    this.result, {
    required super.context,
    super.elapsed,
    super.metadata,
  }) : super._();

  /// Result returned by the wrapped execution.
  final T result;
}

/// A failed strategy outcome.
final class StrategyOutcomeError<T> extends StrategyOutcome<T> {
  StrategyOutcomeError(
    this.error,
    this.stackTrace, {
    required super.context,
    super.elapsed,
    super.metadata,
  }) : super._();

  /// Error thrown by the wrapped execution.
  final Object error;

  /// Stack trace captured with [error].
  final StackTrace stackTrace;
}

/// Shared helpers for reading data from outcome-aware strategy contexts.
extension OutcomeContextAccess<T> on OutcomeContext<T> {
  /// Result from a successful outcome, or `null` for an error outcome.
  T? get result {
    return switch (outcome) {
      StrategyOutcomeResult(:final result) => result,
      StrategyOutcomeError() => null,
    };
  }

  /// Error from a failed outcome, or `null` for a result outcome.
  Object? get error {
    return switch (outcome) {
      StrategyOutcomeError(:final error) => error,
      StrategyOutcomeResult() => null,
    };
  }

  /// Stack trace from a failed outcome, or `null` for a result outcome.
  StackTrace? get stackTrace {
    return switch (outcome) {
      StrategyOutcomeError(:final stackTrace) => stackTrace,
      StrategyOutcomeResult() => null,
    };
  }

  /// Whether [outcome] contains a result.
  bool get hasResult => outcome is StrategyOutcomeResult<T>;

  /// Whether [outcome] contains an error.
  bool get hasError => outcome is StrategyOutcomeError<T>;

  /// Whether [outcome] represents cooperative retry cancellation.
  bool get isCancellation => _isCancellationOutcome(outcome);
}

/// Predicate that classifies strategy outcomes.
abstract class OutcomePredicate<T>
    extends ContextPredicate<StrategyOutcome<T>, OutcomePredicate<T>> {
  /// Creates an outcome predicate.
  const OutcomePredicate();

  /// Returns true when this predicate handles [outcome].
  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome);

  @override
  OutcomePredicate<T> build(
    FutureOr<bool> Function(StrategyOutcome<T> context) shouldHandle,
  ) {
    return _OutcomeWherePredicate<T>(shouldHandle);
  }

  /// Matches non-cancellation exception outcomes.
  factory OutcomePredicate.exception() => _OutcomeExceptionPredicate<T>();

  /// Matches exception outcomes using [test].
  factory OutcomePredicate.exceptionWhere(
    FutureOr<bool> Function(Object error, StackTrace stackTrace) test,
  ) {
    return _OutcomeExceptionWherePredicate<T>(test);
  }

  /// Matches result outcomes using [test].
  factory OutcomePredicate.result(FutureOr<bool> Function(T result) test) {
    return _OutcomeResultPredicate<T>(test);
  }

  /// Matches outcomes using [test].
  factory OutcomePredicate.where(
    FutureOr<bool> Function(StrategyOutcome<T> outcome) test,
  ) {
    return _OutcomeWherePredicate<T>(test);
  }

  /// Matches every non-cancellation outcome.
  factory OutcomePredicate.any() => _OutcomeAnyPredicate<T>();

  /// Matches no outcomes.
  factory OutcomePredicate.never() => _OutcomeNeverPredicate<T>();

  /// Matches non-cancellation exception outcomes of type [E].
  static OutcomePredicate<T> exceptionType<E extends Object, T>() {
    return _OutcomeExceptionWherePredicate<T>((error, _) => error is E);
  }
}

final class _OutcomeExceptionPredicate<T> extends OutcomePredicate<T> {
  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) {
    return outcome is StrategyOutcomeError<T> &&
        !_isCancellationOutcome(outcome);
  }
}

final class _OutcomeExceptionWherePredicate<T> extends OutcomePredicate<T> {
  const _OutcomeExceptionWherePredicate(this._callback);

  final FutureOr<bool> Function(Object error, StackTrace stackTrace) _callback;

  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) {
    return switch (outcome) {
      StrategyOutcomeError(:final error, :final stackTrace)
          when !_isCancellationOutcome(outcome) =>
        _callback(error, stackTrace),
      _ => false,
    };
  }
}

final class _OutcomeResultPredicate<T> extends OutcomePredicate<T> {
  const _OutcomeResultPredicate(this._callback);

  final FutureOr<bool> Function(T result) _callback;

  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) {
    return switch (outcome) {
      StrategyOutcomeResult(:final result) => _callback(result),
      _ => false,
    };
  }
}

final class _OutcomeWherePredicate<T> extends OutcomePredicate<T> {
  const _OutcomeWherePredicate(this._callback);

  final FutureOr<bool> Function(StrategyOutcome<T> outcome) _callback;

  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) => _callback(outcome);
}

final class _OutcomeAnyPredicate<T> extends OutcomePredicate<T> {
  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) {
    return !_isCancellationOutcome(outcome);
  }
}

final class _OutcomeNeverPredicate<T> extends OutcomePredicate<T> {
  @override
  FutureOr<bool> shouldHandle(StrategyOutcome<T> outcome) => false;
}

bool _isCancellationOutcome<T>(StrategyOutcome<T> outcome) {
  return switch (outcome) {
    StrategyOutcomeError(:final error) => error is RetryCancelledException,
    _ => false,
  };
}
