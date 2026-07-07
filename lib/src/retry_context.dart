import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'cancellation.dart';
import 'exceptions.dart';
import 'outcome.dart';
import 'pipeline_event.dart';
import 'retry_future.dart';
import 'timeout_strategy.dart';

/// Context for retry decisions and pipeline execution.
final class RetryContext<T> {
  /// Creates retry attempt metadata.
  RetryContext({
    this.attemptNumber = 0,
    Duration elapsed = Duration.zero,
    AttemptOutcome<T>? outcome,
    this.nextDelay = Duration.zero,
  })  : _elapsed = elapsed,
        _outcome = outcome,
        _startedAt = null,
        _cancellationToken = null,
        _onEvent = null;

  /// Creates a context for one pipeline execution.
  RetryContext.execution({
    required DateTime startedAt,
    required CancellationToken cancellationToken,
    void Function(PipelineEvent event)? onEvent,
  })  : attemptNumber = 0,
        _elapsed = Duration.zero,
        nextDelay = Duration.zero,
        _startedAt = startedAt,
        _cancellationToken = cancellationToken,
        _onEvent = onEvent;

  /// One-based attempt number.
  int attemptNumber;

  /// Elapsed time since the policy started execution.
  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return _elapsed;
    }
    return clock.now().difference(startedAt);
  }

  set elapsed(Duration value) {
    _elapsed = value;
  }

  /// Outcome of the latest attempt.
  AttemptOutcome<T> get outcome {
    final outcome = _outcome;
    if (outcome == null) {
      throw StateError('No attempt outcome is available yet.');
    }
    return outcome;
  }

  set outcome(AttemptOutcome<T> value) {
    _outcome = value;
  }

  /// Delay planned before the next attempt.
  Duration nextDelay;

  /// Current retry execution phase.
  RetryPhase get phase => _phase;

  /// Effective cancellation token for this execution.
  CancellationToken get cancelToken => _requireCancellationToken();

  /// Whether this execution has been cancelled.
  bool get isCancelled => _cancellationToken?.isCancelled ?? false;

  Duration _elapsed;
  AttemptOutcome<T>? _outcome;
  final DateTime? _startedAt;
  final CancellationToken? _cancellationToken;
  final void Function(PipelineEvent event)? _onEvent;
  var _phase = RetryPhase.pending;
  static final _random = math.Random();

  /// Advances the execution attempt count.
  void advanceAttempt() {
    attemptNumber++;
  }

  /// Emits a pipeline event.
  void emit(PipelineEvent event) {
    _onEvent?.call(event);
  }

  /// Throws when the execution has been cancelled.
  void throwIfCancelled() {
    _requireCancellationToken().throwIfCancelled();
  }

  /// Updates the phase exposed by the returned retry future.
  void setPhase(RetryPhase phase) {
    _phase = phase;
  }

  /// Supplies the current runtime time.
  DateTime now() {
    return clock.now();
  }

  /// Waits for a retry delay.
  Future<void> sleep(Duration delay) async {
    final cancellationToken = _requireCancellationToken();
    cancellationToken.throwIfCancelled();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    cancellationToken.throwIfCancelled();
  }

  /// Supplies a random value for delay and jitter calculations.
  double random() {
    return _random.nextDouble();
  }

  /// Applies timeout behavior.
  Future<R> timeout<R>(
    Future<R> future,
    Duration duration,
    TimeoutScope scope,
  ) {
    _requireCancellationToken().throwIfCancelled();
    return future.timeout(
      duration,
      onTimeout: () => throw RetryTimeoutException(scope),
    );
  }

  CancellationToken _requireCancellationToken() {
    final cancellationToken = _cancellationToken;
    if (cancellationToken == null) {
      throw StateError('This retry context is not attached to an execution.');
    }
    return cancellationToken;
  }
}
