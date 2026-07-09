import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('fallback strategy', () {
    test('does not handle cancellation even with fallback any', () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.any(),
        ),
      );

      await expectLater(
        policy.execute(
          () async => throw const RetryCancelledException('stopped'),
        ),
        throwsA(isA<RetryCancelledException>()),
      );
    });

    test('callback receives final failure context', () async {
      Object? capturedFailure;
      Object? capturedHelperError;
      final policy = Retry<int>(
        retry: RetryStrategy<int>(
          delay: DelayPolicy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(0),
        ),
        fallback: FallbackStrategy.callback((context) {
          capturedFailure = context.failure;
          capturedHelperError = context.error;
          return 3;
        }),
      );

      final result = await policy.execute(() async => throw StateError('down'));

      expect(result, 3);
      expect(capturedFailure, isA<StateError>());
      expect(capturedHelperError, same(capturedFailure));
    });

    test('default fallback handles exceptions but not successful results',
        () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(3),
      );

      expect(await policy.execute(() async => 1), 1);
      expect(await policy.execute(() async => throw StateError('down')), 3);
    });

    test('value handles matching result outcome', () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.result((value) => value == 0),
        ),
      );

      final result = await policy.execute(() async => 0);

      expect(result, 3);
    });

    test('explicit fallback any handles successful results', () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.any(),
        ),
      );

      final result = await policy.execute(() async => 1);

      expect(result, 3);
    });

    test('callback receives final result outcome context', () async {
      StrategyOutcome<int>? capturedOutcome;
      int? capturedResult;
      final policy = Retry<int>(
        fallback: FallbackStrategy.callback(
          (context) {
            capturedOutcome = context.outcome;
            capturedResult = context.result;
            return 3;
          },
          fallbackIf: FallbackPredicate<int>.result((value) => value == 0),
        ),
      );

      final result = await policy.execute(() async => 0);

      expect(result, 3);
      expect(
        switch (capturedOutcome) {
          StrategyOutcomeResult<int>(:final result) => result,
          StrategyOutcomeError<int>() => fail('expected result outcome'),
          null => fail('expected fallback outcome'),
        },
        0,
      );
      expect(capturedResult, 0);
    });

    test('cancellation bypasses custom fallback predicate', () async {
      var evaluated = false;
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.where((context) {
            evaluated = true;
            return true;
          }),
        ),
      );

      await expectLater(
        policy.execute(
          () async => throw const RetryCancelledException('stopped'),
        ),
        throwsA(isA<RetryCancelledException>()),
      );
      expect(evaluated, isFalse);
    });

    test('async fallback callback completes with fallback result', () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.callback((context) async {
          await Future<void>.delayed(Duration.zero);
          return 3;
        }),
      );

      final result = await policy.execute(() async => throw StateError('down'));

      expect(result, 3);
    });

    test('onFallback hook is awaited before fallback result', () async {
      final order = <String>[];
      final listener = InMemoryTelemetryListener();
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.result((value) => value == 0),
          onFallback: (context) async {
            await Future<void>.delayed(Duration.zero);
            order.add('hook');
            expect(context.outcome, isA<StrategyOutcomeResult<int>>());
          },
        ),
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      final result = await policy.execute(() async => 0);
      order.add('result');

      expect(result, 3);
      expect(order, ['hook', 'result']);
      expect(
        listener.events.map((event) => event.type),
        containsAllInOrder([
          TelemetryEventType.fallbackHandling,
          TelemetryEventType.fallbackApplied,
        ]),
      );
    });

    test('fallback failed telemetry is emitted for callback failure', () async {
      final listener = InMemoryTelemetryListener();
      final fallbackError = StateError('fallback failed');
      final policy = Retry<int>(
        fallback: FallbackStrategy.callback(
          (_) => throw fallbackError,
          fallbackIf: FallbackPredicate<int>.result((value) => value == 0),
        ),
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await expectLater(
        policy.execute(() async => 0),
        throwsA(same(fallbackError)),
      );

      final failed = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.fallbackFailed,
      );
      expect(failed.error, same(fallbackError));
    });

    test('non-matching failure is propagated', () async {
      final error = StateError('down');
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate.exceptionType<ArgumentError, int>(),
        ),
      );

      await expectLater(
        policy.execute(() async => throw error),
        throwsA(same(error)),
      );
    });

    test('fallback predicates support OR AND and NOT composition', () async {
      final handlesStateOrArgument =
          FallbackPredicate.exceptionType<StateError, int>() |
              FallbackPredicate.exceptionType<ArgumentError, int>();
      final excludesState = FallbackPredicate<int>.any() &
          ~FallbackPredicate.exceptionType<StateError, int>();

      final statePolicy = Retry<int>(
        fallback: FallbackStrategy.value(3, fallbackIf: handlesStateOrArgument),
      );
      final excludedPolicy = Retry<int>(
        fallback: FallbackStrategy.value(3, fallbackIf: excludesState),
      );

      expect(
        await statePolicy.execute(() async => throw StateError('down')),
        3,
      );
      await expectLater(
        excludedPolicy.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );
    });

    test('custom predicates control fallback handling', () async {
      final classPolicy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: const _FallbackOnMessage('class handled'),
        ),
      );
      final callbackPolicy = Retry<int>(
        fallback: FallbackStrategy.value(
          5,
          fallbackIf: FallbackPredicate<int>.where(
            (context) => context.failure.toString().contains('callback'),
          ),
        ),
      );

      expect(
        await classPolicy.execute(
          () async => throw StateError('class handled'),
        ),
        3,
      );
      expect(
        await callbackPolicy.execute(() async => throw StateError('callback')),
        5,
      );
    });

    test('async custom predicate controls fallback handling', () async {
      final policy = Retry<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: FallbackPredicate<int>.where((context) async {
            await Future<void>.delayed(Duration.zero);
            return context.failure.toString().contains('async handled');
          }),
        ),
      );

      expect(
        await policy.execute(() async => throw StateError('async handled')),
        3,
      );
    });

    test(
      'custom predicates compose with built-in fallback predicates',
      () async {
        final predicate = const _FallbackOnMessage('transient') &
            FallbackPredicate.exceptionType<StateError, int>() &
            ~FallbackPredicate.exceptionType<ArgumentError, int>();
        final policy = Retry<int>(
          fallback: FallbackStrategy.value(3, fallbackIf: predicate),
        );

        expect(
          await policy.execute(() async => throw StateError('transient')),
          3,
        );
        await expectLater(
          policy.execute(() async => throw ArgumentError('transient')),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}

final class _FallbackOnMessage extends FallbackPredicate<int> {
  const _FallbackOnMessage(this.text);

  final String text;

  @override
  bool shouldHandle(FallbackContext<int> context) {
    return context.failure.toString().contains(text);
  }
}
