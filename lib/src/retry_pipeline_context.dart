import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'cancellation.dart';
import 'exceptions.dart';
import 'retry_future.dart';
import 'telemetry.dart';

/// Context for one retry pipeline execution.
final class RetryPipelineContext<T> {
  /// Creates a detached pipeline context for tests and custom utilities.
  RetryPipelineContext({
    Duration elapsed = Duration.zero,
  })  : _elapsed = elapsed,
        _startedAt = null,
        _cancellationToken = null,
        _telemetry = null;

  /// Creates a context for one pipeline execution.
  RetryPipelineContext.execution({
    required DateTime startedAt,
    required CancellationToken cancellationToken,
    required TelemetrySink telemetry,
  })  : _elapsed = Duration.zero,
        _startedAt = startedAt,
        _cancellationToken = cancellationToken,
        _telemetry = telemetry;

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

  /// Current retry execution phase.
  RetryPhase get phase => _phase;

  /// Effective cancellation token for this execution.
  CancellationToken get cancelToken => _requireCancellationToken();

  /// Telemetry sink for this execution, if this context is attached to one.
  TelemetrySink? get telemetry => _telemetry;

  /// Whether this execution has been cancelled.
  bool get isCancelled =>
      _internalCancellationReason != null ||
      (_cancellationToken?.isCancelled ?? false);

  Duration _elapsed;
  final DateTime? _startedAt;
  final CancellationToken? _cancellationToken;
  final TelemetrySink? _telemetry;
  Object? _internalCancellationReason;
  var _phase = RetryPhase.pending;
  static final _random = math.Random();

  /// Throws when the execution has been cancelled.
  void throwIfCancelled() {
    final internalReason = _internalCancellationReason;
    if (internalReason != null) {
      _throwCancellationReason(internalReason);
    }
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
    Duration duration, {
    String? strategy,
    Object? source,
  }) {
    throwIfCancelled();
    return future.timeout(
      duration,
      onTimeout: () {
        throw RetryTimeoutException(
          strategy: strategy,
          timeout: duration,
          source: source,
        );
      },
    );
  }

  CancellationToken _requireCancellationToken() {
    final cancellationToken = _cancellationToken;
    if (cancellationToken == null) {
      throw StateError(
          'This pipeline context is not attached to an execution.');
    }
    return cancellationToken;
  }

  Never _throwCancellationReason(Object reason) {
    if (reason is Exception || reason is Error) {
      throw reason;
    }
    throw RetryCancelledException(reason.toString());
  }
}
