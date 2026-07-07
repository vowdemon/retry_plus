import 'outcome.dart';
import 'predicate.dart';

/// Predicate that decides whether an attempt outcome should be retried.
///
/// Callers can extend this class or use callback factories such as
/// [RetryPredicate.where] to provide domain-specific retry decisions.
abstract class RetryPredicate<T>
    with PredicateOperators<RetryPredicate<T>>
    implements BasePredicate<RetryPredicate<T>> {
  /// Creates a retry predicate.
  const RetryPredicate();

  /// Returns true when [outcome] should be retried.
  bool shouldRetry(AttemptOutcome<T> outcome);

  /// Retries any exception outcome.
  factory RetryPredicate.exception() => _ExceptionRetryPredicate<T>();

  /// Retries exception outcomes matching [test].
  factory RetryPredicate.exceptionWhere(
    bool Function(Object error, StackTrace stackTrace) test,
  ) {
    return _ExceptionWhereRetryPredicate<T>(test);
  }

  /// Retries result outcomes matching [test].
  factory RetryPredicate.result(bool Function(T result) test) {
    return _ResultRetryPredicate<T>(test);
  }

  /// Retries outcomes matching [test].
  factory RetryPredicate.where(bool Function(AttemptOutcome<T> outcome) test) {
    return _WhereRetryPredicate<T>(test);
  }

  /// Retries every outcome.
  factory RetryPredicate.any() => _AnyRetryPredicate<T>();

  /// Retries no outcomes.
  factory RetryPredicate.never() => _NeverRetryPredicate<T>();

  /// Retries exception outcomes of type [E].
  static RetryPredicate<T> exceptionType<E extends Object, T>() {
    return _ExceptionWhereRetryPredicate<T>((error, _) => error is E);
  }

  @override
  RetryPredicate<T> addOr(RetryPredicate<T> left, RetryPredicate<T> right) =>
      _OrRetryPredicate<T>(left, right);

  @override
  RetryPredicate<T> addAnd(RetryPredicate<T> left, RetryPredicate<T> right) =>
      _AndRetryPredicate<T>(left, right);

  @override
  RetryPredicate<T> addNot(RetryPredicate<T> inner) {
    return _NotRetryPredicate<T>(inner);
  }
}

final class _ExceptionRetryPredicate<T> extends RetryPredicate<T> {
  @override
  bool shouldRetry(AttemptOutcome<T> outcome) =>
      outcome is AttemptOutcomeError<T>;
}

final class _ExceptionWhereRetryPredicate<T> extends RetryPredicate<T> {
  const _ExceptionWhereRetryPredicate(this.test);

  final bool Function(Object error, StackTrace stackTrace) test;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) {
    return switch (outcome) {
      AttemptOutcomeError(:final error, :final stackTrace) =>
        test(error, stackTrace),
      _ => false,
    };
  }
}

final class _ResultRetryPredicate<T> extends RetryPredicate<T> {
  const _ResultRetryPredicate(this.test);

  final bool Function(T result) test;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) {
    return switch (outcome) {
      AttemptOutcomeResult(:final result) => test(result),
      _ => false,
    };
  }
}

final class _WhereRetryPredicate<T> extends RetryPredicate<T> {
  const _WhereRetryPredicate(this.test);

  final bool Function(AttemptOutcome<T> outcome) test;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) => test(outcome);
}

final class _AnyRetryPredicate<T> extends RetryPredicate<T> {
  @override
  bool shouldRetry(AttemptOutcome<T> outcome) => true;
}

final class _NeverRetryPredicate<T> extends RetryPredicate<T> {
  @override
  bool shouldRetry(AttemptOutcome<T> outcome) => false;
}

final class _OrRetryPredicate<T> extends RetryPredicate<T> {
  const _OrRetryPredicate(this.left, this.right);

  final RetryPredicate<T> left;
  final RetryPredicate<T> right;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) {
    return left.shouldRetry(outcome) || right.shouldRetry(outcome);
  }
}

final class _AndRetryPredicate<T> extends RetryPredicate<T> {
  const _AndRetryPredicate(this.left, this.right);

  final RetryPredicate<T> left;
  final RetryPredicate<T> right;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) {
    return left.shouldRetry(outcome) && right.shouldRetry(outcome);
  }
}

final class _NotRetryPredicate<T> extends RetryPredicate<T> {
  const _NotRetryPredicate(this.inner);

  final RetryPredicate<T> inner;

  @override
  bool shouldRetry(AttemptOutcome<T> outcome) => !inner.shouldRetry(outcome);

  @override
  RetryPredicate<T> addNot(RetryPredicate<T> inner) => this.inner;
}
