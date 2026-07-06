import 'dart:async';

import 'cancellation.dart';
import 'delay.dart';
import 'events.dart';
import 'exceptions.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'retry_context.dart';
import 'retry_predicate.dart';
import 'stop.dart';

/// Retry configuration and pipeline strategy.
final class RetryStrategy<T> implements PipelineStrategy<T> {
  /// Creates a retry strategy.
  RetryStrategy({
    StopStrategy? stop,
    DelayStrategy? delay,
    RetryPredicate<T>? retryIf,
    this.onRetry,
    this.onGiveUp,
  }) : stop = stop ?? StopStrategy.afterAttempt(3),
       delay =
           delay ??
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
    PipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    while (true) {
      context.cancellationToken?.throwIfCancelled();
      context.attemptNumber++;

      late final AttemptOutcome<T> outcome;
      try {
        outcome = AttemptOutcome.result(await next());
      } on RetryCancelledException {
        rethrow;
      } catch (error, stackTrace) {
        if (isCancellationError(error, context.cancellationToken)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        outcome = AttemptOutcome.error(error, stackTrace);
      }

      if (!retryIf.shouldRetry(outcome)) {
        if (outcome.hasError) {
          Error.throwWithStackTrace(outcome.error!, outcome.stackTrace!);
        }
        return outcome.result as T;
      }

      final retryContext = RetryContext<T>(
        attemptNumber: context.attemptNumber,
        elapsed: context.elapsed,
        outcome: outcome,
      );
      final computedDelay = delay.computeDelay(
        retryContext,
        context.runtime.random,
      );
      final nextContext = retryContext.copyWith(nextDelay: computedDelay);

      if (stop.shouldStop(nextContext) ||
          stop.shouldStopBeforeDelay(nextContext, computedDelay)) {
        final event = RetryEvent<T>.giveUp(nextContext);
        onGiveUp?.call(event);
        context.emit(PipelineEvent(type: PipelineEventType.giveUp));
        _throwFinal(
          outcome,
          context.attemptNumber,
          context.elapsed,
          nextContext,
        );
      }

      final event = RetryEvent<T>.retry(nextContext);
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
      await context.runtime.sleeper(computedDelay, context.cancellationToken);
    }
  }

  Never _throwFinal(
    AttemptOutcome<T> outcome,
    int attempts,
    Duration elapsed,
    RetryContext<T> context,
  ) {
    if (outcome.hasError) {
      Error.throwWithStackTrace(outcome.error!, outcome.stackTrace!);
    }
    throw RetryExhaustedException<T>(
      lastResult: outcome.result as T,
      attempts: attempts,
      elapsed: elapsed,
      context: context,
    );
  }
}
