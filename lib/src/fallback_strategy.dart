import 'cancellation.dart';
import 'events.dart';
import 'exceptions.dart';
import 'pipeline.dart';
import 'predicate.dart';
import 'retry_context.dart';

/// Context passed to fallback callbacks.
final class FallbackContext<T> {
  /// Creates fallback context.
  const FallbackContext({
    required this.failure,
    required this.stackTrace,
    required this.elapsed,
    required this.retryContext,
  });

  /// Final failure being handled.
  final Object failure;

  /// Stack trace captured with [failure].
  final StackTrace stackTrace;

  /// Elapsed pipeline time.
  final Duration elapsed;

  /// Retry context.
  final RetryContext<T> retryContext;
}

/// Predicate that decides whether fallback handles a final failure.
///
/// Callers can extend this class or use [FallbackPredicate.where] to provide
/// domain-specific fallback decisions.
abstract class FallbackPredicate<T>
    with PredicateOperators<FallbackPredicate<T>>
    implements BasePredicate<FallbackPredicate<T>> {
  /// Creates a fallback predicate.
  const FallbackPredicate();

  /// Returns true when fallback should handle [context].
  bool shouldFallback(FallbackContext<T> context);

  /// Handles every final failure.
  ///
  /// [FallbackStrategy] bypasses cancellation before evaluating predicates.
  factory FallbackPredicate.any() => _AnyFallbackPredicate<T>();

  /// Handles final failures matching [test].
  factory FallbackPredicate.where(bool Function(FallbackContext<T>) test) {
    return _FallbackWherePredicate<T>(test);
  }

  /// Handles retry-exhausted results.
  factory FallbackPredicate.retryExhausted() {
    return _FallbackWherePredicate<T>(
      (context) => context.failure is RetryExhaustedException<T>,
    );
  }

  /// Handles final exceptions of type [E].
  static FallbackPredicate<T> exceptionType<E extends Object, T>() {
    return _FallbackWherePredicate<T>((context) => context.failure is E);
  }

  @override
  FallbackPredicate<T> addOr(
    FallbackPredicate<T> left,
    FallbackPredicate<T> right,
  ) {
    return _OrFallbackPredicate<T>(left, right);
  }

  @override
  FallbackPredicate<T> addAnd(
    FallbackPredicate<T> left,
    FallbackPredicate<T> right,
  ) {
    return _AndFallbackPredicate<T>(left, right);
  }

  @override
  FallbackPredicate<T> addNot(FallbackPredicate<T> inner) {
    return _NotFallbackPredicate<T>(inner);
  }
}

/// Strategy that converts final pipeline failures into results.
///
/// Cancellation always bypasses fallback handling, even when [fallbackIf] is
/// [FallbackPredicate.any].
final class FallbackStrategy<T> implements RetryPipelineStrategy<T> {
  const FallbackStrategy._({required this.fallback, required this.fallbackIf});

  /// Creates fallback with a static [value].
  factory FallbackStrategy.value(T value, {FallbackPredicate<T>? fallbackIf}) {
    return FallbackStrategy<T>._(
      fallback: (_) => value,
      fallbackIf: fallbackIf ?? FallbackPredicate<T>.any(),
    );
  }

  /// Creates fallback with a [callback].
  factory FallbackStrategy.callback(
    T Function(FallbackContext<T> context) callback, {
    FallbackPredicate<T>? fallbackIf,
  }) {
    return FallbackStrategy<T>._(
      fallback: callback,
      fallbackIf: fallbackIf ?? FallbackPredicate<T>.any(),
    );
  }

  /// Computes fallback result.
  final T Function(FallbackContext<T> context) fallback;

  /// Decides whether fallback applies.
  final FallbackPredicate<T> fallbackIf;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    try {
      return await next();
    } on RetryCancelledException {
      rethrow;
    } catch (error, stackTrace) {
      if (isCancellationError(error, context.cancelToken)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final fallbackContext = FallbackContext<T>(
        failure: error,
        stackTrace: stackTrace,
        elapsed: context.elapsed,
        retryContext: context,
      );
      if (!fallbackIf.shouldFallback(fallbackContext)) {
        rethrow;
      }
      final result = fallback(fallbackContext);
      context.emit(
        PipelineEvent(
          type: PipelineEventType.fallback,
          error: error,
          metadata: <String, Object?>{'elapsed': context.elapsed},
        ),
      );
      return result;
    }
  }
}

final class _AnyFallbackPredicate<T> extends FallbackPredicate<T> {
  @override
  bool shouldFallback(FallbackContext<T> context) => true;
}

final class _FallbackWherePredicate<T> extends FallbackPredicate<T> {
  const _FallbackWherePredicate(this.test);

  final bool Function(FallbackContext<T>) test;

  @override
  bool shouldFallback(FallbackContext<T> context) => test(context);
}

final class _OrFallbackPredicate<T> extends FallbackPredicate<T> {
  const _OrFallbackPredicate(this.left, this.right);

  final FallbackPredicate<T> left;
  final FallbackPredicate<T> right;

  @override
  bool shouldFallback(FallbackContext<T> context) {
    return left.shouldFallback(context) || right.shouldFallback(context);
  }
}

final class _AndFallbackPredicate<T> extends FallbackPredicate<T> {
  const _AndFallbackPredicate(this.left, this.right);

  final FallbackPredicate<T> left;
  final FallbackPredicate<T> right;

  @override
  bool shouldFallback(FallbackContext<T> context) {
    return left.shouldFallback(context) && right.shouldFallback(context);
  }
}

final class _NotFallbackPredicate<T> extends FallbackPredicate<T> {
  const _NotFallbackPredicate(this.inner);

  final FallbackPredicate<T> inner;

  @override
  bool shouldFallback(FallbackContext<T> context) {
    return !inner.shouldFallback(context);
  }

  @override
  FallbackPredicate<T> addNot(FallbackPredicate<T> inner) => this.inner;
}
