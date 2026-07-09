import 'dart:async';

import 'outcome.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';

/// Metadata available when deciding whether to schedule another retry.
final class RetryAttemptContext<T> {
  /// Creates retry attempt metadata.
  const RetryAttemptContext({
    required this.outcome,
    required this.pipelineContext,
    required this.retryIndex,
    required this.attemptNumber,
    required this.elapsed,
    required this.attemptDuration,
  });

  /// Outcome produced by the attempt.
  final AttemptOutcome<T> outcome;

  /// Shared pipeline execution context.
  final RetryPipelineContext<T> pipelineContext;

  /// Zero-based retry index for the retry that may be scheduled next.
  final int retryIndex;

  /// One-based operation attempt number that produced [outcome].
  final int attemptNumber;

  /// Elapsed execution time when the decision is evaluated.
  final Duration elapsed;

  /// Duration of the attempt that produced [outcome].
  final Duration attemptDuration;

  /// Shared strategy outcome view for this retry attempt.
  StrategyOutcome<T> get strategyOutcome {
    final metadata = <String, Object?>{
      'retryIndex': retryIndex,
      'attemptNumber': attemptNumber,
      'attemptDuration': attemptDuration,
    };
    return switch (outcome) {
      AttemptOutcomeResult(:final result) => StrategyOutcome<T>.result(
          result,
          context: pipelineContext,
          elapsed: elapsed,
          metadata: metadata,
        ),
      AttemptOutcomeError(:final error, :final stackTrace) =>
        StrategyOutcome<T>.error(
          error,
          stackTrace,
          context: pipelineContext,
          elapsed: elapsed,
          metadata: metadata,
        ),
    };
  }
}

/// Decision that determines whether another retry attempt should be scheduled.
///
/// Retry decisions receive full attempt metadata, so they can express both
/// outcome matching and retry budget rules.
abstract class RetryIf<T>
    extends ContextPredicate<RetryAttemptContext<T>, RetryIf<T>> {
  /// Creates a retry decision.
  const RetryIf();

  /// Returns true when another retry attempt should be scheduled.
  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt);

  @override
  RetryIf<T> build(
      FutureOr<bool> Function(RetryAttemptContext<T> context) shouldHandle) {
    return _WhereRetryIf<T>(shouldHandle);
  }

  /// Retries any exception outcome.
  factory RetryIf.exception() => _ExceptionRetryIf<T>();

  /// Retries exception outcomes matching [test].
  factory RetryIf.exceptionWhere(
    FutureOr<bool> Function(Object error, StackTrace stackTrace) test,
  ) {
    return _ExceptionWhereRetryIf<T>(test);
  }

  /// Retries result outcomes matching [test].
  factory RetryIf.result(FutureOr<bool> Function(T result) test) {
    return _ResultRetryIf<T>(test);
  }

  /// Retries attempts matching [test].
  factory RetryIf.where(
      FutureOr<bool> Function(RetryAttemptContext<T> attempt) test) {
    return _WhereRetryIf<T>(test);
  }

  /// Retries every outcome.
  factory RetryIf.any() => _AnyRetryIf<T>();

  /// Retries no outcomes.
  factory RetryIf.never() => _NeverRetryIf<T>();

  /// Allows retries while [RetryAttemptContext.retryIndex] is lower than [retries].
  factory RetryIf.maxRetries(int retries) {
    if (retries < 0) {
      throw ArgumentError.value(retries, 'retries', 'must not be negative');
    }
    return _MaxRetriesRetryIf<T>(retries);
  }

  /// Retries exception outcomes of type [E].
  static RetryIf<T> exceptionType<E extends Object, T>() {
    return _ExceptionWhereRetryIf<T>((error, _) => error is E);
  }
}

final class _ExceptionRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) =>
      attempt.outcome is AttemptOutcomeError<T>;
}

final class _ExceptionWhereRetryIf<T> extends RetryIf<T> {
  const _ExceptionWhereRetryIf(this._callback);

  final FutureOr<bool> Function(Object error, StackTrace stackTrace) _callback;

  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeError(:final error, :final stackTrace) =>
        _callback(error, stackTrace),
      _ => false,
    };
  }
}

final class _ResultRetryIf<T> extends RetryIf<T> {
  const _ResultRetryIf(this._callback);

  final FutureOr<bool> Function(T result) _callback;

  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeResult(:final result) => _callback(result),
      _ => false,
    };
  }
}

final class _WhereRetryIf<T> extends RetryIf<T> {
  const _WhereRetryIf(this._callback);

  final FutureOr<bool> Function(RetryAttemptContext<T> attempt) _callback;

  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) {
    return _callback(attempt);
  }
}

final class _AnyRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) => true;
}

final class _NeverRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) => false;
}

final class _MaxRetriesRetryIf<T> extends RetryIf<T> {
  const _MaxRetriesRetryIf(this.retries);

  final int retries;

  @override
  FutureOr<bool> shouldHandle(RetryAttemptContext<T> attempt) {
    return attempt.retryIndex < retries;
  }
}
