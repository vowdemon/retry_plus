import 'dart:async';

import 'pipeline.dart';
import 'predicate.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Predicate that decides whether injection applies.
///
/// Callers can extend this class or use [InjectionTrigger.where] to provide
/// domain-specific injection decisions.
abstract class InjectionTrigger<T>
    extends ContextPredicate<RetryPipelineContext<T>, InjectionTrigger<T>> {
  /// Creates an injection trigger.
  const InjectionTrigger();

  /// Returns true when injection should apply to [context].
  @override
  FutureOr<bool> shouldHandle(RetryPipelineContext<T> context);

  @override
  InjectionTrigger<T> build(
    FutureOr<bool> Function(RetryPipelineContext<T> context) shouldHandle,
  ) {
    return _InjectionWhereTrigger<T>(shouldHandle);
  }

  /// Triggers when [context.random] returns a value below [rate].
  factory InjectionTrigger.rate(double rate) {
    if (rate < 0 || rate > 1) {
      throw ArgumentError.value(rate, 'rate', 'must be between 0 and 1');
    }
    return _InjectionWhereTrigger<T>((context) => context.random() < rate);
  }

  /// Always triggers injection.
  factory InjectionTrigger.always() {
    return _InjectionWhereTrigger<T>((_) => true);
  }

  /// Never triggers injection.
  factory InjectionTrigger.never() {
    return _InjectionWhereTrigger<T>((_) => false);
  }

  /// Triggers according to [test].
  factory InjectionTrigger.where(
    FutureOr<bool> Function(RetryPipelineContext<T> context) test,
  ) {
    return _InjectionWhereTrigger<T>(test);
  }
}

/// Strategy that throws a generated error when triggered.
final class InjectionThrowStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a throw injection strategy.
  InjectionThrowStrategy({
    required this.error,
    InjectionTrigger<T>? injectIf,
    super.name,
  }) : injectIf = injectIf ?? InjectionTrigger<T>.always();

  /// Generates the thrown error.
  final FutureOr<Object> Function(RetryPipelineContext<T> context) error;

  /// Decides whether injection applies.
  final InjectionTrigger<T> injectIf;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    if (!await _shouldHandle(context)) {
      return next();
    }
    context.throwIfCancelled();
    final injectedError = await error(context);
    context.throwIfCancelled();
    await _emit(context, injectedError);
    throw injectedError;
  }

  Future<bool> _shouldHandle(RetryPipelineContext<T> context) async {
    context.throwIfCancelled();
    final shouldHandle = await injectIf.shouldHandle(context);
    context.throwIfCancelled();
    return shouldHandle;
  }

  Future<void> _emit(RetryPipelineContext<T> context, Object error) async {
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.injectionThrow,
      strategyName: name,
      error: error,
      attributes: _eventAttributes(context),
    );
  }

  Map<String, Object?> _eventAttributes(RetryPipelineContext<T> context) {
    return <String, Object?>{
      'elapsed': context.elapsed,
    };
  }
}

/// Strategy that waits for a generated delay before running the inner pipeline.
final class InjectionDelayStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a delay injection strategy.
  InjectionDelayStrategy({
    required this.delay,
    InjectionTrigger<T>? injectIf,
    super.name,
  }) : injectIf = injectIf ?? InjectionTrigger<T>.always();

  /// Generates the injected delay.
  final FutureOr<Duration> Function(RetryPipelineContext<T> context) delay;

  /// Decides whether injection applies.
  final InjectionTrigger<T> injectIf;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    if (!await _shouldHandle(context)) {
      return next();
    }
    context.throwIfCancelled();
    final injectedDelay = await delay(context);
    if (injectedDelay < Duration.zero) {
      throw ArgumentError.value(injectedDelay, 'delay', 'must not be negative');
    }
    context.throwIfCancelled();
    await _emit(context, injectedDelay);
    await context.sleep(injectedDelay);
    context.throwIfCancelled();
    return next();
  }

  Future<bool> _shouldHandle(RetryPipelineContext<T> context) async {
    context.throwIfCancelled();
    final shouldHandle = await injectIf.shouldHandle(context);
    context.throwIfCancelled();
    return shouldHandle;
  }

  Future<void> _emit(RetryPipelineContext<T> context, Duration delay) async {
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.injectionDelay,
      strategyName: name,
      attributes: <String, Object?>{
        'elapsed': context.elapsed,
        'delay': delay,
      },
    );
  }
}

/// Strategy that returns a generated result when triggered.
final class InjectionResultStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a result injection strategy.
  InjectionResultStrategy({
    required this.result,
    InjectionTrigger<T>? injectIf,
    super.name,
  }) : injectIf = injectIf ?? InjectionTrigger<T>.always();

  /// Generates the injected result.
  final FutureOr<T> Function(RetryPipelineContext<T> context) result;

  /// Decides whether injection applies.
  final InjectionTrigger<T> injectIf;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    if (!await _shouldHandle(context)) {
      return next();
    }
    context.throwIfCancelled();
    final injectedResult = await result(context);
    context.throwIfCancelled();
    await _emit(context);
    return injectedResult;
  }

  Future<bool> _shouldHandle(RetryPipelineContext<T> context) async {
    context.throwIfCancelled();
    final shouldHandle = await injectIf.shouldHandle(context);
    context.throwIfCancelled();
    return shouldHandle;
  }

  Future<void> _emit(RetryPipelineContext<T> context) async {
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.injectionResult,
      strategyName: name,
      attributes: <String, Object?>{
        'elapsed': context.elapsed,
      },
    );
  }
}

/// Strategy that runs custom behavior before the inner pipeline.
final class InjectionBehaviorStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a behavior injection strategy.
  InjectionBehaviorStrategy({
    required this.behavior,
    InjectionTrigger<T>? injectIf,
    super.name,
  }) : injectIf = injectIf ?? InjectionTrigger<T>.always();

  /// Custom behavior to run before the inner pipeline.
  final FutureOr<void> Function(RetryPipelineContext<T> context) behavior;

  /// Decides whether injection applies.
  final InjectionTrigger<T> injectIf;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    if (!await _shouldHandle(context)) {
      return next();
    }
    context.throwIfCancelled();
    await _emit(context);
    await behavior(context);
    context.throwIfCancelled();
    return next();
  }

  Future<bool> _shouldHandle(RetryPipelineContext<T> context) async {
    context.throwIfCancelled();
    final shouldHandle = await injectIf.shouldHandle(context);
    context.throwIfCancelled();
    return shouldHandle;
  }

  Future<void> _emit(RetryPipelineContext<T> context) async {
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.injectionBehavior,
      strategyName: name,
      attributes: <String, Object?>{
        'elapsed': context.elapsed,
      },
    );
  }
}

final class _InjectionWhereTrigger<T> extends InjectionTrigger<T> {
  const _InjectionWhereTrigger(this._callback);

  final FutureOr<bool> Function(RetryPipelineContext<T> context) _callback;

  @override
  FutureOr<bool> shouldHandle(RetryPipelineContext<T> context) {
    return _callback(context);
  }
}
