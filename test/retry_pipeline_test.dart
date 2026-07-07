import 'dart:async';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  group('RetryPipeline', () {
    test('empty pipeline preserves operation success', () async {
      final result = await RetryPipeline<int>().execute(() async => 42);

      expect(result, 42);
    });

    test('empty pipeline preserves operation error', () async {
      final error = StateError('raw failure');

      await expectLater(
        RetryPipeline<int>().execute(() async => throw error),
        throwsA(same(error)),
      );
    });

    test('emits ordered pipeline events', () async {
      final events = <PipelineEvent>[];

      final result = await RetryPipeline<int>(
        onEvent: events.add,
      ).execute(() async => 1);

      expect(result, 1);
      expect(events.map((event) => event.type), [
        PipelineEventType.started,
        PipelineEventType.completed,
      ]);
    });

    test('supports multiple ordered pipeline strategies', () async {
      final trace = <String>[];
      final pipeline = RetryPipeline<int>(
        strategies: [
          _TracingStrategy<int>('outer', trace),
          _TracingStrategy<int>('middle', trace),
          _TracingStrategy<int>('inner', trace),
        ],
      );

      final result = await pipeline.execute(() async {
        trace.add('operation');
        return 42;
      });

      expect(result, 42);
      expect(trace, [
        'enter outer',
        'enter middle',
        'enter inner',
        'operation',
        'exit inner',
        'exit middle',
        'exit outer',
      ]);
    });

    test('custom strategy can read context and emit events', () async {
      final events = <PipelineEvent>[];
      final observations = <String>[];
      final pipeline = RetryPipeline<int>(
        onEvent: events.add,
        strategies: [_ObservingStrategy<int>(observations)],
      );

      final result = await withClock(
        Clock.fixed(DateTime(2026, 1, 1, 12)),
        () => pipeline.execute(() async => 5),
      );

      expect(result, 5);
      expect(observations, [
        'attempt=0 elapsed=0:00:00.000000 cancelled=false',
      ]);
      expect(events.map((event) => event.type), [
        PipelineEventType.started,
        PipelineEventType.retry,
        PipelineEventType.completed,
      ]);
      expect(events[1].metadata, {'source': 'custom'});
    });

    test('custom pipeline order differs from canonical policy order', () async {
      var customAttempts = 0;
      final customPipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayStrategy.none(),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
          FallbackStrategy.value(7),
        ],
      );

      final customResult = await customPipeline.execute(() async {
        customAttempts++;
        throw StateError('down');
      });

      var policyAttempts = 0;
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        ),
        fallback: FallbackStrategy.value(7),
      );

      final policyResult = await policy.execute(() async {
        policyAttempts++;
        throw StateError('down');
      });

      expect(customResult, 7);
      expect(customAttempts, 1);
      expect(policyResult, 7);
      expect(policyAttempts, 2);
    });

    test('constructor accepts caller provided built-in strategies', () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          FallbackStrategy.value(7),
          RetryStrategy<int>(
            delay: DelayStrategy.none(),
            retryIf: RetryIf<int>.result((value) => value == 0) &
                RetryIf<int>.maxRetries(1),
          ),
        ],
      );

      final result = await pipeline.execute(() async {
        attempts++;
        return 0;
      });

      expect(result, 0);
      expect(attempts, 2);
    });
  });

  group('RetryPolicy canonical composition', () {
    test('fallback handles open circuit without retrying operation', () async {
      var operationAttempts = 0;
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(2),
        ),
        circuitBreaker: breaker,
        fallback: FallbackStrategy.value(
          7,
          fallbackIf:
              FallbackPredicate.exceptionType<CircuitOpenException, int>(),
        ),
      );

      await expectLater(
        policy.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );

      final recovered = await policy.execute(() async {
        operationAttempts++;
        return 1;
      });

      expect(recovered, 7);
      expect(operationAttempts, 0);
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('fallback does not handle final retry result', () async {
      var attempts = 0;
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.result((value) => value == 0) &
              RetryIf<int>.maxRetries(1),
        ),
        fallback: FallbackStrategy.value(9),
      );

      final result = await policy.execute(() async {
        attempts++;
        return 0;
      });

      expect(result, 0);
      expect(attempts, 2);
    });

    test('fallback callback failure is not retried', () async {
      var attempts = 0;
      final fallbackError = StateError('fallback failed');
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        ),
        fallback: FallbackStrategy.callback((_) => throw fallbackError),
      );

      await expectLater(
        policy.execute(() async {
          attempts++;
          throw StateError('down');
        }),
        throwsA(same(fallbackError)),
      );
      expect(attempts, 2);
    });

    test('retry wraps per-attempt timeout', () async {
      var attempts = 0;
      final policy = RetryPolicy<int>(
        timeout: TimeoutStrategy.perAttempt(const Duration(milliseconds: 1)),
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
              RetryIf<int>.maxRetries(1),
        ),
      );

      final result = await policy.execute(() async {
        attempts++;
        if (attempts == 1) {
          return Completer<int>().future;
        }
        return 5;
      });

      expect(result, 5);
      expect(attempts, 2);
    });

    test(
      'fallback handles retry exhaustion after per-attempt timeouts and opens circuit once',
      () async {
        var attempts = 0;
        final retryAttempts = <int>[];
        final giveUpAttempts = <int>[];
        final pipelineEvents = <PipelineEvent>[];
        Object? fallbackFailure;
        final breaker = CircuitBreakerStrategy(
          failureThreshold: 1,
          recoveryDuration: const Duration(minutes: 1),
          failureIf:
              CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
        );
        final policy = RetryPolicy<int>(
          retry: RetryStrategy<int>(
            delay: DelayStrategy.none(),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(1),
            onRetry: (event) {
              retryAttempts.add(event.attemptNumber);
            },
            onGiveUp: (event) {
              giveUpAttempts.add(event.attemptNumber);
            },
          ),
          timeout: TimeoutStrategy.perAttempt(const Duration(milliseconds: 1)),
          circuitBreaker: breaker,
          fallback: FallbackStrategy.callback(
            (context) {
              fallbackFailure = context.failure;
              return 99;
            },
            fallbackIf:
                FallbackPredicate.exceptionType<RetryTimeoutException, int>(),
          ),
          onEvent: pipelineEvents.add,
        );

        final result = await policy.execute(() async {
          attempts++;
          return Completer<int>().future;
        });

        expect(result, 99);
        expect(attempts, 2);
        expect(retryAttempts, [1]);
        expect(giveUpAttempts, [2]);
        expect(fallbackFailure, isA<RetryTimeoutException>());
        expect(breaker.state, CircuitBreakerState.open);
        expect(pipelineEvents.map((event) => event.type), [
          PipelineEventType.started,
          PipelineEventType.timeout,
          PipelineEventType.retry,
          PipelineEventType.timeout,
          PipelineEventType.giveUp,
          PipelineEventType.circuitOpened,
          PipelineEventType.fallback,
          PipelineEventType.completed,
        ]);
      },
    );
  });

  group('Polly-style timeout and retry ordering', () {
    test('retry outside timeout retries per-attempt timeout failures',
        () async {
      var attempts = 0;
      final retriedTimeoutScopes = <TimeoutScope>[];
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayStrategy.none(),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(1),
            onRetry: (event) {
              final outcome = event.outcome;
              if (outcome is AttemptOutcomeError<int>) {
                final error = outcome.error;
                if (error is RetryTimeoutException) {
                  retriedTimeoutScopes.add(error.scope);
                }
              }
            },
          ),
          TimeoutStrategy<int>.perAttempt(const Duration(milliseconds: 1)),
        ],
      );

      final result = await pipeline.execute(() {
        attempts++;
        if (attempts == 1) {
          return Completer<int>().future;
        }
        return 5;
      });

      expect(result, 5);
      expect(attempts, 2);
      expect(retriedTimeoutScopes, [TimeoutScope.perAttempt]);
    });

    test('timeout outside retry stops pending retry attempts', () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>.overall(const Duration(milliseconds: 10)),
          RetryStrategy<int>(
            delay: DelayStrategy.fixed(const Duration(milliseconds: 20)),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(99),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          throw StateError('down');
        }),
        throwsA(
          isA<RetryTimeoutException>().having(
            (error) => error.scope,
            'scope',
            TimeoutScope.overall,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(attempts, 1);
    });

    test('outer timeout stops retry around inner per-attempt timeout',
        () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>.overall(const Duration(milliseconds: 18)),
          RetryStrategy<int>(
            delay: DelayStrategy.fixed(const Duration(milliseconds: 5)),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(99),
          ),
          TimeoutStrategy<int>.perAttempt(const Duration(milliseconds: 5)),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          return Completer<int>().future;
        }),
        throwsA(
          isA<RetryTimeoutException>().having(
            (error) => error.scope,
            'scope',
            TimeoutScope.overall,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(attempts, lessThanOrEqualTo(2));
    });
  });
}

final class _ObservingStrategy<T> implements RetryPipelineStrategy<T> {
  const _ObservingStrategy(this.observations);

  final List<String> observations;

  @override
  Future<T> execute(RetryContext<T> context, Future<T> Function() next) {
    observations.add(
      'attempt=${context.attemptNumber} '
      'elapsed=${context.elapsed} '
      'cancelled=${context.isCancelled}',
    );
    context.emit(
      const PipelineEvent(
        type: PipelineEventType.retry,
        metadata: {'source': 'custom'},
      ),
    );
    return next();
  }
}

final class _TracingStrategy<T> implements RetryPipelineStrategy<T> {
  const _TracingStrategy(this.name, this.trace);

  final String name;
  final List<String> trace;

  @override
  Future<T> execute(
    RetryContext<T> context,
    Future<T> Function() next,
  ) async {
    trace.add('enter $name');
    try {
      return await next();
    } finally {
      trace.add('exit $name');
    }
  }
}
