import 'dart:async';

import 'cancellation.dart';
import 'delay.dart';
import 'events.dart';
import 'exceptions.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'retry_context.dart';
import 'retry_future.dart';
import 'retry_predicate.dart';
import 'stop.dart';

/// Retry configuration and pipeline strategy.
final class RetryStrategy<T> implements RetryPipelineStrategy<T> {
  /// Creates a retry strategy.
  RetryStrategy({
    StopStrategy? stop,
    DelayStrategy? delay,
    RetryPredicate<T>? retryIf,
    this.onRetry,
    this.onGiveUp,
  })  : stop = stop ?? StopStrategy.afterAttempt(3),
        delay = delay ??
            DelayStrategy.exponential(
              initial: const Duration(milliseconds: 200),
              max: const Duration(seconds: 5),
            ),
        retryIf = retryIf ?? RetryPredicate<T>.exception();

  /// Strategy that decides when retrying must stop.
  final StopStrategy stop;

  /// Strategy that computes the wait before the next attempt.
  final DelayStrategy delay;

  /// Predicate that decides whether an outcome should be retried.
  final RetryPredicate<T> retryIf;

  /// Called when the policy schedules another attempt.
  final void Function(RetryEvent<T> event)? onRetry;

  /// Called when the policy gives up on a retryable outcome.
  final void Function(RetryEvent<T> event)? onGiveUp;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    while (true) {
      context.throwIfCancelled();
      context.advanceAttempt();

      late final AttemptOutcome<T> outcome;
      try {
        outcome = AttemptOutcome.result(await next());
      } on RetryCancelledException {
        rethrow;
      } catch (error, stackTrace) {
        if (isCancellationError(error, context.cancelToken)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        outcome = AttemptOutcome.error(error, stackTrace);
      }
      context.outcome = outcome;
      context.nextDelay = Duration.zero;

      if (!retryIf.shouldRetry(outcome)) {
        return switch (outcome) {
          AttemptOutcomeResult(:final result) => result,
          AttemptOutcomeError(:final error, :final stackTrace) =>
            Error.throwWithStackTrace(error, stackTrace),
        };
      }

      final computedDelay = delay.computeDelay(
        context,
        context.random,
      );
      context.nextDelay = computedDelay;

      if (stop.shouldStop(context) ||
          stop.shouldStopBeforeDelay(context, computedDelay)) {
        final event = RetryEvent<T>.giveUp(context);
        onGiveUp?.call(event);
        context.emit(PipelineEvent(type: PipelineEventType.giveUp));
        _throwFinal(
          outcome,
          context.attemptNumber,
          context.elapsed,
          context,
        );
      }

      final event = RetryEvent<T>.retry(context);
      onRetry?.call(event);
      context.emit(
        PipelineEvent(
          type: PipelineEventType.retry,
          metadata: <String, Object?>{
            'attemptNumber': context.attemptNumber,
            'nextDelay': computedDelay,
          },
        ),
      );
      context.setPhase(RetryPhase.waiting);
      await context.sleep(computedDelay);
    }
  }

  Never _throwFinal(
    AttemptOutcome<T> outcome,
    int attempts,
    Duration elapsed,
    RetryContext<T> context,
  ) {
    switch (outcome) {
      case AttemptOutcomeResult(:final result):
        throw RetryExhaustedException<T>(
          lastResult: result,
          attempts: attempts,
          elapsed: elapsed,
          context: context,
        );
      case AttemptOutcomeError(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
