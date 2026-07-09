import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('InjectionTrigger', () {
    test('rate trigger handles boundary rates', () async {
      final context = RetryPipelineContext<int>();

      expect(await InjectionTrigger<int>.rate(1).shouldHandle(context), isTrue);
      expect(
        await InjectionTrigger<int>.rate(0).shouldHandle(context),
        isFalse,
      );
    });

    test('rate validates bounds', () {
      expect(() => InjectionTrigger<int>.rate(-0.01), throwsArgumentError);
      expect(() => InjectionTrigger<int>.rate(1.01), throwsArgumentError);
    });

    test('always never custom async and boolean composition', () async {
      final context = RetryPipelineContext<int>();
      var enabled = true;
      final enabledTrigger = InjectionTrigger<int>.where((context) async {
        await Future<void>.delayed(Duration.zero);
        return enabled && !context.isCancelled;
      });
      final never = InjectionTrigger<int>.never();
      final always = InjectionTrigger<int>.always();

      expect(await always.shouldHandle(context), isTrue);
      expect(await never.shouldHandle(context), isFalse);
      expect(await (enabledTrigger & always).shouldHandle(context), isTrue);
      expect(await (enabledTrigger & never).shouldHandle(context), isFalse);
      expect(await (never | enabledTrigger).shouldHandle(context), isTrue);
      expect(await (~never).shouldHandle(context), isTrue);
      enabled = false;
      expect(await enabledTrigger.shouldHandle(context), isFalse);
    });
  });

  group('injection strategies', () {
    test('throw injection emits event and is visible to outer retry', () async {
      final listener = InMemoryTelemetryListener();
      var operationCalls = 0;
      var injected = false;
      final error = _InjectedFailure();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<_InjectedFailure, int>() &
                RetryIf<int>.maxRetries(1),
          ),
          InjectionThrowStrategy<int>(
            name: 'throw-once',
            injectIf: InjectionTrigger<int>.where(
              (_) {
                if (injected) {
                  return false;
                }
                injected = true;
                return true;
              },
            ),
            error: (context) {
              expect(context.elapsed, isA<Duration>());
              return error;
            },
          ),
        ],
      );

      final result = await pipeline.execute(() {
        operationCalls++;
        return 7;
      });

      expect(result, 7);
      expect(operationCalls, 1);
      final injectionEvent = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.injectionThrow,
      );
      expect(injectionEvent.error, same(error));
      expect(injectionEvent.source.strategyName, 'throw-once');
      expect(injectionEvent.attributes['elapsed'], isA<Duration>());
      expect(
        listener.events.map((event) => event.type),
        contains(TelemetryEventType.retryScheduled),
      );
    });

    test('fallback handles throw injection according to pipeline order',
        () async {
      var operationCalls = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          FallbackStrategy.value(
            9,
            fallbackIf:
                FallbackPredicate.exceptionType<_InjectedFailure, int>(),
          ),
          InjectionThrowStrategy<int>(
            error: (_) => _InjectedFailure(),
          ),
        ],
      );

      final result = await pipeline.execute(() {
        operationCalls++;
        return 1;
      });

      expect(result, 9);
      expect(operationCalls, 0);
    });

    test('circuit breaker counts throw injection according to pipeline order',
        () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.exceptionType<_InjectedFailure>(),
      );
      final pipeline = RetryPipeline<int>(
        strategies: [
          breaker.asStrategy<int>(),
          InjectionThrowStrategy<int>(
            error: (_) => _InjectedFailure(),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => 1),
        throwsA(isA<_InjectedFailure>()),
      );
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('delay injection is covered by outer timeout', () async {
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 1)),
          InjectionDelayStrategy<int>(
            name: 'slowdown',
            delay: (_) => const Duration(milliseconds: 20),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => 1),
        throwsA(isA<RetryTimeoutException>()),
      );

      final delayEvent = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.injectionDelay,
      );
      expect(delayEvent.source.strategyName, 'slowdown');
      expect(delayEvent.attributes['delay'], const Duration(milliseconds: 20));
      expect(
        listener.events.map((event) => event.type),
        contains(TelemetryEventType.timeoutTimedOut),
      );
    });

    test('delay injection rejects negative generated delay', () async {
      final pipeline = RetryPipeline<int>(
        strategies: [
          InjectionDelayStrategy<int>(
            delay: (_) => const Duration(milliseconds: -1),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => 1),
        throwsArgumentError,
      );
    });

    test('cancellation during delay prevents inner execution', () async {
      final delayStarted = Completer<void>();
      var operationCalls = 0;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(
          listeners: [
            CallbackTelemetryListener((event) {
              if (event.type == TelemetryEventType.injectionDelay &&
                  !delayStarted.isCompleted) {
                delayStarted.complete();
              }
            }),
          ],
        ),
        strategies: [
          InjectionDelayStrategy<int>(
            delay: (_) => const Duration(milliseconds: 20),
          ),
        ],
      );

      final run = pipeline.execute(() {
        operationCalls++;
        return 1;
      });
      await delayStarted.future;
      run.cancel(const RetryCancelledException('stopped'));

      await expectLater(run, throwsA(isA<RetryCancelledException>()));
      expect(operationCalls, 0);
    });

    test('result injection can be retried and bypasses inner operation',
        () async {
      var operationCalls = 0;
      var injected = false;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.result((value) => value == 0) &
                RetryIf<int>.maxRetries(1),
          ),
          InjectionResultStrategy<int>(
            injectIf: InjectionTrigger<int>.where(
              (_) {
                if (injected) {
                  return false;
                }
                injected = true;
                return true;
              },
            ),
            result: (_) => 0,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        operationCalls++;
        return 1;
      });

      expect(result, 1);
      expect(operationCalls, 1);
    });

    test('behavior injection runs before inner operation', () async {
      final order = <String>[];
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          InjectionBehaviorStrategy<int>(
            name: 'side-effect',
            behavior: (_) async {
              await Future<void>.delayed(Duration.zero);
              order.add('behavior');
            },
          ),
        ],
      );

      final result = await pipeline.execute(() {
        order.add('operation');
        return 1;
      });

      expect(result, 1);
      expect(order, ['behavior', 'operation']);
      final behaviorEvent = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.injectionBehavior,
      );
      expect(behaviorEvent.source.strategyName, 'side-effect');
    });

    test('behavior injection failure propagates', () async {
      final error = StateError('behavior failed');
      final pipeline = RetryPipeline<int>(
        strategies: [
          InjectionBehaviorStrategy<int>(
            behavior: (_) => throw error,
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => 1),
        throwsA(same(error)),
      );
    });

    test(
        'skipped injection invokes inner pipeline and emits no injection event',
        () async {
      final listener = InMemoryTelemetryListener();
      var operationCalls = 0;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          InjectionResultStrategy<int>(
            injectIf: InjectionTrigger<int>.never(),
            result: (_) => 0,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        operationCalls++;
        return 1;
      });

      expect(result, 1);
      expect(operationCalls, 1);
      expect(
        listener.events.map((event) => event.type),
        isNot(contains(TelemetryEventType.injectionResult)),
      );
    });

    test('result injection outside hedging bypasses hedged execution',
        () async {
      final listener = InMemoryTelemetryListener();
      var operationCalls = 0;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          InjectionResultStrategy<int>(result: (_) => 5),
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        operationCalls++;
        return 1;
      });

      expect(result, 5);
      expect(operationCalls, 0);
      expect(
        listener.events.map((event) => event.type),
        isNot(contains(TelemetryEventType.hedgingScheduled)),
      );
    });
  });
}

final class _InjectedFailure implements Exception {}
