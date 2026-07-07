import 'cancellation.dart';
import 'events.dart';
import 'exceptions.dart';
import 'pipeline.dart';
import 'predicate.dart';
import 'retry_context.dart';

/// Circuit breaker state.
enum CircuitBreakerState {
  /// Calls are allowed and failures are counted.
  closed,

  /// Calls are rejected until the recovery duration elapses.
  open,

  /// Probe calls are allowed to determine whether the circuit can close.
  halfOpen,
}

/// Context used to classify circuit breaker failures.
final class CircuitFailureContext {
  /// Creates a circuit failure context.
  const CircuitFailureContext({
    required this.failure,
    required this.stackTrace,
  });

  /// Failure thrown by guarded execution.
  final Object failure;

  /// Stack trace captured with [failure].
  final StackTrace stackTrace;
}

/// Predicate that decides whether a failure counts for the circuit breaker.
///
/// Callers can extend this class or use [CircuitFailurePredicate.where] to
/// provide domain-specific circuit failure classification.
abstract class CircuitFailurePredicate
    with PredicateOperators<CircuitFailurePredicate>
    implements BasePredicate<CircuitFailurePredicate> {
  /// Creates a circuit failure predicate.
  const CircuitFailurePredicate();

  /// Returns true when [context] should count as a circuit failure.
  bool shouldRecordFailure(CircuitFailureContext context);

  /// Counts ordinary failures except cancellation.
  factory CircuitFailurePredicate.any() => _CircuitFailureWherePredicate(
        (context) => context.failure is! RetryCancelledException,
      );

  /// Counts failures matching [test].
  factory CircuitFailurePredicate.where(
    bool Function(CircuitFailureContext context) test,
  ) {
    return _CircuitFailureWherePredicate(test);
  }

  /// Counts failures of type [E].
  static CircuitFailurePredicate exceptionType<E extends Object>() {
    return _CircuitFailureWherePredicate((context) => context.failure is E);
  }

  @override
  CircuitFailurePredicate or(
    CircuitFailurePredicate left,
    CircuitFailurePredicate right,
  ) {
    return _OrCircuitFailurePredicate(left, right);
  }

  @override
  CircuitFailurePredicate and(
    CircuitFailurePredicate left,
    CircuitFailurePredicate right,
  ) {
    return _AndCircuitFailurePredicate(left, right);
  }

  @override
  CircuitFailurePredicate not(CircuitFailurePredicate inner) {
    return _NotCircuitFailurePredicate(inner);
  }
}

/// Stateful circuit breaker strategy.
///
/// Cancellation always bypasses circuit failure accounting, even when
/// [failureIf] would otherwise match the thrown value.
final class CircuitBreakerStrategy {
  /// Creates a circuit breaker strategy.
  CircuitBreakerStrategy({
    required this.failureThreshold,
    required this.recoveryDuration,
    this.halfOpenSuccessThreshold = 1,
    CircuitFailurePredicate? failureIf,
  }) : failureIf = failureIf ?? CircuitFailurePredicate.any() {
    if (failureThreshold < 1) {
      throw ArgumentError.value(
        failureThreshold,
        'failureThreshold',
        'must be at least 1',
      );
    }
    if (halfOpenSuccessThreshold < 1) {
      throw ArgumentError.value(
        halfOpenSuccessThreshold,
        'halfOpenSuccessThreshold',
        'must be at least 1',
      );
    }
    if (recoveryDuration < Duration.zero) {
      throw ArgumentError.value(
        recoveryDuration,
        'recoveryDuration',
        'must not be negative',
      );
    }
  }

  /// Failures required to open the circuit.
  final int failureThreshold;

  /// Time the circuit remains open before probing.
  final Duration recoveryDuration;

  /// Successful probes required to close the circuit.
  final int halfOpenSuccessThreshold;

  /// Predicate that decides which non-cancellation failures affect state.
  final CircuitFailurePredicate failureIf;

  var _state = CircuitBreakerState.closed;
  var _failures = 0;
  var _halfOpenSuccesses = 0;
  DateTime? _openedAt;

  /// Current breaker state.
  CircuitBreakerState get state => _state;

  /// Resets the breaker to closed state.
  void reset() {
    _state = CircuitBreakerState.closed;
    _failures = 0;
    _halfOpenSuccesses = 0;
    _openedAt = null;
  }

  /// Returns this breaker as a typed pipeline strategy.
  RetryPipelineStrategy<T> asStrategy<T>() =>
      _CircuitBreakerRetryPipelineStrategy<T>(this);
}

final class _CircuitBreakerRetryPipelineStrategy<T>
    implements RetryPipelineStrategy<T> {
  const _CircuitBreakerRetryPipelineStrategy(this.breaker);

  final CircuitBreakerStrategy breaker;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    final breaker = this.breaker;
    _refreshState(context);
    if (breaker._state == CircuitBreakerState.open) {
      final error = const CircuitOpenException();
      context.emit(
        PipelineEvent(type: PipelineEventType.circuitRejected, error: error),
      );
      throw error;
    }

    try {
      final result = await next();
      _recordSuccess(context);
      return result;
    } on RetryCancelledException {
      rethrow;
    } catch (error, stackTrace) {
      if (isCancellationError(error, context.cancelToken)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final failureContext = CircuitFailureContext(
        failure: error,
        stackTrace: stackTrace,
      );
      if (breaker.failureIf.shouldRecordFailure(failureContext)) {
        _recordFailure(context);
      }
      rethrow;
    }
  }

  void _refreshState(RetryContext<T> context) {
    if (breaker._state != CircuitBreakerState.open) {
      return;
    }
    final openedAt = breaker._openedAt;
    if (openedAt == null) {
      return;
    }
    if (context.now().difference(openedAt) >= breaker.recoveryDuration) {
      breaker._state = CircuitBreakerState.halfOpen;
      breaker._halfOpenSuccesses = 0;
      context.emit(
        const PipelineEvent(type: PipelineEventType.circuitHalfOpen),
      );
    }
  }

  void _recordSuccess(RetryContext<T> context) {
    if (breaker._state == CircuitBreakerState.halfOpen) {
      breaker._halfOpenSuccesses++;
      if (breaker._halfOpenSuccesses >= breaker.halfOpenSuccessThreshold) {
        breaker.reset();
        context.emit(
          const PipelineEvent(type: PipelineEventType.circuitClosed),
        );
      }
      return;
    }
    breaker._failures = 0;
  }

  void _recordFailure(RetryContext<T> context) {
    if (breaker._state == CircuitBreakerState.halfOpen) {
      _open(context);
      return;
    }
    breaker._failures++;
    if (breaker._failures >= breaker.failureThreshold) {
      _open(context);
    }
  }

  void _open(RetryContext<T> context) {
    breaker._state = CircuitBreakerState.open;
    breaker._openedAt = context.now();
    breaker._halfOpenSuccesses = 0;
    context.emit(const PipelineEvent(type: PipelineEventType.circuitOpened));
  }
}

final class _CircuitFailureWherePredicate extends CircuitFailurePredicate {
  const _CircuitFailureWherePredicate(this.test);

  final bool Function(CircuitFailureContext) test;

  @override
  bool shouldRecordFailure(CircuitFailureContext context) => test(context);
}

final class _OrCircuitFailurePredicate extends CircuitFailurePredicate {
  const _OrCircuitFailurePredicate(this.left, this.right);

  final CircuitFailurePredicate left;
  final CircuitFailurePredicate right;

  @override
  bool shouldRecordFailure(CircuitFailureContext context) {
    return left.shouldRecordFailure(context) ||
        right.shouldRecordFailure(context);
  }
}

final class _AndCircuitFailurePredicate extends CircuitFailurePredicate {
  const _AndCircuitFailurePredicate(this.left, this.right);

  final CircuitFailurePredicate left;
  final CircuitFailurePredicate right;

  @override
  bool shouldRecordFailure(CircuitFailureContext context) {
    return left.shouldRecordFailure(context) &&
        right.shouldRecordFailure(context);
  }
}

final class _NotCircuitFailurePredicate extends CircuitFailurePredicate {
  const _NotCircuitFailurePredicate(this.inner);

  final CircuitFailurePredicate inner;

  @override
  bool shouldRecordFailure(CircuitFailureContext context) {
    return !inner.shouldRecordFailure(context);
  }

  @override
  CircuitFailurePredicate not(CircuitFailurePredicate inner) => this.inner;
}
