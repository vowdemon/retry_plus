import 'dart:async';
import 'dart:math' as math;

import 'retry_predicate.dart';

/// Policy that computes the wait before the next attempt.
///
/// Callers can extend this class or use [DelayPolicy.custom] to provide
/// domain-specific delay algorithms.
abstract class DelayPolicy {
  /// Creates a delay policy.
  const DelayPolicy();

  /// No delay.
  static DelayPolicy none() => const _FixedDelayPolicy(Duration.zero);

  /// Fixed [duration] delay.
  static DelayPolicy fixed(Duration duration) {
    _checkNonNegativeDuration(duration, 'duration');
    return _FixedDelayPolicy(duration);
  }

  /// Linear delay of [initial] multiplied by retry index.
  static DelayPolicy linear({required Duration initial, Duration? max}) {
    _checkPositiveDuration(initial, 'initial');
    if (max != null) {
      _checkPositiveDuration(max, 'max');
      if (max < initial) {
        throw ArgumentError.value(max, 'max', 'must be at least initial');
      }
    }
    return _LinearDelayPolicy(initial: initial, max: max);
  }

  /// Exponential delay using [initial] and [factor].
  static DelayPolicy exponential({
    required Duration initial,
    double factor = 2,
    Duration? max,
    Jitter? jitter,
  }) {
    _checkPositiveDuration(initial, 'initial');
    if (factor <= 1) {
      throw ArgumentError.value(factor, 'factor', 'must be greater than 1');
    }
    if (max != null) {
      _checkPositiveDuration(max, 'max');
      if (max < initial) {
        throw ArgumentError.value(max, 'max', 'must be at least initial');
      }
    }
    return _ExponentialDelayPolicy(
      initial: initial,
      factor: factor,
      max: max,
      jitter: jitter,
    );
  }

  /// Random delay between [min] and [max], inclusive of the lower bound.
  static DelayPolicy random({required Duration min, required Duration max}) {
    _checkNonNegativeDuration(min, 'min');
    _checkNonNegativeDuration(max, 'max');
    if (max < min) {
      throw ArgumentError.value(max, 'max', 'must be at least min');
    }
    return _RandomDelayPolicy(min: min, max: max);
  }

  /// Decorrelated jitter delay with mutable state scoped to one execution.
  static DelayPolicy decorrelatedJitter({
    required Duration medianFirstRetryDelay,
    Duration? max,
  }) {
    _checkPositiveDuration(medianFirstRetryDelay, 'medianFirstRetryDelay');
    if (max != null) {
      _checkPositiveDuration(max, 'max');
      if (max < medianFirstRetryDelay) {
        throw ArgumentError.value(
          max,
          'max',
          'must be at least medianFirstRetryDelay',
        );
      }
    }
    return _DecorrelatedJitterDelayPolicy(
      medianFirstRetryDelay: medianFirstRetryDelay,
      max: max,
    );
  }

  /// Creates a delay policy from [compute].
  static DelayPolicy custom(
    Duration Function(
      RetryAttemptContext<Object?> context,
      double Function() random,
    ) compute,
  ) {
    return _CustomDelayPolicy(compute);
  }

  /// Creates an attempt-aware delay policy from [compute].
  static DelayPolicy generated(
    FutureOr<Duration?> Function(
      RetryAttemptContext<Object?> attempt,
      double Function() random,
    ) compute,
  ) {
    return _GeneratedDelayPolicy(compute);
  }

  /// Computes a retry delay for [context].
  FutureOr<Duration?> compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  );

  /// Adds two computed delays together.
  DelayPolicy operator +(DelayPolicy other) {
    return _SumDelayPolicy(this, other);
  }

  /// Uses [fallback] when this policy produces no delay.
  DelayPolicy fallbackTo(DelayPolicy fallback) {
    return _FallbackDelayPolicy(this, fallback);
  }
}

/// Jitter applied to a computed delay.
///
/// Callers can implement this interface or use [Jitter.custom] to provide
/// domain-specific jitter algorithms.
abstract interface class Jitter {
  /// Computes jittered delay from [baseDelay].
  Duration compute(Duration baseDelay, double Function() random);

  /// Full jitter between zero and the computed delay.
  factory Jitter.full() = _FullJitter;

  /// Creates jitter from [compute].
  factory Jitter.custom(
    Duration Function(Duration baseDelay, double Function() random) compute,
  ) = _CustomJitter;
}

final class _FullJitter implements Jitter {
  const _FullJitter();

  @override
  Duration compute(Duration baseDelay, double Function() random) {
    return _scaleDuration(baseDelay, random());
  }
}

final class _CustomJitter implements Jitter {
  const _CustomJitter(this._compute);

  final Duration Function(Duration baseDelay, double Function() random)
      _compute;

  @override
  Duration compute(Duration baseDelay, double Function() random) {
    return _compute(baseDelay, random);
  }
}

final class _FixedDelayPolicy extends DelayPolicy {
  const _FixedDelayPolicy(this.duration);

  final Duration duration;

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    return duration;
  }
}

final class _LinearDelayPolicy extends DelayPolicy {
  const _LinearDelayPolicy({required this.initial, this.max});

  final Duration initial;
  final Duration? max;

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    final delay = initial * context.attemptNumber;
    return _clampDuration(delay, max);
  }
}

final class _ExponentialDelayPolicy extends DelayPolicy {
  const _ExponentialDelayPolicy({
    required this.initial,
    required this.factor,
    this.max,
    this.jitter,
  });

  final Duration initial;
  final double factor;
  final Duration? max;
  final Jitter? jitter;

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    final exponent = context.attemptNumber - 1;
    final scaled = _scaleDuration(
      initial,
      math.pow(factor, exponent).toDouble(),
    );
    final clamped = _clampDuration(scaled, max);
    return jitter?.compute(clamped, random) ?? clamped;
  }
}

final class _RandomDelayPolicy extends DelayPolicy {
  const _RandomDelayPolicy({required this.min, required this.max});

  final Duration min;
  final Duration max;

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    final range = max.inMicroseconds - min.inMicroseconds;
    final micros = min.inMicroseconds + (range * random()).round();
    return Duration(microseconds: micros);
  }
}

final class _DecorrelatedJitterDelayPolicy extends DelayPolicy {
  _DecorrelatedJitterDelayPolicy({
    required this.medianFirstRetryDelay,
    this.max,
  });

  final Duration medianFirstRetryDelay;
  final Duration? max;
  final Expando<int> _previousDelayMicros = Expando<int>();

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    final baseMicros = medianFirstRetryDelay.inMicroseconds;
    final previousMicros =
        _previousDelayMicros[context.pipelineContext] ?? baseMicros;
    final upperMicros = math.max(baseMicros, previousMicros * 3);
    final jitteredMicros =
        baseMicros + ((upperMicros - baseMicros) * random()).round();
    _previousDelayMicros[context.pipelineContext] = jitteredMicros;
    return _clampDuration(Duration(microseconds: jitteredMicros), max);
  }
}

final class _CustomDelayPolicy extends DelayPolicy {
  const _CustomDelayPolicy(this._compute);

  final Duration Function(
    RetryAttemptContext<Object?> context,
    double Function() random,
  ) _compute;

  @override
  Duration compute<T>(
    RetryAttemptContext<T> context,
    double Function() random,
  ) {
    final duration = _compute(context as RetryAttemptContext<Object?>, random);
    _checkNonNegativeDuration(duration, 'custom delay');
    return duration;
  }
}

final class _GeneratedDelayPolicy extends DelayPolicy {
  const _GeneratedDelayPolicy(this._compute);

  final FutureOr<Duration?> Function(
    RetryAttemptContext<Object?> attempt,
    double Function() random,
  ) _compute;

  @override
  FutureOr<Duration?> compute<T>(
    RetryAttemptContext<T> attempt,
    double Function() random,
  ) async {
    final duration = await _compute(
      attempt as RetryAttemptContext<Object?>,
      random,
    );
    if (duration != null) {
      _checkNonNegativeDuration(duration, 'generated delay');
    }
    return duration;
  }
}

final class _SumDelayPolicy extends DelayPolicy {
  const _SumDelayPolicy(this.left, this.right);

  final DelayPolicy left;
  final DelayPolicy right;

  @override
  FutureOr<Duration?> compute<T>(
    RetryAttemptContext<T> attempt,
    double Function() random,
  ) async {
    final leftDelay = await left.compute(attempt, random);
    final rightDelay = await right.compute(attempt, random);
    if (leftDelay == null || rightDelay == null) {
      return null;
    }
    return leftDelay + rightDelay;
  }
}

final class _FallbackDelayPolicy extends DelayPolicy {
  const _FallbackDelayPolicy(this.primary, this.fallback);

  final DelayPolicy primary;
  final DelayPolicy fallback;

  @override
  FutureOr<Duration?> compute<T>(
    RetryAttemptContext<T> attempt,
    double Function() random,
  ) async {
    final primaryDelay = await primary.compute(attempt, random);
    if (primaryDelay != null) {
      return primaryDelay;
    }
    return fallback.compute(attempt, random);
  }
}

void _checkNonNegativeDuration(Duration duration, String name) {
  if (duration < Duration.zero) {
    throw ArgumentError.value(duration, name, 'must not be negative');
  }
}

void _checkPositiveDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, name, 'must be positive');
  }
}

Duration _scaleDuration(Duration duration, double factor) {
  return Duration(microseconds: (duration.inMicroseconds * factor).round());
}

Duration _clampDuration(Duration duration, Duration? max) {
  if (max != null && duration > max) {
    return max;
  }
  return duration;
}
