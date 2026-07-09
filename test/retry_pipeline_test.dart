import 'dart:async';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

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
      final listener = InMemoryTelemetryListener();

      final result = await RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
      ).execute(() async => 1);

      expect(result, 1);
      expect(listener.events.map((event) => event.type), [
        TelemetryEventType.pipelineStarted,
        TelemetryEventType.pipelineSucceeded,
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

    test('applies repeated strategy types as ordered wrappers', () async {
      final trace = <String>[];
      final pipeline = RetryPipeline<int>(
        strategies: [
          _TracingStrategy<int>('retry-like outer', trace),
          _TracingStrategy<int>('retry-like inner', trace),
        ],
      );

      final result = await pipeline.execute(() async {
        trace.add('operation');
        return 42;
      });

      expect(result, 42);
      expect(trace, [
        'enter retry-like outer',
        'enter retry-like inner',
        'operation',
        'exit retry-like inner',
        'exit retry-like outer',
      ]);
    });

    test('custom strategy can read context and emit events', () async {
      final listener = InMemoryTelemetryListener();
      final observations = <String>[];
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [_ObservingStrategy<int>(observations)],
      );

      final result = await withClock(
        Clock.fixed(DateTime(2026, 1, 1, 12)),
        () => pipeline.execute(() async => 5),
      );

      expect(result, 5);
      expect(observations, [
        'elapsed=0:00:00.000000 cancelled=false',
      ]);
      expect(listener.events.map((event) => event.type), [
        TelemetryEventType.pipelineStarted,
        TelemetryEventType.retryScheduled,
        TelemetryEventType.pipelineSucceeded,
      ]);
      expect(listener.events[1].attributes, {'source': 'custom'});
    });

    test('custom strategy sees only pipeline context inside retry attempts',
        () async {
      final listener = InMemoryTelemetryListener();
      final observations = <String>[];
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
          _ObservingStrategy<int>(observations),
        ],
      );

      final result = await pipeline.execute(() {
        attempts++;
        if (attempts == 1) {
          throw StateError('transient');
        }
        return 7;
      });

      expect(result, 7);
      expect(observations, hasLength(2));
      final customEvents = listener.events
          .where((event) => event.source.strategyName == 'observing')
          .toList();
      expect(customEvents, hasLength(2));
      for (final event in customEvents) {
        expect(event.attributes, isNot(contains('attemptNumber')));
        expect(event.attributes, isNot(contains('retryIndex')));
      }
    });

    test('nested retry strategies keep independent attempt sequences',
        () async {
      final outerAttempts = <int>[];
      final innerAttempts = <int>[];
      var operationCalls = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            name: 'outer',
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.where((attempt) {
              outerAttempts.add(attempt.attemptNumber);
              return attempt.outcome is AttemptOutcomeError<int> &&
                  attempt.retryIndex < 1;
            }),
          ),
          RetryStrategy<int>(
            name: 'inner',
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.where((attempt) {
              innerAttempts.add(attempt.attemptNumber);
              return attempt.outcome is AttemptOutcomeError<int> &&
                  attempt.retryIndex < 1;
            }),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          operationCalls++;
          throw StateError('down');
        }),
        throwsA(isA<StateError>()),
      );

      expect(operationCalls, 4);
      expect(outerAttempts, [1, 2]);
      expect(innerAttempts, [1, 2, 1, 2]);
    });

    test('custom pipeline order differs from canonical policy order', () async {
      var customAttempts = 0;
      final customPipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
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
      final policy = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 1,
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
            delay: DelayPolicy.none(),
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

  group('Retry canonical composition', () {
    test('fallback handles open circuit without retrying operation', () async {
      var operationAttempts = 0;
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 2,
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
      final policy = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 1,
        retryIf: RetryIf<int>.result((value) => value == 0),
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
      final policy = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 1,
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

    test('explicit retry wraps timeout for each attempt', () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(1),
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
        ],
      );

      final result = await pipeline.execute(() async {
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
        final listener = InMemoryTelemetryListener();
        Object? fallbackFailure;
        final breaker = CircuitBreaker(
          failureThreshold: 1,
          recoveryDuration: const Duration(minutes: 1),
          failureIf:
              CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
        );
        final pipeline = RetryPipeline<int>(
          telemetry: TelemetryOptions(listeners: [listener]),
          strategies: [
            FallbackStrategy.callback(
              (context) {
                fallbackFailure = context.failure;
                return 99;
              },
              fallbackIf:
                  FallbackPredicate.exceptionType<RetryTimeoutException, int>(),
            ),
            breaker.asStrategy<int>(),
            RetryStrategy<int>(
              delay: DelayPolicy.none(),
              retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                  RetryIf<int>.maxRetries(1),
              onRetry: (event) {
                retryAttempts.add(event.attemptNumber);
              },
              onGiveUp: (event) {
                giveUpAttempts.add(event.attemptNumber);
              },
            ),
            TimeoutStrategy<int>(const Duration(milliseconds: 1)),
          ],
        );

        final result = await pipeline.execute(() async {
          attempts++;
          return Completer<int>().future;
        });

        expect(result, 99);
        expect(attempts, 2);
        expect(retryAttempts, [1]);
        expect(giveUpAttempts, [2]);
        expect(fallbackFailure, isA<RetryTimeoutException>());
        expect(breaker.state, CircuitBreakerState.open);
        expect(listener.events.map((event) => event.type), [
          TelemetryEventType.pipelineStarted,
          TelemetryEventType.timeoutTimedOut,
          TelemetryEventType.retryAttempt,
          TelemetryEventType.retryScheduled,
          TelemetryEventType.timeoutTimedOut,
          TelemetryEventType.retryAttempt,
          TelemetryEventType.retryGiveUp,
          TelemetryEventType.circuitOpened,
          TelemetryEventType.fallbackHandling,
          TelemetryEventType.fallbackApplied,
          TelemetryEventType.pipelineSucceeded,
        ]);
      },
    );
  });

  group('position-scoped timeout and retry ordering', () {
    test('position-scoped timeout inside retry times each attempt', () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(1),
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
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
    });

    test('position-scoped timeout outside retry times whole retry flow',
        () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 10)),
          RetryStrategy<int>(
            delay: DelayPolicy.fixed(const Duration(milliseconds: 20)),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(99),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          throw StateError('down');
        }),
        throwsA(isA<RetryTimeoutException>()),
      );

      expect(attempts, 1);
    });

    test('nested timeout event error identifies producing strategy', () async {
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          TimeoutStrategy<int>(
            const Duration(milliseconds: 20),
            name: 'outer-timeout',
          ),
          TimeoutStrategy<int>(
            const Duration(milliseconds: 1),
            name: 'inner-timeout',
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );

      final timeoutEvents = listener.events
          .where((event) => event.type == TelemetryEventType.timeoutTimedOut)
          .toList();
      expect(timeoutEvents, hasLength(1));
      expect(
        (timeoutEvents.single.error as RetryTimeoutException).strategy,
        'inner-timeout',
      );
      expect(
        timeoutEvents.single.attributes['timeout'],
        const Duration(milliseconds: 1),
      );
    });

    test('generated timeout duration is applied', () async {
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>.generated((context) async {
            await Future<void>.delayed(Duration.zero);
            return const Duration(milliseconds: 1);
          }),
        ],
      );

      await expectLater(
        pipeline.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );
    });

    test('generated null timeout disables timeout for execution', () async {
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>.generated((context) => null),
        ],
      );

      final result = await pipeline.execute(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 7;
      });

      expect(result, 7);
    });

    test('retry outside timeout retries per-attempt timeout failures',
        () async {
      var attempts = 0;
      final retriedTimeouts = <Duration?>[];
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(1),
            onRetry: (event) {
              final outcome = event.outcome;
              if (outcome is AttemptOutcomeError<int>) {
                final error = outcome.error;
                if (error is RetryTimeoutException) {
                  retriedTimeouts.add(error.timeout);
                }
              }
            },
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
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
      expect(retriedTimeouts, [const Duration(milliseconds: 1)]);
    });

    test('timeout outside retry bounds whole retry flow', () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 10)),
          RetryStrategy<int>(
            delay: DelayPolicy.fixed(const Duration(milliseconds: 20)),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(99),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          throw StateError('down');
        }),
        throwsA(isA<RetryTimeoutException>()),
      );

      expect(attempts, 1);
    });

    test('nested retry timeout composition returns outer timeout first',
        () async {
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 18)),
          RetryStrategy<int>(
            delay: DelayPolicy.fixed(const Duration(milliseconds: 5)),
            retryIf: RetryIf.exceptionType<RetryTimeoutException, int>() &
                RetryIf<int>.maxRetries(99),
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 5)),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          return Completer<int>().future;
        }),
        throwsA(isA<RetryTimeoutException>()),
      );

      expect(attempts, lessThanOrEqualTo(2));
    });
  });

  group('Integrated strategy composition', () {
    test('retry wraps rate limiter rejection', () async {
      final limiter = _RejectOnceLimiter();
      var operationAttempts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<RateLimitRejectedException, int>() &
                RetryIf<int>.maxRetries(1),
          ),
          RateLimiterStrategy<int>(limiter),
        ],
      );

      final result = await pipeline.execute(() async {
        operationAttempts++;
        return 1;
      });

      expect(result, 1);
      expect(limiter.acquisitions, 2);
      expect(operationAttempts, 1);
    });

    test('fallback outside timeout handles timeout failure', () async {
      final pipeline = RetryPipeline<int>(
        strategies: [
          FallbackStrategy.value(
            9,
            fallbackIf:
                FallbackPredicate.exceptionType<RetryTimeoutException, int>(),
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
        ],
      );

      final result = await pipeline.execute(() => Completer<int>().future);

      expect(result, 9);
    });

    test('circuit breaker outside timeout counts timeout outcome', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf:
            CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
      );
      final pipeline = RetryPipeline<int>(
        strategies: [
          breaker.asStrategy<int>(),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
        ],
      );

      await expectLater(
        pipeline.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );
      await expectLater(
        pipeline.execute(() async => 1),
        throwsA(isA<CircuitOpenException>()),
      );
    });

    test('hedging wraps timeout so each hedged action gets a timeout',
        () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
          ),
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        if (starts == 1) {
          return Completer<int>().future;
        }
        return 7;
      });

      expect(result, 7);
      expect(starts, 2);
    });

    test('timeout outside hedging bounds the whole hedged flow', () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
          HedgingStrategy<int>(
            delay: const Duration(milliseconds: 20),
            maxHedgedAttempts: 1,
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          starts++;
          return Completer<int>().future;
        }),
        throwsA(isA<RetryTimeoutException>()),
      );
      expect(starts, 1);
    });
  });
}

final class _RejectOnceLimiter implements RateLimiter {
  var acquisitions = 0;

  @override
  FutureOr<RateLimitLease> acquire(RateLimitContext context) {
    acquisitions++;
    if (acquisitions == 1) {
      return RateLimitLease.rejected(
        retryAfter: const Duration(milliseconds: 1),
      );
    }
    return RateLimitLease.acquired();
  }
}

final class _ObservingStrategy<T> extends RetryPipelineStrategy<T> {
  const _ObservingStrategy(this.observations) : super(name: 'observing');

  final List<String> observations;

  @override
  Future<T> execute(
      RetryPipelineContext<T> context, Future<T> Function() next) async {
    observations.add(
      'elapsed=${context.elapsed} '
      'cancelled=${context.isCancelled}',
    );
    await context.telemetry?.emit<T>(
      type: TelemetryEventType.retryScheduled,
      strategyName: name,
      attributes: {'source': 'custom'},
    );
    return next();
  }
}

final class _TracingStrategy<T> extends RetryPipelineStrategy<T> {
  const _TracingStrategy(String name, this.trace) : super(name: name);

  final List<String> trace;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
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
