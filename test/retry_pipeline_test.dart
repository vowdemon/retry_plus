import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

import 'test_support.dart';

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
      final runtime = RetryRuntime(observer: events.add);

      final result = await RetryPipeline<int>(
        runtime: runtime,
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
      final runtime = RetryRuntime(
        clock: () => DateTime(2026, 1, 1, 12),
        observer: events.add,
      );
      final pipeline = RetryPipeline<int>(
        runtime: runtime,
        strategies: [_ObservingStrategy<int>(observations)],
      );

      final result = await pipeline.execute(() async => 5);

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
            stop: StopStrategy.afterAttempt(2),
            delay: DelayStrategy.none(),
            retryIf: RetryPredicate<int>.exception(),
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
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.exception(),
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
            stop: StopStrategy.afterAttempt(2),
            delay: DelayStrategy.none(),
            retryIf: RetryPredicate<int>.result((value) => value == 0),
          ),
        ],
      );

      final result = await pipeline.execute(() async {
        attempts++;
        return 0;
      });

      expect(result, 7);
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
          stop: StopStrategy.afterAttempt(3),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.exception(),
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

    test('fallback handles retry exhaustion', () async {
      var attempts = 0;
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.result((value) => value == 0),
        ),
        fallback: FallbackStrategy.value(9),
      );

      final result = await policy.execute(() async {
        attempts++;
        return 0;
      });

      expect(result, 9);
      expect(attempts, 2);
    });

    test('fallback callback failure is not retried', () async {
      var attempts = 0;
      final fallbackError = StateError('fallback failed');
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.result((value) => value == 0),
        ),
        fallback: FallbackStrategy.callback((_) => throw fallbackError),
      );

      await expectLater(
        policy.execute(() async {
          attempts++;
          return 0;
        }),
        throwsA(same(fallbackError)),
      );
      expect(attempts, 2);
    });

    test('retry wraps per-attempt timeout', () async {
      var attempts = 0;
      final runtime = FakeRuntime();
      final policy = RetryPolicy<int>(
        timeout: TimeoutStrategy.perAttempt(const Duration(seconds: 1)),
        retry: RetryStrategy<int>(
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate.exceptionType<RetryTimeoutException, int>(),
        ),
        runtime: runtime.value,
      );

      final result = await policy.execute(() async {
        attempts++;
        if (attempts == 1) {
          return runtime.timeoutOperation<int>();
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
        final retryEvents = <RetryEvent<int>>[];
        final giveUpEvents = <RetryEvent<int>>[];
        final pipelineEvents = <PipelineEvent>[];
        Object? fallbackFailure;
        final runtime = FakeRuntime(
          timeoutScopesToThrow: [
            TimeoutScope.perAttempt,
            TimeoutScope.perAttempt,
          ],
        );
        final breaker = CircuitBreakerStrategy(
          failureThreshold: 1,
          recoveryDuration: const Duration(minutes: 1),
          failureIf:
              CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
        );
        final policy = RetryPolicy<int>(
          retry: RetryStrategy<int>(
            stop: StopStrategy.afterAttempt(2),
            delay: DelayStrategy.none(),
            retryIf: RetryPredicate.exceptionType<RetryTimeoutException, int>(),
            onRetry: retryEvents.add,
            onGiveUp: giveUpEvents.add,
          ),
          timeout: TimeoutStrategy.perAttempt(const Duration(seconds: 1)),
          circuitBreaker: breaker,
          fallback: FallbackStrategy.callback(
            (context) {
              fallbackFailure = context.failure;
              return 99;
            },
            fallbackIf:
                FallbackPredicate.exceptionType<RetryTimeoutException, int>(),
          ),
          runtime: RetryRuntime(
            clock: runtime.clock.now,
            sleeper: runtime.sleep,
            timeout: runtime.timeout,
            random: SequenceRandom([0.5]).nextDouble,
            observer: pipelineEvents.add,
          ),
        );

        final result = await policy.execute(() async {
          attempts++;
          return attempts;
        });

        expect(result, 99);
        expect(attempts, 2);
        expect(runtime.timeouts, [
          TimeoutScope.perAttempt,
          TimeoutScope.perAttempt,
        ]);
        expect(retryEvents, hasLength(1));
        expect(retryEvents.single.attemptNumber, 1);
        expect(giveUpEvents, hasLength(1));
        expect(giveUpEvents.single.attemptNumber, 2);
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
}

final class _ObservingStrategy<T> implements PipelineStrategy<T> {
  const _ObservingStrategy(this.observations);

  final List<String> observations;

  @override
  Future<T> execute(PipelineContext<T> context, Future<T> Function() next) {
    observations.add(
      'attempt=${context.attemptNumber} '
      'elapsed=${context.elapsed} '
      'cancelled=${context.cancellationToken?.isCancelled ?? false}',
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

final class _TracingStrategy<T> implements PipelineStrategy<T> {
  const _TracingStrategy(this.name, this.trace);

  final String name;
  final List<String> trace;

  @override
  Future<T> execute(
    PipelineContext<T> context,
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
