import 'dart:async';

import 'package:clock/clock.dart';

import 'cancellation.dart';
import 'exceptions.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Circuit breaker state.
enum CircuitBreakerState {
  /// Calls are allowed and failures are counted.
  closed,

  /// Calls are rejected until the recovery duration elapses.
  open,

  /// Probe calls are allowed to determine whether the circuit can close.
  halfOpen,

  /// Calls are rejected until manually closed.
  isolated,
}

/// Context used to classify circuit breaker failures.
final class CircuitFailureContext implements OutcomeContext<Object?> {
  /// Creates a circuit failure context.
  const CircuitFailureContext({
    required this.outcome,
  });

  /// Outcome produced by guarded execution.
  @override
  final StrategyOutcome<Object?> outcome;

  /// Pipeline execution context.
  @override
  RetryPipelineContext<Object?> get pipelineContext => outcome.context;

  /// Elapsed pipeline time.
  @override
  Duration get elapsed => outcome.elapsed;

  /// Failure thrown by guarded execution.
  Object get failure => OutcomeContextAccess<Object?>(this).failure;

  /// Stack trace captured with [failure].
  StackTrace get stackTrace => OutcomeContextAccess<Object?>(this).stackTrace;
}

/// Predicate that decides whether a failure counts for the circuit breaker.
///
/// Callers can extend this class or use [CircuitFailurePredicate.where] to
/// provide domain-specific circuit failure classification.
abstract class CircuitFailurePredicate
    extends ContextPredicate<CircuitFailureContext, CircuitFailurePredicate> {
  /// Creates a circuit failure predicate.
  const CircuitFailurePredicate();

  /// Returns true when [context] should count as a circuit failure.
  @override
  FutureOr<bool> shouldHandle(CircuitFailureContext context);

  @override
  CircuitFailurePredicate build(
    FutureOr<bool> Function(CircuitFailureContext context) shouldHandle,
  ) {
    return _CircuitFailureWherePredicate(shouldHandle);
  }

  /// Counts every non-cancellation outcome.
  factory CircuitFailurePredicate.any() => _CircuitFailureWherePredicate(
        (context) => !context.isCancellation,
      );

  /// Counts ordinary exception outcomes except cancellation.
  factory CircuitFailurePredicate.exception() {
    return _CircuitFailureWherePredicate(
      (context) =>
          context.outcome is StrategyOutcomeError<Object?> &&
          !context.isCancellation,
    );
  }

  /// Counts exception outcomes matching [test].
  factory CircuitFailurePredicate.exceptionWhere(
    FutureOr<bool> Function(Object error, StackTrace stackTrace) test,
  ) {
    return _CircuitFailureWherePredicate(
      (context) => switch (context.outcome) {
        StrategyOutcomeError(:final error, :final stackTrace)
            when !context.isCancellation =>
          test(error, stackTrace),
        _ => false,
      },
    );
  }

  /// Counts outcomes matching [test].
  factory CircuitFailurePredicate.where(
    FutureOr<bool> Function(CircuitFailureContext context) test,
  ) {
    return _CircuitFailureWherePredicate(test);
  }

  /// Counts failures of type [E].
  static CircuitFailurePredicate exceptionType<E extends Object>() {
    return CircuitFailurePredicate.exceptionWhere((error, _) => error is E);
  }

  /// Counts result outcomes matching [test].
  static CircuitFailurePredicate result<T>(
    FutureOr<bool> Function(T result) test,
  ) {
    return _CircuitFailureWherePredicate(
      (context) => switch (context.outcome) {
        StrategyOutcomeResult(result: final result) when result is T =>
          test(result),
        _ => false,
      },
    );
  }
}

/// A single execution sample observed by a circuit breaker meter.
final class CircuitMeterSample {
  /// Creates a circuit meter sample.
  const CircuitMeterSample({
    required this.outcome,
    required this.isFailure,
    required this.timestamp,
  });

  /// Outcome produced by the guarded execution.
  final StrategyOutcome<Object?> outcome;

  /// Whether [outcome] was classified as a handled circuit failure.
  final bool isFailure;

  /// Sample timestamp from the execution context clock.
  final DateTime timestamp;
}

/// Stateful circuit metering contract.
///
/// Implementations receive observed execution samples and return true when the
/// breaker should transition to open state.
abstract class CircuitMeter {
  /// Creates a circuit meter.
  const CircuitMeter();

  /// Creates a meter that opens after [failureThreshold] consecutive failures.
  factory CircuitMeter.consecutive(int failureThreshold) {
    return _ConsecutiveCircuitMeter(failureThreshold);
  }

  /// Creates a meter that opens when handled failure ratio reaches
  /// [failureRatio] within [samplingDuration] after [minimumThroughput].
  factory CircuitMeter.failureRatio({
    required double failureRatio,
    required Duration samplingDuration,
    required int minimumThroughput,
  }) {
    return _FailureRatioCircuitMeter(
      failureRatio: failureRatio,
      samplingDuration: samplingDuration,
      minimumThroughput: minimumThroughput,
    );
  }

  /// Records [sample] and returns true when the breaker should open.
  bool record(CircuitMeterSample sample);

  /// Clears any accumulated meter state.
  void reset();
}

/// Metadata provided when a circuit opens.
final class CircuitOpenContext {
  /// Creates circuit-open metadata.
  const CircuitOpenContext({
    required this.outcome,
    required this.previousState,
    required this.pipelineContext,
    this.breakDuration,
  });

  /// Outcome that caused the circuit to open, when opened by execution.
  final StrategyOutcome<Object?>? outcome;

  /// State before the transition to open.
  final CircuitBreakerState previousState;

  /// Execution context that caused the transition, when available.
  final RetryPipelineContext<Object?>? pipelineContext;

  /// Duration the circuit will remain open, when known.
  final Duration? breakDuration;

  CircuitOpenContext _withBreakDuration(Duration duration) {
    return CircuitOpenContext(
      outcome: outcome,
      previousState: previousState,
      pipelineContext: pipelineContext,
      breakDuration: duration,
    );
  }
}

/// Metadata provided when an open circuit moves to half-open.
final class CircuitHalfOpenContext {
  /// Creates circuit half-open metadata.
  const CircuitHalfOpenContext({
    required this.pipelineContext,
  });

  /// Execution context that observed the half-open transition.
  final RetryPipelineContext<Object?> pipelineContext;
}

/// Metadata provided when a circuit closes.
final class CircuitClosedContext {
  /// Creates circuit-closed metadata.
  const CircuitClosedContext({
    required this.previousState,
    required this.pipelineContext,
  });

  /// State before the transition to closed.
  final CircuitBreakerState previousState;

  /// Execution context that caused the transition, when available.
  final RetryPipelineContext<Object?>? pipelineContext;
}

/// Metadata provided when a circuit rejects execution.
final class CircuitRejectedContext {
  /// Creates circuit-rejection metadata.
  const CircuitRejectedContext({
    required this.state,
    required this.error,
    required this.pipelineContext,
    this.retryAfter,
  });

  /// State that rejected execution.
  final CircuitBreakerState state;

  /// Rejection error.
  final CircuitOpenException error;

  /// Execution context rejected by the circuit.
  final RetryPipelineContext<Object?> pipelineContext;

  /// Duration after which a probe may be allowed, when known.
  final Duration? retryAfter;
}

/// Read-only view of circuit breaker state.
final class CircuitStateProvider {
  const CircuitStateProvider._(this._breaker);

  final CircuitBreaker _breaker;

  /// Current circuit state.
  CircuitBreakerState get state => _breaker.state;

  /// Time at which the circuit most recently opened, when open.
  DateTime? get openedAt => _breaker._openedAt;

  /// Break duration currently in effect, when open.
  Duration? get breakDuration => _breaker._currentBreakDuration;

  /// Remaining time before an open circuit may move to half-open.
  Duration? retryAfter([DateTime? now]) => _breaker._retryAfter(now);
}

/// Manual circuit control surface.
final class CircuitBreakerControl {
  const CircuitBreakerControl._(this._breaker);

  final CircuitBreaker _breaker;

  /// Manually isolates the circuit until [close] is called.
  Future<void> isolate() async {
    _breaker._state = CircuitBreakerState.isolated;
    _breaker._openedAt = null;
    _breaker._currentBreakDuration = null;
    _breaker.meter.reset();
  }

  /// Manually closes an isolated or open circuit.
  Future<void> close() async {
    final context = _breaker._close(null);
    await _breaker.onClosed?.call(context);
  }
}

/// Stateful circuit breaker.
///
/// Cancellation always bypasses circuit failure accounting, even when
/// [failureIf] would otherwise match the thrown value.
final class CircuitBreaker {
  /// Creates a circuit breaker.
  CircuitBreaker({
    this.name,
    int? failureThreshold,
    CircuitMeter? meter,
    required this.recoveryDuration,
    FutureOr<Duration> Function(CircuitOpenContext context)? breakDuration,
    this.halfOpenSuccessThreshold = 1,
    CircuitFailurePredicate? failureIf,
    this.onOpened,
    this.onHalfOpened,
    this.onClosed,
    this.onRejected,
  })  : failureThreshold = failureThreshold ?? 1,
        meter = meter ?? CircuitMeter.consecutive(failureThreshold ?? 1),
        breakDurationGenerator = breakDuration,
        failureIf = failureIf ?? CircuitFailurePredicate.exception() {
    if (this.failureThreshold < 1) {
      throw ArgumentError.value(
        this.failureThreshold,
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

  /// Optional breaker instance name used by default strategy telemetry.
  final String? name;

  /// Failures required to open the circuit.
  final int failureThreshold;

  /// Meter that decides when handled outcomes should open the circuit.
  final CircuitMeter meter;

  /// Time the circuit remains open before probing.
  final Duration recoveryDuration;

  /// Optional dynamic break duration generator.
  final FutureOr<Duration> Function(CircuitOpenContext context)?
      breakDurationGenerator;

  /// Successful probes required to close the circuit.
  final int halfOpenSuccessThreshold;

  /// Predicate that decides which non-cancellation failures affect state.
  final CircuitFailurePredicate failureIf;

  /// Hook invoked after the circuit opens.
  final FutureOr<void> Function(CircuitOpenContext context)? onOpened;

  /// Hook invoked after the circuit moves to half-open.
  final FutureOr<void> Function(CircuitHalfOpenContext context)? onHalfOpened;

  /// Hook invoked after the circuit closes.
  final FutureOr<void> Function(CircuitClosedContext context)? onClosed;

  /// Hook invoked when the circuit rejects execution.
  final FutureOr<void> Function(CircuitRejectedContext context)? onRejected;

  /// Read-only state provider.
  late final CircuitStateProvider stateProvider = CircuitStateProvider._(this);

  /// Manual circuit control.
  late final CircuitBreakerControl control = CircuitBreakerControl._(this);

  var _state = CircuitBreakerState.closed;
  var _halfOpenSuccesses = 0;
  DateTime? _openedAt;
  Duration? _currentBreakDuration;

  /// Current breaker state.
  CircuitBreakerState get state => _state;

  /// Returns this breaker as a typed pipeline strategy.
  CircuitBreakerStrategy<T> asStrategy<T>({String? name}) {
    return CircuitBreakerStrategy<T>(this, name: name);
  }

  /// Resets the breaker to closed state.
  void reset() {
    _state = CircuitBreakerState.closed;
    meter.reset();
    _halfOpenSuccesses = 0;
    _openedAt = null;
    _currentBreakDuration = null;
  }

  Duration? _retryAfter([DateTime? now]) {
    if (_state != CircuitBreakerState.open) {
      return null;
    }
    final openedAt = _openedAt;
    final breakDuration = _currentBreakDuration;
    if (openedAt == null || breakDuration == null) {
      return null;
    }
    final remaining =
        breakDuration - ((now ?? clock.now()).difference(openedAt));
    return remaining <= Duration.zero ? Duration.zero : remaining;
  }

  CircuitClosedContext _close(RetryPipelineContext<Object?>? context) {
    final previousState = _state;
    reset();
    return CircuitClosedContext(
      previousState: previousState,
      pipelineContext: context,
    );
  }
}

/// Pipeline strategy that applies a shared [CircuitBreaker].
final class CircuitBreakerStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a typed circuit breaker strategy using [breaker].
  CircuitBreakerStrategy(this.breaker, {String? name})
      : super(name: name ?? breaker.name);

  /// Shared circuit breaker state machine.
  final CircuitBreaker breaker;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    final breaker = this.breaker;
    await _refreshState(context);
    if (breaker._state == CircuitBreakerState.open ||
        breaker._state == CircuitBreakerState.isolated) {
      final retryAfter = breaker._retryAfter(context.now());
      final error = CircuitOpenException(
        breaker._state == CircuitBreakerState.isolated
            ? 'Circuit breaker is isolated'
            : 'Circuit breaker is open',
        retryAfter,
      );
      final rejectionContext = CircuitRejectedContext(
        state: breaker._state,
        error: error,
        pipelineContext: context,
        retryAfter: retryAfter,
      );
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.circuitRejected,
        strategyName: name,
        error: error,
        attributes: {
          'state': breaker._state.name,
          if (retryAfter != null) 'retryAfter': retryAfter,
        },
      );
      await breaker.onRejected?.call(rejectionContext);
      throw error;
    }

    try {
      final result = await next();
      final failureContext = CircuitFailureContext(
        outcome: StrategyOutcome<Object?>.result(result, context: context),
      );
      if (await breaker.failureIf.shouldHandle(failureContext)) {
        await _recordFailure(context, failureContext.outcome);
      } else {
        await _recordSuccess(context, failureContext.outcome);
      }
      return result;
    } on RetryCancelledException {
      rethrow;
    } catch (error, stackTrace) {
      if (isCancellationError(error, context.cancelToken)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final failureContext = CircuitFailureContext(
        outcome: StrategyOutcome<Object?>.error(
          error,
          stackTrace,
          context: context,
        ),
      );
      if (await breaker.failureIf.shouldHandle(failureContext)) {
        await _recordFailure(context, failureContext.outcome);
      }
      rethrow;
    }
  }

  Future<void> _refreshState(RetryPipelineContext<T> context) async {
    if (breaker._state != CircuitBreakerState.open) {
      return;
    }
    final openedAt = breaker._openedAt;
    if (openedAt == null) {
      return;
    }
    final breakDuration =
        breaker._currentBreakDuration ?? breaker.recoveryDuration;
    if (context.now().difference(openedAt) >= breakDuration) {
      breaker._state = CircuitBreakerState.halfOpen;
      breaker._halfOpenSuccesses = 0;
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.circuitHalfOpened,
        strategyName: name,
        attributes: {'state': CircuitBreakerState.halfOpen.name},
      );
      await breaker.onHalfOpened?.call(
        CircuitHalfOpenContext(pipelineContext: context),
      );
    }
  }

  Future<void> _recordSuccess(
    RetryPipelineContext<T> context,
    StrategyOutcome<Object?> outcome,
  ) async {
    if (breaker._state == CircuitBreakerState.halfOpen) {
      breaker._halfOpenSuccesses++;
      if (breaker._halfOpenSuccesses >= breaker.halfOpenSuccessThreshold) {
        final closedContext = breaker._close(context);
        await context.telemetry?.emit<Object?>(
          type: TelemetryEventType.circuitClosed,
          outcome: outcome,
          strategyName: name,
          attributes: {'previousState': closedContext.previousState.name},
        );
        await breaker.onClosed?.call(closedContext);
      }
      return;
    }
    breaker.meter.record(
      CircuitMeterSample(
        outcome: outcome,
        isFailure: false,
        timestamp: context.now(),
      ),
    );
  }

  Future<void> _recordFailure(
    RetryPipelineContext<T> context,
    StrategyOutcome<Object?> outcome,
  ) async {
    if (breaker._state == CircuitBreakerState.halfOpen) {
      await _open(context, outcome);
      return;
    }
    final shouldOpen = breaker.meter.record(
      CircuitMeterSample(
        outcome: outcome,
        isFailure: true,
        timestamp: context.now(),
      ),
    );
    if (shouldOpen) {
      await _open(context, outcome);
    }
  }

  Future<void> _open(
    RetryPipelineContext<T> context,
    StrategyOutcome<Object?> outcome,
  ) async {
    final previousState = breaker._state;
    final openContext = CircuitOpenContext(
      outcome: outcome,
      previousState: previousState,
      pipelineContext: context,
    );
    final breakDuration =
        await breaker.breakDurationGenerator?.call(openContext) ??
            breaker.recoveryDuration;
    if (breakDuration < Duration.zero) {
      throw ArgumentError.value(
        breakDuration,
        'breakDuration',
        'must not be negative',
      );
    }
    breaker._state = CircuitBreakerState.open;
    breaker._openedAt = context.now();
    breaker._currentBreakDuration = breakDuration;
    breaker._halfOpenSuccesses = 0;
    breaker.meter.reset();
    final openedContext = openContext._withBreakDuration(breakDuration);
    await context.telemetry?.emit<Object?>(
      type: TelemetryEventType.circuitOpened,
      outcome: outcome,
      strategyName: name,
      error: switch (outcome) {
        StrategyOutcomeError(:final error) => error,
        _ => null,
      },
      stackTrace: switch (outcome) {
        StrategyOutcomeError(:final stackTrace) => stackTrace,
        _ => null,
      },
      attributes: {
        'previousState': previousState.name,
        'breakDuration': breakDuration,
      },
    );
    await breaker.onOpened?.call(openedContext);
  }
}

final class _ConsecutiveCircuitMeter implements CircuitMeter {
  _ConsecutiveCircuitMeter(this.failureThreshold) {
    if (failureThreshold < 1) {
      throw ArgumentError.value(
        failureThreshold,
        'failureThreshold',
        'must be at least 1',
      );
    }
  }

  final int failureThreshold;

  var _failures = 0;

  @override
  bool record(CircuitMeterSample sample) {
    if (sample.isFailure) {
      _failures++;
    } else {
      _failures = 0;
    }
    return _failures >= failureThreshold;
  }

  @override
  void reset() {
    _failures = 0;
  }
}

final class _FailureRatioCircuitMeter implements CircuitMeter {
  _FailureRatioCircuitMeter({
    required this.failureRatio,
    required this.samplingDuration,
    required this.minimumThroughput,
  }) {
    if (failureRatio <= 0 || failureRatio > 1) {
      throw ArgumentError.value(
        failureRatio,
        'failureRatio',
        'must be greater than 0 and at most 1',
      );
    }
    if (samplingDuration <= Duration.zero) {
      throw ArgumentError.value(
        samplingDuration,
        'samplingDuration',
        'must be greater than zero',
      );
    }
    if (minimumThroughput < 1) {
      throw ArgumentError.value(
        minimumThroughput,
        'minimumThroughput',
        'must be at least 1',
      );
    }
  }

  final double failureRatio;
  final Duration samplingDuration;
  final int minimumThroughput;

  final _samples = <CircuitMeterSample>[];

  @override
  bool record(CircuitMeterSample sample) {
    _samples.add(sample);
    _prune(sample.timestamp);
    if (_samples.length < minimumThroughput) {
      return false;
    }

    final failures = _samples.where((sample) => sample.isFailure).length;
    return failures / _samples.length >= failureRatio;
  }

  @override
  void reset() {
    _samples.clear();
  }

  void _prune(DateTime now) {
    _samples.removeWhere(
      (sample) => now.difference(sample.timestamp) > samplingDuration,
    );
  }
}

final class _CircuitFailureWherePredicate extends CircuitFailurePredicate {
  const _CircuitFailureWherePredicate(this._callback);

  final FutureOr<bool> Function(CircuitFailureContext) _callback;

  @override
  FutureOr<bool> shouldHandle(CircuitFailureContext context) =>
      _callback(context);
}
