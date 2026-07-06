import 'dart:math' as math;

import 'retry_context.dart';

/// Strategy that computes the wait before the next attempt.
///
/// Callers can extend this class or use [DelayStrategy.custom] to provide
/// domain-specific delay algorithms.
abstract class DelayStrategy {
  /// Creates a delay strategy.
  const DelayStrategy();

  /// No delay.
  static DelayStrategy none() => const _FixedDelayStrategy(Duration.zero);

  /// Fixed [duration] delay.
  static DelayStrategy fixed(Duration duration) {
    _checkNonNegativeDuration(duration, 'duration');
    return _FixedDelayStrategy(duration);
  }

  /// Linear delay of [initial] multiplied by retry index.
  static DelayStrategy linear({required Duration initial, Duration? max}) {
    _checkPositiveDuration(initial, 'initial');
    if (max != null) {
      _checkPositiveDuration(max, 'max');
      if (max < initial) {
        throw ArgumentError.value(max, 'max', 'must be at least initial');
      }
    }
    return _LinearDelayStrategy(initial: initial, max: max);
  }

  /// Exponential delay using [initial] and [factor].
  static DelayStrategy exponential({
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
    return _ExponentialDelayStrategy(
      initial: initial,
      factor: factor,
      max: max,
      jitter: jitter,
    );
  }

  /// Random delay between [min] and [max], inclusive of the lower bound.
  static DelayStrategy random({required Duration min, required Duration max}) {
    _checkNonNegativeDuration(min, 'min');
    _checkNonNegativeDuration(max, 'max');
    if (max < min) {
      throw ArgumentError.value(max, 'max', 'must be at least min');
    }
    return _RandomDelayStrategy(min: min, max: max);
  }

  /// Creates a delay strategy from [compute].
  static DelayStrategy custom(
    Duration Function(RetryContext<Object?> context, double Function() random)
    compute,
  ) {
    return _CustomDelayStrategy(compute);
  }

  /// Computes a retry delay for [context].
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  );

  /// Adds two computed delays together.
  DelayStrategy operator +(DelayStrategy other) {
    return _SumDelayStrategy(this, other);
  }
}

/// Jitter applied to a computed delay.
///
/// Callers can implement this interface or use [Jitter.custom] to provide
/// domain-specific jitter algorithms.
abstract interface class Jitter {
  /// Applies jitter to [baseDelay].
  Duration apply(Duration baseDelay, double Function() random);

  /// Full jitter between zero and the computed delay.
  factory Jitter.full() = _FullJitter;

  /// Creates jitter from [apply].
  factory Jitter.custom(
    Duration Function(Duration baseDelay, double Function() random) apply,
  ) = _CustomJitter;
}

final class _FullJitter implements Jitter {
  const _FullJitter();

  @override
  Duration apply(Duration baseDelay, double Function() random) {
    return _scaleDuration(baseDelay, random());
  }
}

final class _CustomJitter implements Jitter {
  const _CustomJitter(this._apply);

  final Duration Function(Duration baseDelay, double Function() random) _apply;

  @override
  Duration apply(Duration baseDelay, double Function() random) {
    return _apply(baseDelay, random);
  }
}

final class _FixedDelayStrategy extends DelayStrategy {
  const _FixedDelayStrategy(this.duration);

  final Duration duration;

  @override
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    return duration;
  }
}

final class _LinearDelayStrategy extends DelayStrategy {
  const _LinearDelayStrategy({required this.initial, this.max});

  final Duration initial;
  final Duration? max;

  @override
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    final delay = initial * context.attemptNumber;
    return _clampDuration(delay, max);
  }
}

final class _ExponentialDelayStrategy extends DelayStrategy {
  const _ExponentialDelayStrategy({
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
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    final exponent = context.attemptNumber - 1;
    final scaled = _scaleDuration(
      initial,
      math.pow(factor, exponent).toDouble(),
    );
    final clamped = _clampDuration(scaled, max);
    return jitter?.apply(clamped, random) ?? clamped;
  }
}

final class _RandomDelayStrategy extends DelayStrategy {
  const _RandomDelayStrategy({required this.min, required this.max});

  final Duration min;
  final Duration max;

  @override
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    final range = max.inMicroseconds - min.inMicroseconds;
    final micros = min.inMicroseconds + (range * random()).round();
    return Duration(microseconds: micros);
  }
}

final class _CustomDelayStrategy extends DelayStrategy {
  const _CustomDelayStrategy(this._compute);

  final Duration Function(
    RetryContext<Object?> context,
    double Function() random,
  )
  _compute;

  @override
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    final duration = _compute(context, random);
    _checkNonNegativeDuration(duration, 'custom delay');
    return duration;
  }
}

final class _SumDelayStrategy extends DelayStrategy {
  const _SumDelayStrategy(this.left, this.right);

  final DelayStrategy left;
  final DelayStrategy right;

  @override
  Duration computeDelay(
    RetryContext<Object?> context,
    double Function() random,
  ) {
    return left.computeDelay(context, random) +
        right.computeDelay(context, random);
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
