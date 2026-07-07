import 'dart:async';

import 'cancellation.dart';
import 'delay.dart';
import 'events.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'retry_context.dart';
import 'retry_future.dart';
import 'retry_predicate.dart';

/// Retry configuration and pipeline strategy.
final class RetryStrategy<T> implements RetryPipelineStrategy<T> {
  /// Creates a retry strategy.
  RetryStrategy({
    DelayStrategy? delay,
    RetryIf<T>? retryIf,
    this.onRetry,
    this.onGiveUp,
  })  : delay = delay ??
            DelayStrategy.exponential(
              initial: const Duration(milliseconds: 200),
              max: const Duration(seconds: 5),
            ),
        retryIf =
            retryIf ?? (RetryIf<T>.exception() & RetryIf<T>.maxRetries(3));

  /// Strategy that computes the wait before the next attempt.
  final DelayStrategy delay;

  /// Predicate that decides whether an outcome should be retried.
  final RetryIf<T> retryIf;

  /// Called when the policy schedules another attempt.
  final FutureOr<void> Function(RetryEvent<T> event)? onRetry;

  /// Called when the policy gives up on a retryable outcome.
  final FutureOr<void> Function(RetryEvent<T> event)? onGiveUp;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    while (true) {
      context.throwIfCancelled();
      context.advanceAttempt();

      late final AttemptOutcome<T> outcome;
      final attemptStartedAt = context.now();
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
      final attemptDuration = context.now().difference(attemptStartedAt);
      context.outcome = outcome;
      context.nextDelay = Duration.zero;

      final attempt = RetryAttempt<T>(
        outcome: outcome,
        context: context,
        retryIndex: context.attemptNumber - 1,
        attemptNumber: context.attemptNumber,
        elapsed: context.elapsed,
        attemptDuration: attemptDuration,
        nextDelay: Duration.zero,
      );
      final decision = await retryIf.evaluate(attempt);

      if (!decision.shouldRetry) {
        return await _completeFinalOutcome(
          context: context,
          outcome: outcome,
          attempt: attempt,
          decision: decision,
        );
      }

      final computedDelay =
          await delay.computeDelayForAttempt(attempt, context.random) ??
              Duration.zero;
      context.nextDelay = computedDelay;

      final retryAttempt = RetryAttempt<T>(
        outcome: outcome,
        context: context,
        retryIndex: context.attemptNumber - 1,
        attemptNumber: context.attemptNumber,
        elapsed: context.elapsed,
        attemptDuration: attemptDuration,
        nextDelay: computedDelay,
      );

      final event = RetryEvent<T>.retry(retryAttempt);
      await onRetry?.call(event);
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

  Future<T> _completeFinalOutcome({
    required RetryContext<T> context,
    required AttemptOutcome<T> outcome,
    required RetryAttempt<T> attempt,
    required RetryDecision decision,
  }) async {
    if (decision.handled) {
      final event = RetryEvent<T>.giveUp(attempt);
      await onGiveUp?.call(event);
      context.emit(PipelineEvent(type: PipelineEventType.giveUp));
    }
    switch (outcome) {
      case AttemptOutcomeResult(:final result):
        return result;
      case AttemptOutcomeError(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
