import 'dart:async';

import 'outcome.dart';
import 'predicate.dart';
import 'retry_context.dart';

/// Metadata available when deciding whether to schedule another retry.
final class RetryAttempt<T> {
  /// Creates retry attempt metadata.
  const RetryAttempt({
    required this.outcome,
    required this.context,
    required this.retryIndex,
    required this.attemptNumber,
    required this.elapsed,
    required this.attemptDuration,
    required this.nextDelay,
  });

  /// Outcome produced by the attempt.
  final AttemptOutcome<T> outcome;

  /// Shared retry execution context.
  final RetryContext<T> context;

  /// Zero-based retry index for the retry that may be scheduled next.
  final int retryIndex;

  /// One-based operation attempt number that produced [outcome].
  final int attemptNumber;

  /// Elapsed execution time when the decision is evaluated.
  final Duration elapsed;

  /// Duration of the attempt that produced [outcome].
  final Duration attemptDuration;

  /// Delay that will be used if retrying continues.
  final Duration nextDelay;
}

final class RetryDecision {
  const RetryDecision({required this.shouldRetry, required this.handled});

  final bool shouldRetry;
  final bool handled;
}

/// Decision that determines whether another retry attempt should be scheduled.
///
/// Retry decisions receive full attempt metadata, so they can express both
/// outcome matching and retry budget rules.
abstract class RetryIf<T>
    with PredicateOperators<RetryIf<T>>
    implements BasePredicate<RetryIf<T>> {
  /// Creates a retry decision.
  const RetryIf();

  /// Returns true when another retry attempt should be scheduled.
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt);

  Future<RetryDecision> evaluate(RetryAttempt<T> attempt) async {
    final shouldRetry = await shouldRetryAttempt(attempt);
    return RetryDecision(shouldRetry: shouldRetry, handled: shouldRetry);
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
  factory RetryIf.where(FutureOr<bool> Function(RetryAttempt<T> attempt) test) {
    return _WhereRetryIf<T>(test);
  }

  /// Retries every outcome.
  factory RetryIf.any() => _AnyRetryIf<T>();

  /// Retries no outcomes.
  factory RetryIf.never() => _NeverRetryIf<T>();

  /// Allows retries while [RetryAttempt.retryIndex] is lower than [retries].
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

  @override
  RetryIf<T> or(RetryIf<T> left, RetryIf<T> right) =>
      _OrRetryIf<T>(left, right);

  @override
  RetryIf<T> and(RetryIf<T> left, RetryIf<T> right) =>
      _AndRetryIf<T>(left, right);

  @override
  RetryIf<T> not(RetryIf<T> inner) {
    return _NotRetryIf<T>(inner);
  }
}

final class _ExceptionRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) =>
      attempt.outcome is AttemptOutcomeError<T>;
}

final class _ExceptionWhereRetryIf<T> extends RetryIf<T> {
  const _ExceptionWhereRetryIf(this.test);

  final FutureOr<bool> Function(Object error, StackTrace stackTrace) test;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeError(:final error, :final stackTrace) =>
        test(error, stackTrace),
      _ => false,
    };
  }
}

final class _ResultRetryIf<T> extends RetryIf<T> {
  const _ResultRetryIf(this.test);

  final FutureOr<bool> Function(T result) test;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeResult(:final result) => test(result),
      _ => false,
    };
  }
}

final class _WhereRetryIf<T> extends RetryIf<T> {
  const _WhereRetryIf(this.test);

  final FutureOr<bool> Function(RetryAttempt<T> attempt) test;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) => test(attempt);
}

final class _AnyRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) => true;
}

final class _NeverRetryIf<T> extends RetryIf<T> {
  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) => false;
}

final class _MaxRetriesRetryIf<T> extends RetryIf<T> {
  const _MaxRetriesRetryIf(this.retries);

  final int retries;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) {
    return attempt.retryIndex < retries;
  }

  @override
  Future<RetryDecision> evaluate(RetryAttempt<T> attempt) async {
    return RetryDecision(
      shouldRetry: await shouldRetryAttempt(attempt),
      handled: false,
    );
  }
}

final class _OrRetryIf<T> extends RetryIf<T> {
  const _OrRetryIf(this.left, this.right);

  final RetryIf<T> left;
  final RetryIf<T> right;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) async {
    return await left.shouldRetryAttempt(attempt) ||
        await right.shouldRetryAttempt(attempt);
  }

  @override
  Future<RetryDecision> evaluate(RetryAttempt<T> attempt) async {
    final leftDecision = await left.evaluate(attempt);
    if (leftDecision.shouldRetry) {
      return RetryDecision(
        shouldRetry: true,
        handled: leftDecision.handled,
      );
    }
    final rightDecision = await right.evaluate(attempt);
    return RetryDecision(
      shouldRetry: rightDecision.shouldRetry,
      handled: leftDecision.handled || rightDecision.handled,
    );
  }
}

final class _AndRetryIf<T> extends RetryIf<T> {
  const _AndRetryIf(this.left, this.right);

  final RetryIf<T> left;
  final RetryIf<T> right;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) async {
    return await left.shouldRetryAttempt(attempt) &&
        await right.shouldRetryAttempt(attempt);
  }

  @override
  Future<RetryDecision> evaluate(RetryAttempt<T> attempt) async {
    final leftDecision = await left.evaluate(attempt);
    if (!leftDecision.shouldRetry) {
      return RetryDecision(
        shouldRetry: false,
        handled: leftDecision.handled,
      );
    }
    final rightDecision = await right.evaluate(attempt);
    return RetryDecision(
      shouldRetry: rightDecision.shouldRetry,
      handled: leftDecision.handled || rightDecision.handled,
    );
  }
}

final class _NotRetryIf<T> extends RetryIf<T> {
  const _NotRetryIf(this.inner);

  final RetryIf<T> inner;

  @override
  FutureOr<bool> shouldRetryAttempt(RetryAttempt<T> attempt) async {
    return !await inner.shouldRetryAttempt(attempt);
  }

  @override
  Future<RetryDecision> evaluate(RetryAttempt<T> attempt) async {
    final decision = await inner.evaluate(attempt);
    return RetryDecision(shouldRetry: !decision.shouldRetry, handled: false);
  }

  @override
  RetryIf<T> not(RetryIf<T> inner) => this.inner;
}
