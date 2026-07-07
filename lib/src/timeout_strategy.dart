import 'cancellation.dart';
import 'events.dart';
import 'exceptions.dart';
import 'pipeline.dart';
import 'retry_context.dart';

/// Timeout scope for timeout strategy failures.
enum TimeoutScope {
  /// Timeout applies to one operation attempt.
  perAttempt,

  /// Timeout applies to the whole pipeline execution.
  overall,
}

/// Strategy that limits execution time.
final class TimeoutStrategy<T> implements RetryPipelineStrategy<T> {
  const TimeoutStrategy._({this.perAttempt, this.overall});

  /// Creates a per-attempt timeout strategy.
  factory TimeoutStrategy.perAttempt(Duration duration) {
    _checkPositiveDuration(duration, 'duration');
    return TimeoutStrategy<T>._(perAttempt: duration);
  }

  /// Creates an overall timeout strategy.
  factory TimeoutStrategy.overall(Duration duration) {
    _checkPositiveDuration(duration, 'duration');
    return TimeoutStrategy<T>._(overall: duration);
  }

  /// Creates a timeout strategy with both scopes.
  factory TimeoutStrategy.combined({Duration? perAttempt, Duration? overall}) {
    if (perAttempt != null) {
      _checkPositiveDuration(perAttempt, 'perAttempt');
    }
    if (overall != null) {
      _checkPositiveDuration(overall, 'overall');
    }
    return TimeoutStrategy<T>._(perAttempt: perAttempt, overall: overall);
  }

  /// Per-attempt timeout duration.
  final Duration? perAttempt;

  /// Overall timeout duration.
  final Duration? overall;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    final duration = perAttempt ?? overall;
    final scope =
        perAttempt != null ? TimeoutScope.perAttempt : TimeoutScope.overall;
    if (duration == null) {
      return next();
    }
    context.throwIfCancelled();
    try {
      return await context.timeout<T>(
        next(),
        duration,
        scope,
      );
    } on RetryTimeoutException catch (error) {
      context.emit(
        PipelineEvent(type: PipelineEventType.timeout, error: error),
      );
      rethrow;
    } on RetryCancelledException {
      rethrow;
    }
  }
}

void _checkPositiveDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration, name, 'must be positive');
  }
}
