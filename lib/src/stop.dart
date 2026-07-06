import 'predicate.dart';
import 'retry_context.dart';

/// Strategy that decides when retrying must stop.
///
/// Callers can extend this class or use [StopStrategy.custom] to provide
/// domain-specific stop rules.
abstract class StopStrategy
    implements OrComposable<StopStrategy>, AndComposable<StopStrategy> {
  /// Creates a stop strategy.
  const StopStrategy();

  /// Never stops on its own.
  factory StopStrategy.never() = _NeverStopStrategy;

  /// Stops after [attempts] total attempts.
  factory StopStrategy.afterAttempt(int attempts) {
    if (attempts < 1) {
      throw ArgumentError.value(attempts, 'attempts', 'must be at least 1');
    }
    return _AfterAttemptStopStrategy(attempts);
  }

  /// Stops when elapsed time is greater than or equal to [duration].
  factory StopStrategy.afterElapsed(Duration duration) {
    _checkNonNegativeDuration(duration, 'duration');
    return _AfterElapsedStopStrategy(duration);
  }

  /// Stops before waiting when the next delay would exceed [duration].
  factory StopStrategy.beforeElapsed(Duration duration) {
    _checkNonNegativeDuration(duration, 'duration');
    return _BeforeElapsedStopStrategy(duration);
  }

  /// Creates a stop strategy from callbacks.
  factory StopStrategy.custom({
    required bool Function(RetryContext<Object?> context) shouldStop,
    bool Function(RetryContext<Object?> context, Duration delay)?
    shouldStopBeforeDelay,
  }) {
    return _CustomStopStrategy(
      stop: shouldStop,
      shouldStopBeforeDelay: shouldStopBeforeDelay,
    );
  }

  /// Returns true when retrying should stop after the latest attempt.
  bool shouldStop(RetryContext<Object?> context);

  /// Returns true when [delay] should not be scheduled.
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay);

  @override
  StopStrategy addOr(StopStrategy left, StopStrategy right) {
    return _OrStopStrategy(left, right);
  }

  @override
  StopStrategy addAnd(StopStrategy left, StopStrategy right) {
    return _AndStopStrategy(left, right);
  }

  /// Stops when either strategy stops.
  @override
  StopStrategy operator |(StopStrategy other) {
    return addOr(this, other);
  }

  /// Stops when both strategies stop.
  @override
  StopStrategy operator &(StopStrategy other) {
    return addAnd(this, other);
  }
}

final class _NeverStopStrategy extends StopStrategy {
  const _NeverStopStrategy();

  @override
  bool shouldStop(RetryContext<Object?> context) => false;

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return false;
  }
}

final class _AfterAttemptStopStrategy extends StopStrategy {
  const _AfterAttemptStopStrategy(this.attempts);

  final int attempts;

  @override
  bool shouldStop(RetryContext<Object?> context) {
    return context.attemptNumber >= attempts;
  }

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return false;
  }
}

final class _AfterElapsedStopStrategy extends StopStrategy {
  const _AfterElapsedStopStrategy(this.duration);

  final Duration duration;

  @override
  bool shouldStop(RetryContext<Object?> context) {
    return context.elapsed >= duration;
  }

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return false;
  }
}

final class _BeforeElapsedStopStrategy extends StopStrategy {
  const _BeforeElapsedStopStrategy(this.duration);

  final Duration duration;

  @override
  bool shouldStop(RetryContext<Object?> context) {
    return context.elapsed >= duration;
  }

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return context.elapsed + delay > duration;
  }
}

final class _CustomStopStrategy extends StopStrategy {
  const _CustomStopStrategy({
    required this.stop,
    bool Function(RetryContext<Object?> context, Duration delay)?
    shouldStopBeforeDelay,
  }) : stopBeforeDelay = shouldStopBeforeDelay;

  final bool Function(RetryContext<Object?> context) stop;
  final bool Function(RetryContext<Object?> context, Duration delay)?
  stopBeforeDelay;

  @override
  bool shouldStop(RetryContext<Object?> context) => stop(context);

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return stopBeforeDelay?.call(context, delay) ?? false;
  }
}

final class _OrStopStrategy extends StopStrategy {
  const _OrStopStrategy(this.left, this.right);

  final StopStrategy left;
  final StopStrategy right;

  @override
  bool shouldStop(RetryContext<Object?> context) {
    return left.shouldStop(context) || right.shouldStop(context);
  }

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return left.shouldStopBeforeDelay(context, delay) ||
        right.shouldStopBeforeDelay(context, delay);
  }
}

final class _AndStopStrategy extends StopStrategy {
  const _AndStopStrategy(this.left, this.right);

  final StopStrategy left;
  final StopStrategy right;

  @override
  bool shouldStop(RetryContext<Object?> context) {
    return left.shouldStop(context) && right.shouldStop(context);
  }

  @override
  bool shouldStopBeforeDelay(RetryContext<Object?> context, Duration delay) {
    return left.shouldStopBeforeDelay(context, delay) &&
        right.shouldStopBeforeDelay(context, delay);
  }
}

void _checkNonNegativeDuration(Duration duration, String name) {
  if (duration < Duration.zero) {
    throw ArgumentError.value(duration, name, 'must not be negative');
  }
}
