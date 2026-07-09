import 'dart:async';
import 'dart:collection';

import 'cancellation.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Context supplied when creating or executing a hedged action.
final class HedgingActionContext<T> {
  /// Creates hedging action metadata.
  const HedgingActionContext({
    required this.actionIndex,
    required this.pipelineContext,
    required this.cancellationToken,
    required this.observedOutcomes,
  });

  /// Zero-based action index. The primary action is 0.
  final int actionIndex;

  /// Whether this action is a hedged action.
  bool get isHedged => actionIndex > 0;

  /// Pipeline execution context.
  final RetryPipelineContext<T> pipelineContext;

  /// Cooperative cancellation token for this action.
  final CancellationToken cancellationToken;

  /// Outcomes observed before this action was created.
  final List<StrategyOutcome<T>> observedOutcomes;
}

/// Context passed to hedging predicates.
final class HedgingOutcomeContext<T> implements OutcomeContext<T> {
  /// Creates hedging outcome metadata.
  const HedgingOutcomeContext({
    required this.outcome,
    required this.actionIndex,
    required this.pipelineContext,
    required this.observedOutcomes,
  });

  /// Outcome produced by an action.
  @override
  final StrategyOutcome<T> outcome;

  /// Elapsed pipeline time.
  @override
  Duration get elapsed => outcome.elapsed;

  /// Action index that produced [outcome].
  final int actionIndex;

  /// Pipeline execution context.
  @override
  final RetryPipelineContext<T> pipelineContext;

  /// Outcomes observed before [outcome].
  final List<StrategyOutcome<T>> observedOutcomes;
}

/// Context passed when a hedged action is scheduled.
final class HedgingScheduledContext<T> {
  /// Creates hedging schedule metadata.
  const HedgingScheduledContext({
    required this.actionIndex,
    required this.delay,
    required this.pipelineContext,
    required this.observedOutcomes,
  });

  /// Hedged action index.
  final int actionIndex;

  /// Delay that elapsed before scheduling the action.
  final Duration delay;

  /// Pipeline execution context.
  final RetryPipelineContext<T> pipelineContext;

  /// Outcomes observed before this action was scheduled.
  final List<StrategyOutcome<T>> observedOutcomes;
}

/// Context passed when a hedging outcome is selected.
final class HedgingSelectedContext<T> implements OutcomeContext<T> {
  /// Creates hedging selection metadata.
  const HedgingSelectedContext({
    required this.outcome,
    required this.actionIndex,
    required this.pipelineContext,
    required this.observedOutcomes,
  });

  /// Selected outcome.
  @override
  final StrategyOutcome<T> outcome;

  /// Elapsed pipeline time.
  @override
  Duration get elapsed => outcome.elapsed;

  /// Action index that produced [outcome].
  final int actionIndex;

  /// Pipeline execution context.
  @override
  final RetryPipelineContext<T> pipelineContext;

  /// Outcomes observed before selection.
  final List<StrategyOutcome<T>> observedOutcomes;
}

/// Predicate that decides whether a hedging outcome is handled.
abstract class HedgingPredicate<T>
    extends ContextPredicate<HedgingOutcomeContext<T>, HedgingPredicate<T>> {
  /// Creates a hedging predicate.
  const HedgingPredicate();

  /// Returns true when [context] should not win the hedging race.
  @override
  FutureOr<bool> shouldHandle(HedgingOutcomeContext<T> context);

  @override
  HedgingPredicate<T> build(
    FutureOr<bool> Function(HedgingOutcomeContext<T> context) shouldHandle,
  ) {
    return _HedgingWherePredicate<T>(shouldHandle);
  }

  /// Handles ordinary exception outcomes except cancellation.
  factory HedgingPredicate.exception() => _HedgingOutcomePredicate<T>(
        OutcomePredicate<T>.exception(),
      );

  /// Handles exception outcomes of type [E].
  static HedgingPredicate<T> exceptionType<E extends Object, T>() {
    return _HedgingOutcomePredicate<T>(
      OutcomePredicate.exceptionType<E, T>(),
    );
  }

  /// Handles result outcomes matching [test].
  factory HedgingPredicate.result(FutureOr<bool> Function(T result) test) {
    return _HedgingOutcomePredicate<T>(OutcomePredicate<T>.result(test));
  }

  /// Handles outcomes matching [test].
  factory HedgingPredicate.where(
    FutureOr<bool> Function(HedgingOutcomeContext<T> context) test,
  ) {
    return _HedgingWherePredicate<T>(test);
  }

  /// Handles every non-cancellation outcome.
  factory HedgingPredicate.any() => _HedgingOutcomePredicate<T>(
        OutcomePredicate<T>.any(),
      );

  /// Handles no outcomes.
  factory HedgingPredicate.never() => _HedgingOutcomePredicate<T>(
        OutcomePredicate<T>.never(),
      );
}

/// Strategy that races primary execution with optional hedged actions.
final class HedgingStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a hedging strategy.
  HedgingStrategy({
    super.name,
    this.delay = Duration.zero,
    this.delayGenerator,
    this.maxHedgedAttempts = 1,
    HedgingPredicate<T>? hedgeIf,
    this.actionGenerator,
    this.onHedge,
    this.onOutcome,
    this.onSelected,
  }) : hedgeIf = hedgeIf ?? HedgingPredicate<T>.exception() {
    if (maxHedgedAttempts < 0) {
      throw ArgumentError.value(
        maxHedgedAttempts,
        'maxHedgedAttempts',
        'must not be negative',
      );
    }
    if (delay < Duration.zero) {
      throw ArgumentError.value(delay, 'delay', 'must not be negative');
    }
  }

  /// Fixed delay before a latency-triggered hedge.
  final Duration delay;

  /// Optional generated delay for the next hedged action.
  final FutureOr<Duration?> Function(HedgingActionContext<T> context)?
      delayGenerator;

  /// Maximum number of additional hedged actions.
  final int maxHedgedAttempts;

  /// Predicate for outcomes that should not win while capacity remains.
  final HedgingPredicate<T> hedgeIf;

  /// Optional generator for custom hedged actions.
  final FutureOr<FutureOr<T> Function(HedgingActionContext<T> context)?>
      Function(HedgingActionContext<T> context)? actionGenerator;

  /// Hook invoked before a hedged action starts.
  final FutureOr<void> Function(HedgingScheduledContext<T> context)? onHedge;

  /// Hook invoked when an action outcome is observed.
  final FutureOr<void> Function(HedgingOutcomeContext<T> context)? onOutcome;

  /// Hook invoked when an outcome is selected.
  final FutureOr<void> Function(HedgingSelectedContext<T> context)? onSelected;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    final controller = _HedgingExecution<T>(this, context, next);
    return controller.run();
  }
}

final class _HedgingExecution<T> {
  _HedgingExecution(this.strategy, this.context, this.next);

  final HedgingStrategy<T> strategy;
  final RetryPipelineContext<T> context;
  final Future<T> Function() next;
  final _signals = _SignalQueue<_HedgingSignal<T>>();
  final _observedOutcomes = <StrategyOutcome<T>>[];
  final _actionTokens = <int, CancellationToken>{};
  var _inFlight = 0;
  var _nextActionIndex = 1;
  var _completed = false;
  var _delayScheduled = false;
  var _delayDisabled = false;

  Future<T> run() async {
    _startAction(0, (_) => next(), CancellationToken());
    _scheduleDelayedHedge();
    _watchCallerCancellation();

    while (true) {
      final signal = await _signals.next();
      if (_completed) {
        continue;
      }

      switch (signal) {
        case _CancellationSignal<T>(:final reason):
          _cancelActions(reason);
          _completed = true;
          _throwCancellation(reason);
        case _ScheduleHedgeSignal<T>(:final actionIndex, :final delay):
          _delayScheduled = false;
          if (_canStartHedge(actionIndex)) {
            await _startHedge(actionIndex, delay);
          }
        case _OutcomeSignal<T>(:final outcome, :final actionIndex):
          final selected = await _handleOutcome(outcome, actionIndex);
          if (selected != null) {
            return selected;
          }
      }
    }
  }

  Future<T?> _handleOutcome(
    StrategyOutcome<T> outcome,
    int actionIndex,
  ) async {
    _inFlight--;
    final previous = List<StrategyOutcome<T>>.unmodifiable(_observedOutcomes);
    final outcomeContext = HedgingOutcomeContext<T>(
      outcome: outcome,
      actionIndex: actionIndex,
      pipelineContext: context,
      observedOutcomes: previous,
    );
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.hedgingOutcome,
      outcome: outcome,
      strategyName: strategy.name,
      error: switch (outcome) {
        StrategyOutcomeError(:final error) => error,
        _ => null,
      },
      stackTrace: switch (outcome) {
        StrategyOutcomeError(:final stackTrace) => stackTrace,
        _ => null,
      },
      attributes: {'actionIndex': actionIndex},
    );
    await strategy.onOutcome?.call(outcomeContext);

    final handled = await strategy.hedgeIf.shouldHandle(outcomeContext);
    if (!handled) {
      _completed = true;
      _cancelActions(const RetryCancelledException('Hedging action lost race'));
      final selectedContext = HedgingSelectedContext<T>(
        outcome: outcome,
        actionIndex: actionIndex,
        pipelineContext: context,
        observedOutcomes: previous,
      );
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.hedgingSelected,
        outcome: outcome,
        strategyName: strategy.name,
        error: switch (outcome) {
          StrategyOutcomeError(:final error) => error,
          _ => null,
        },
        stackTrace: switch (outcome) {
          StrategyOutcomeError(:final stackTrace) => stackTrace,
          _ => null,
        },
        attributes: {'actionIndex': actionIndex},
      );
      await strategy.onSelected?.call(selectedContext);
      return _completeOutcome(outcome);
    }

    _observedOutcomes.add(outcome);
    if (_nextActionIndex <= strategy.maxHedgedAttempts && !_delayDisabled) {
      await _startHedge(_nextActionIndex, Duration.zero);
      return null;
    }
    if (_inFlight == 0) {
      _completed = true;
      return _completeOutcome(outcome);
    }
    return null;
  }

  Future<void> _startHedge(int actionIndex, Duration delay) async {
    if (!_canStartHedge(actionIndex)) {
      return;
    }
    final token = CancellationToken();
    final actionContext = _actionContext(actionIndex, token);
    FutureOr<T> Function(HedgingActionContext<T> context)? generatedAction;
    try {
      generatedAction = strategy.actionGenerator == null
          ? null
          : await strategy.actionGenerator!.call(actionContext);
    } catch (error, stackTrace) {
      _inFlight++;
      _actionTokens[actionIndex] = token;
      _nextActionIndex = actionIndex + 1;
      _signals.add(
        _OutcomeSignal<T>(
          actionIndex,
          StrategyOutcome<T>.error(
            error,
            stackTrace,
            context: context,
            metadata: {'actionIndex': actionIndex},
          ),
        ),
      );
      _scheduleDelayedHedge();
      return;
    }
    FutureOr<T> defaultAction(HedgingActionContext<T> _) => next();
    final action = generatedAction ??
        (strategy.actionGenerator == null ? defaultAction : null);
    if (action == null) {
      _delayDisabled = true;
      return;
    }

    final scheduledContext = HedgingScheduledContext<T>(
      actionIndex: actionIndex,
      delay: delay,
      pipelineContext: context,
      observedOutcomes:
          List<StrategyOutcome<T>>.unmodifiable(_observedOutcomes),
    );
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.hedgingScheduled,
      strategyName: strategy.name,
      attributes: {'actionIndex': actionIndex, 'delay': delay},
    );
    await strategy.onHedge?.call(scheduledContext);
    _nextActionIndex = actionIndex + 1;
    _startAction(actionIndex, action, token);
    _scheduleDelayedHedge();
  }

  void _startAction(
    int actionIndex,
    FutureOr<T> Function(HedgingActionContext<T> context) action,
    CancellationToken cancellationToken,
  ) {
    _inFlight++;
    _actionTokens[actionIndex] = cancellationToken;
    Future<T>.sync(() => action(_actionContext(actionIndex, cancellationToken)))
        .then(
      (result) {
        _signals.add(
          _OutcomeSignal<T>(
            actionIndex,
            StrategyOutcome<T>.result(
              result,
              context: context,
              metadata: {'actionIndex': actionIndex},
            ),
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _signals.add(
          _OutcomeSignal<T>(
            actionIndex,
            StrategyOutcome<T>.error(
              error,
              stackTrace,
              context: context,
              metadata: {'actionIndex': actionIndex},
            ),
          ),
        );
      },
    );
  }

  void _scheduleDelayedHedge() {
    if (_delayScheduled ||
        _delayDisabled ||
        _nextActionIndex > strategy.maxHedgedAttempts) {
      return;
    }
    _delayScheduled = true;
    final actionIndex = _nextActionIndex;
    final delayContext = _actionContext(actionIndex, CancellationToken());
    Future<void>(() async {
      final generatedDelay = strategy.delayGenerator == null
          ? strategy.delay
          : await strategy.delayGenerator!.call(delayContext);
      if (generatedDelay == null) {
        _delayDisabled = true;
        _delayScheduled = false;
        return;
      }
      if (generatedDelay < Duration.zero) {
        throw ArgumentError.value(
          generatedDelay,
          'delay',
          'must not be negative',
        );
      }
      if (generatedDelay > Duration.zero) {
        await Future<void>.delayed(generatedDelay);
      }
      _signals.add(_ScheduleHedgeSignal<T>(actionIndex, generatedDelay));
    });
  }

  HedgingActionContext<T> _actionContext(
    int actionIndex,
    CancellationToken cancellationToken,
  ) {
    return HedgingActionContext<T>(
      actionIndex: actionIndex,
      pipelineContext: context,
      cancellationToken: cancellationToken,
      observedOutcomes:
          List<StrategyOutcome<T>>.unmodifiable(_observedOutcomes),
    );
  }

  bool _canStartHedge(int actionIndex) {
    return !_completed &&
        actionIndex == _nextActionIndex &&
        actionIndex <= strategy.maxHedgedAttempts;
  }

  void _watchCallerCancellation() {
    Future<void>(() async {
      while (!_completed) {
        if (context.isCancelled) {
          _signals.add(
            _CancellationSignal<T>(
              context.cancelToken.reason ?? const RetryCancelledException(),
            ),
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
  }

  void _cancelActions(Object reason) {
    for (final token in _actionTokens.values) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
  }

  T _completeOutcome(StrategyOutcome<T> outcome) {
    return switch (outcome) {
      StrategyOutcomeResult(:final result) => result,
      StrategyOutcomeError(:final error, :final stackTrace) =>
        Error.throwWithStackTrace(error, stackTrace),
    };
  }

  Never _throwCancellation(Object reason) {
    if (reason is Exception || reason is Error) {
      throw reason;
    }
    throw RetryCancelledException(reason.toString());
  }
}

sealed class _HedgingSignal<T> {
  const _HedgingSignal();
}

final class _OutcomeSignal<T> extends _HedgingSignal<T> {
  const _OutcomeSignal(this.actionIndex, this.outcome);

  final int actionIndex;
  final StrategyOutcome<T> outcome;
}

final class _ScheduleHedgeSignal<T> extends _HedgingSignal<T> {
  const _ScheduleHedgeSignal(this.actionIndex, this.delay);

  final int actionIndex;
  final Duration delay;
}

final class _CancellationSignal<T> extends _HedgingSignal<T> {
  const _CancellationSignal(this.reason);

  final Object reason;
}

final class _SignalQueue<T> {
  final _items = Queue<T>();
  Completer<T>? _pending;

  Future<T> next() {
    if (_items.isNotEmpty) {
      return Future<T>.value(_items.removeFirst());
    }
    final pending = Completer<T>();
    _pending = pending;
    return pending.future;
  }

  void add(T item) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      _pending = null;
      pending.complete(item);
      return;
    }
    _items.addLast(item);
  }
}

final class _HedgingOutcomePredicate<T> extends HedgingPredicate<T> {
  const _HedgingOutcomePredicate(this.inner);

  final OutcomePredicate<T> inner;

  @override
  FutureOr<bool> shouldHandle(HedgingOutcomeContext<T> context) {
    return inner.shouldHandle(context.outcome);
  }
}

final class _HedgingWherePredicate<T> extends HedgingPredicate<T> {
  const _HedgingWherePredicate(this._callback);

  final FutureOr<bool> Function(HedgingOutcomeContext<T>) _callback;

  @override
  FutureOr<bool> shouldHandle(HedgingOutcomeContext<T> context) {
    return _callback(context);
  }
}
