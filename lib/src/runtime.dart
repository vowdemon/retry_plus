import 'dart:async';
import 'dart:math' as math;

import 'cancellation.dart';
import 'events.dart';
import 'exceptions.dart';
import 'timeout_strategy.dart';

/// Runtime dependencies used by retry pipelines and strategies.
final class RetryRuntime {
  /// Creates runtime dependencies.
  RetryRuntime({
    DateTime Function()? clock,
    Future<void> Function(Duration delay, CancellationToken? cancellationToken)?
    sleeper,
    double Function()? random,
    Future<T> Function<T>(
      Future<T> future,
      Duration duration,
      TimeoutScope scope,
      CancellationToken? cancellationToken,
    )?
    timeout,
    this.observer,
  }) : clock = clock ?? DateTime.now,
       sleeper = sleeper ?? _defaultSleeper,
       random = random ?? math.Random().nextDouble,
       timeout = timeout ?? _defaultTimeout;

  /// Supplies the current time.
  final DateTime Function() clock;

  /// Waits for retry delays.
  final Future<void> Function(
    Duration delay,
    CancellationToken? cancellationToken,
  )
  sleeper;

  /// Supplies randomness for jitter and random delay.
  final double Function() random;

  /// Applies timeout behavior.
  final Future<T> Function<T>(
    Future<T> future,
    Duration duration,
    TimeoutScope scope,
    CancellationToken? cancellationToken,
  )
  timeout;

  /// Optional pipeline event observer.
  final void Function(PipelineEvent event)? observer;

  /// Emits [event] to the observer.
  void emit(PipelineEvent event) {
    observer?.call(event);
  }
}

Future<void> _defaultSleeper(
  Duration delay,
  CancellationToken? cancellationToken,
) async {
  cancellationToken?.throwIfCancelled();
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  cancellationToken?.throwIfCancelled();
}

Future<T> _defaultTimeout<T>(
  Future<T> future,
  Duration duration,
  TimeoutScope scope,
  CancellationToken? cancellationToken,
) async {
  cancellationToken?.throwIfCancelled();
  return future.timeout(
    duration,
    onTimeout: () => throw RetryTimeoutException(scope),
  );
}
