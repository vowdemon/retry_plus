import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  group('public composition interfaces', () {
    test('predicates expose OR AND and NOT operators directly', () {
      final retry = RetryPredicate<int>.any();
      final fallback = FallbackPredicate<int>.any();
      final circuit = CircuitFailurePredicate.any();

      expect(retry | RetryPredicate<int>.never(), isA<RetryPredicate<int>>());
      expect(
        fallback & FallbackPredicate<int>.any(),
        isA<FallbackPredicate<int>>(),
      );
      expect(~circuit, isA<CircuitFailurePredicate>());
    });

    test('stop strategies expose OR and AND operators directly', () {
      final stop = StopStrategy.never();

      expect(stop | StopStrategy.afterAttempt(2), isA<StopStrategy>());
      expect(stop & StopStrategy.afterAttempt(2), isA<StopStrategy>());
    });
  });

  group('RetryPolicy', () {
    test('returns a successful async result without retrying', () async {
      var attempts = 0;
      final retryEvents = <RetryEvent<String>>[];

      final result = await RetryPolicy<String>(
        delay: DelayStrategy.none(),
        onRetry: retryEvents.add,
      ).execute(() async {
        attempts++;
        return 'ok';
      });

      expect(result, 'ok');
      expect(attempts, 1);
      expect(retryEvents, isEmpty);
    });

    test('retries retryable exceptions until the operation succeeds', () async {
      var attempts = 0;

      final result = await RetryPolicy<String>(
        stop: StopStrategy.afterAttempt(3),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<String>.exception(),
      ).execute(() async {
        attempts++;
        if (attempts < 3) {
          throw const SocketException('offline');
        }
        return 'ready';
      });

      expect(result, 'ready');
      expect(attempts, 3);
    });

    test('rethrows non-retryable exceptions immediately', () async {
      var attempts = 0;
      final error = StateError('not transient');

      final call = RetryPolicy<String>(
        stop: StopStrategy.afterAttempt(3),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate.exceptionType<SocketException, String>(),
      ).execute(() async {
        attempts++;
        throw error;
      });

      await expectLater(call, throwsA(same(error)));
      expect(attempts, 1);
    });

    test(
      'retries retryable results until a valid result is returned',
      () async {
        var attempts = 0;

        final result = await RetryPolicy<int>(
          stop: StopStrategy.afterAttempt(3),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.result((value) => value < 10),
        ).execute(() async {
          attempts++;
          return attempts == 3 ? 42 : 0;
        });

        expect(result, 42);
        expect(attempts, 3);
      },
    );

    test(
      'throws RetryExhaustedException when retryable results are exhausted',
      () async {
        final call = RetryPolicy<int>(
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.result((value) => value < 10),
        ).execute(() async => 0);

        await expectLater(
          call,
          throwsA(
            isA<RetryExhaustedException<int>>()
                .having((error) => error.lastResult, 'lastResult', 0)
                .having((error) => error.attempts, 'attempts', 2),
          ),
        );
      },
    );

    test(
      'does not wait when beforeElapsed would exceed the time budget',
      () async {
        final clock = FakeClock(DateTime(2026));

        await withFakeClock(clock, () async {
          final call = RetryPolicy<int>(
            stop: StopStrategy.beforeElapsed(const Duration(seconds: 5)),
            delay: DelayStrategy.fixed(const Duration(seconds: 10)),
            retryIf: RetryPredicate<int>.result((value) => value == 0),
          ).execute(() async => 0);

          await expectLater(
            call.timeout(const Duration(milliseconds: 50)),
            throwsA(isA<RetryExhaustedException<int>>()),
          );
        });
      },
    );

    test(
      'computes composed exponential and random delays deterministically',
      () {
        final delay = DelayStrategy.exponential(
              initial: const Duration(milliseconds: 100),
              factor: 2,
              max: const Duration(milliseconds: 250),
            ) +
            DelayStrategy.random(
              min: const Duration(milliseconds: 10),
              max: const Duration(milliseconds: 20),
            );
        final random = SequenceRandom([0.5, 0.5]).nextDouble;

        expect(
          [
            delay.computeDelay(
              RetryContext<Object?>(attemptNumber: 1),
              random,
            ),
            delay.computeDelay(
              RetryContext<Object?>(attemptNumber: 2),
              random,
            ),
          ],
          [
            const Duration(milliseconds: 115),
            const Duration(milliseconds: 215),
          ],
        );
      },
    );

    test('applies full jitter within the exponential delay bound', () async {
      final delay = DelayStrategy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: Jitter.full(),
      );

      expect(
        delay.computeDelay(
          RetryContext<Object?>(attemptNumber: 1),
          SequenceRandom([0.25]).nextDouble,
        ),
        const Duration(milliseconds: 25),
      );
    });

    test('cancels promptly during a retry delay', () async {
      final token = CancellationToken();
      late RetryFuture<String> call;
      var attempts = 0;

      call = RetryPolicy<String>(
        stop: StopStrategy.afterAttempt(3),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<String>.exception(),
        onRetry: (_) {
          call.cancel('stopped');
        },
      ).execute(() async {
        attempts++;
        throw const SocketException('offline');
      }, cancellationToken: token);

      await expectLater(call, throwsA(isA<RetryCancelledException>()));
      expect(attempts, 1);
      expect(call.cancelToken.isCancelled, isTrue);
      expect(identical(call.cancelToken, token), isTrue);
    });

    test('rethrows cancellation without retrying or giving up', () async {
      var attempts = 0;
      final giveUpEvents = <RetryEvent<String>>[];

      final call = RetryPolicy<String>(
        stop: StopStrategy.afterAttempt(3),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<String>.exception(),
        onGiveUp: giveUpEvents.add,
      ).execute(() async {
        attempts++;
        throw const RetryCancelledException('stopped');
      });

      await expectLater(call, throwsA(isA<RetryCancelledException>()));
      expect(attempts, 1);
      expect(giveUpEvents, isEmpty);
    });

    test('emits retry and give-up hooks with attempt metadata', () async {
      final retryAttempts = <int>[];
      final retryDelays = <Duration>[];
      final giveUpAttempts = <int>[];

      final call = RetryPolicy<int>(
        stop: StopStrategy.afterAttempt(2),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<int>.result((value) => value == 0),
        onRetry: (event) {
          retryAttempts.add(event.attemptNumber);
          retryDelays.add(event.nextDelay);
        },
        onGiveUp: (event) {
          giveUpAttempts.add(event.attemptNumber);
        },
      ).execute(() async => 0);

      await expectLater(call, throwsA(isA<RetryExhaustedException<int>>()));
      expect(retryAttempts, [1]);
      expect(retryDelays, [Duration.zero]);
      expect(giveUpAttempts, [2]);
    });

    test('retry event exposes typed attempt outcome', () async {
      final retryOutcomes = <AttemptOutcome<int>>[];

      final result = await RetryPolicy<int>(
        stop: StopStrategy.afterAttempt(2),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<int>.result((value) => value == 0),
        onRetry: (event) {
          retryOutcomes.add(event.outcome);
        },
      ).execute(() async => retryOutcomes.isEmpty ? 0 : 1);

      expect(result, 1);
      expect(
        switch (retryOutcomes.single) {
          AttemptOutcomeResult(:final result) => result,
          AttemptOutcomeError() => fail('expected result outcome'),
        },
        0,
      );
    });

    test('propagates hook failures', () async {
      final hookError = StateError('hook failed');

      final call = RetryPolicy<int>(
        stop: StopStrategy.afterAttempt(2),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<int>.result((value) => value == 0),
        onRetry: (_) => throw hookError,
      ).execute(() async => 0);

      await expectLater(call, throwsA(same(hookError)));
    });

    test(
      'uses the same retry behavior for sync and convenience APIs',
      () async {
        var syncAttempts = 0;
        final syncResult = await RetryPolicy<int>(
          stop: StopStrategy.afterAttempt(2),
          delay: DelayStrategy.none(),
          retryIf: RetryPredicate<int>.exception(),
        ).execute(() {
          syncAttempts++;
          if (syncAttempts == 1) {
            throw StateError('try again');
          }
          return 7;
        });

        var retryAttempts = 0;
        final retryResult = await retry<int>(
          () async {
            retryAttempts++;
            if (retryAttempts == 1) {
              throw StateError('try again');
            }
            return 9;
          },
          attempts: 2,
          delay: DelayStrategy.none(),
        );

        expect(syncResult, 7);
        expect(syncAttempts, 2);
        expect(retryResult, 9);
        expect(retryAttempts, 2);
      },
    );
  });

  group('strategy validation', () {
    test('rejects invalid strategy inputs', () {
      expect(() => StopStrategy.afterAttempt(0), throwsArgumentError);
      expect(
        () => DelayStrategy.fixed(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => DelayStrategy.exponential(
          initial: const Duration(milliseconds: 1),
          factor: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => DelayStrategy.random(
          min: const Duration(milliseconds: 2),
          max: const Duration(milliseconds: 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('retry predicate composition', () {
    test('preserves OR AND and NOT behavior', () {
      final socketError = AttemptOutcome<int>.error(
        const SocketException('offline'),
        StackTrace.current,
      );
      final argumentError = AttemptOutcome<int>.error(
        ArgumentError('bad input'),
        StackTrace.current,
      );
      const retryableResult = AttemptOutcome.result(0);

      final either = RetryPredicate.exceptionType<SocketException, int>() |
          RetryPredicate<int>.result((value) => value == 0);
      final both = RetryPredicate<int>.exception() &
          ~RetryPredicate.exceptionType<ArgumentError, int>();

      expect(either.shouldRetry(socketError), isTrue);
      expect(either.shouldRetry(retryableResult), isTrue);
      expect(both.shouldRetry(socketError), isTrue);
      expect(both.shouldRetry(argumentError), isFalse);
    });
  });

  group('public retry extension points', () {
    test('custom retry predicates control retry decisions', () async {
      var classAttempts = 0;
      final classResult = await RetryPolicy<int>(
        stop: StopStrategy.afterAttempt(2),
        delay: DelayStrategy.none(),
        retryIf: const _RetryZeroResult(),
      ).execute(() async {
        classAttempts++;
        return classAttempts == 1 ? 0 : 7;
      });

      var callbackAttempts = 0;
      final callbackResult = await RetryPolicy<int>(
        stop: StopStrategy.afterAttempt(2),
        delay: DelayStrategy.none(),
        retryIf: RetryPredicate<int>.where(
          (outcome) => switch (outcome) {
            AttemptOutcomeResult(:final result) => result == 0,
            AttemptOutcomeError() => false,
          },
        ),
      ).execute(() async {
        callbackAttempts++;
        return callbackAttempts == 1 ? 0 : 9;
      });

      expect(classResult, 7);
      expect(classAttempts, 2);
      expect(callbackResult, 9);
      expect(callbackAttempts, 2);
    });

    test(
      'custom delay strategies receive context and deterministic random',
      () {
        final randomValues = <double>[];
        final delay = DelayStrategy.custom((context, random) {
          final randomValue = random();
          randomValues.add(randomValue);
          return Duration(
            milliseconds:
                context.attemptNumber * 100 + (randomValue * 8).round(),
          );
        });
        final random = SequenceRandom([0.5, 0.25]).nextDouble;

        final delays = [
          delay.computeDelay(RetryContext<Object?>(attemptNumber: 1), random),
          delay.computeDelay(RetryContext<Object?>(attemptNumber: 2), random),
        ];

        expect(randomValues, [0.5, 0.25]);
        expect(delays, [
          const Duration(milliseconds: 104),
          const Duration(milliseconds: 202),
        ]);
      },
    );

    test('custom stop strategies can inspect next delay metadata', () async {
      final observedNextDelays = <Duration>[];

      final call = RetryPolicy<int>(
        stop: StopStrategy.custom(
          shouldStop: (_) => false,
          shouldStopBeforeDelay: (context, delay) {
            observedNextDelays.add(context.nextDelay);
            expect(delay, context.nextDelay);
            return true;
          },
        ),
        delay: DelayStrategy.fixed(const Duration(milliseconds: 10)),
        retryIf: RetryPredicate<int>.result((value) => value == 0),
      ).execute(() async => 0);

      await expectLater(call, throwsA(isA<RetryExhaustedException<int>>()));
      expect(observedNextDelays, [const Duration(milliseconds: 10)]);
    });

    test('custom jitter implementations and callbacks transform delays', () {
      final context = RetryContext<int>(
        attemptNumber: 1,
        elapsed: Duration.zero,
        outcome: AttemptOutcome.result(0),
      );
      final classDelay = DelayStrategy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: const _FixedJitter(Duration(milliseconds: 12)),
      );
      final callbackDelay = DelayStrategy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: Jitter.custom(
          (baseDelay, random) => Duration(
            milliseconds:
                baseDelay.inMilliseconds ~/ 2 + (random() * 10).round(),
          ),
        ),
      );

      expect(
        classDelay.computeDelay(context, SequenceRandom([0.5]).nextDouble),
        const Duration(milliseconds: 12),
      );
      expect(
        callbackDelay.computeDelay(context, SequenceRandom([0.5]).nextDouble),
        const Duration(milliseconds: 55),
      );
    });
  });
}

final class _RetryZeroResult extends RetryPredicate<int> {
  const _RetryZeroResult();

  @override
  bool shouldRetry(AttemptOutcome<int> outcome) {
    return switch (outcome) {
      AttemptOutcomeResult(:final result) => result == 0,
      AttemptOutcomeError() => false,
    };
  }
}

final class _FixedJitter implements Jitter {
  const _FixedJitter(this.duration);

  final Duration duration;

  @override
  Duration apply(Duration baseDelay, double Function() random) => duration;
}

final class FakeClock {
  FakeClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

Future<T> withFakeClock<T>(
  FakeClock fakeClock,
  Future<T> Function() body,
) {
  return withClock(Clock(fakeClock.now), body);
}

final class SequenceRandom {
  SequenceRandom(this._values);

  final List<double> _values;
  var _index = 0;

  double nextDouble() => _values[_index++];
}
