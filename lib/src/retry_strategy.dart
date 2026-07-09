import 'dart:async';

import 'cancellation.dart';
import 'delay.dart';
import 'outcome.dart';
import 'pipeline.dart';
import 'retry_pipeline_context.dart';
import 'retry_future.dart';
import 'retry_predicate.dart';
import 'telemetry.dart';

/// Retry configuration and pipeline strategy.
final class RetryStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a retry strategy.
  RetryStrategy({
    super.name,
    DelayPolicy? delay,
    RetryIf<T>? retryIf,
    this.onRetry,
    this.onGiveUp,
  })  : delay = delay ??
            DelayPolicy.exponential(
              initial: const Duration(milliseconds: 200),
              max: const Duration(seconds: 5),
            ),
        retryIf =
            retryIf ?? (RetryIf<T>.exception() & RetryIf<T>.maxRetries(3));

  /// Strategy that computes the wait before the next attempt.
  final DelayPolicy delay;

  /// Predicate that decides whether an outcome should be retried.
  final RetryIf<T> retryIf;

  /// Called after retry continuation is accepted and before delay calculation.
  final FutureOr<void> Function(RetryAttemptContext<T> attempt)? onRetry;

  /// Called when the policy gives up on a retryable outcome.
  final FutureOr<void> Function(RetryAttemptContext<T> attempt)? onGiveUp;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    var hasRetried = false;
    var attemptNumber = 0;
    while (true) {
      context.throwIfCancelled();
      attemptNumber++;

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

      final attempt = RetryAttemptContext<T>(
        outcome: outcome,
        pipelineContext: context,
        retryIndex: attemptNumber - 1,
        attemptNumber: attemptNumber,
        elapsed: context.elapsed,
        attemptDuration: attemptDuration,
      );
      final shouldRetry = await retryIf.shouldHandle(attempt);

      if (!shouldRetry) {
        await _emitAttemptTelemetry(
          context: context,
          attempt: attempt,
          handled: false,
        );
        return await _completeFinalOutcome(
          context: context,
          outcome: outcome,
          attempt: attempt,
          shouldGiveUp: hasRetried,
        );
      }

      await _emitAttemptTelemetry(
        context: context,
        attempt: attempt,
        handled: true,
      );
      await onRetry?.call(attempt);

      final computedDelay =
          await delay.compute(attempt, context.random) ?? Duration.zero;
      hasRetried = true;
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.retryScheduled,
        outcome: attempt.strategyOutcome,
        strategyName: name,
        attributes: <String, Object?>{
          'attemptNumber': attempt.attemptNumber,
          'retryIndex': attempt.retryIndex,
          'nextDelay': computedDelay,
        },
      );
      context.setPhase(RetryPhase.waiting);
      await context.sleep(computedDelay);
    }
  }

  Future<T> _completeFinalOutcome({
    required RetryPipelineContext<T> context,
    required AttemptOutcome<T> outcome,
    required RetryAttemptContext<T> attempt,
    required bool shouldGiveUp,
  }) async {
    if (shouldGiveUp) {
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.retryGiveUp,
        outcome: attempt.strategyOutcome,
        strategyName: name,
        error: switch (outcome) {
          AttemptOutcomeError(:final error) => error,
          _ => null,
        },
        stackTrace: switch (outcome) {
          AttemptOutcomeError(:final stackTrace) => stackTrace,
          _ => null,
        },
        attributes: <String, Object?>{
          'attemptNumber': attempt.attemptNumber,
          'retryIndex': attempt.retryIndex,
        },
      );
      await onGiveUp?.call(attempt);
    }
    switch (outcome) {
      case AttemptOutcomeResult(:final result):
        return result;
      case AttemptOutcomeError(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _emitAttemptTelemetry({
    required RetryPipelineContext<T> context,
    required RetryAttemptContext<T> attempt,
    required bool handled,
  }) async {
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.retryAttempt,
      duration: attempt.attemptDuration,
      outcome: attempt.strategyOutcome,
      strategyName: name,
      error: switch (attempt.outcome) {
        AttemptOutcomeError(:final error) => error,
        _ => null,
      },
      stackTrace: switch (attempt.outcome) {
        AttemptOutcomeError(:final stackTrace) => stackTrace,
        _ => null,
      },
      attributes: <String, Object?>{
        'attemptNumber': attempt.attemptNumber,
        'retryIndex': attempt.retryIndex,
        'handled': handled,
      },
    );
  }
}
