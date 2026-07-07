import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  group('unified retry decision', () {
    test('retryIf receives typed attempt metadata', () async {
      final seen = <RetryAttempt<int>>[];

      final result = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.where((attempt) {
          seen.add(attempt);
          return attempt.outcome is AttemptOutcomeResult<int> &&
              attempt.retryIndex == 0;
        }),
      ).execute(() async => seen.isEmpty ? 0 : 7);

      expect(result, 7);
      expect(seen, hasLength(2));
      expect(seen.first.retryIndex, 0);
      expect(seen.first.attemptNumber, 1);
      expect(seen.first.elapsed, isA<Duration>());
      expect(seen.first.attemptDuration, isA<Duration>());
      expect(seen.first.context, isA<RetryContext<int>>());
      expect(seen.first.nextDelay, Duration.zero);
      expect(
        switch (seen.first.outcome) {
          AttemptOutcomeResult(:final result) => result,
          AttemptOutcomeError() => fail('expected result outcome'),
        },
        0,
      );
    });

    test('retryIf supports synchronous and asynchronous callbacks', () async {
      var syncAttempts = 0;
      final syncResult = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.where(
          (attempt) =>
              attempt.outcome is AttemptOutcomeError<int> &&
              attempt.retryIndex < 1,
        ),
      ).execute(() {
        syncAttempts++;
        if (syncAttempts == 1) {
          throw StateError('sync');
        }
        return 3;
      });

      var asyncAttempts = 0;
      final asyncResult = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.where((attempt) async {
          await Future<void>.delayed(Duration.zero);
          return attempt.outcome is AttemptOutcomeError<int> &&
              attempt.retryIndex < 1;
        }),
      ).execute(() {
        asyncAttempts++;
        if (asyncAttempts == 1) {
          throw StateError('async');
        }
        return 5;
      });

      expect(syncResult, 3);
      expect(syncAttempts, 2);
      expect(asyncResult, 5);
      expect(asyncAttempts, 2);
    });

    test('delay supports asynchronous generated durations', () async {
      final observedDelays = <Duration>[];

      final result = await RetryPolicy<int>(
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        delay: DelayStrategy.generated((attempt, random) async {
          await Future<void>.delayed(Duration.zero);
          return Duration(milliseconds: 2 + attempt.retryIndex);
        }),
        onRetry: (event) {
          observedDelays.add(event.nextDelay);
        },
      ).execute(() async => observedDelays.isEmpty ? 0 : 5);

      expect(result, 5);
      expect(observedDelays, [const Duration(milliseconds: 2)]);
    });

    test('generated delay can fall back when it returns null', () async {
      final observedDelays = <Duration>[];

      final result = await RetryPolicy<int>(
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        delay: DelayStrategy.generated((attempt, random) => null)
            .fallbackTo(DelayStrategy.fixed(const Duration(milliseconds: 3))),
        onRetry: (event) {
          observedDelays.add(event.nextDelay);
        },
      ).execute(() async => observedDelays.isEmpty ? 0 : 5);

      expect(result, 5);
      expect(observedDelays, [const Duration(milliseconds: 3)]);
    });

    test('stateful jitter remains scoped to one retry execution', () {
      final delay = DelayStrategy.decorrelatedJitter(
        medianFirstRetryDelay: const Duration(milliseconds: 100),
      );
      final firstContext = RetryContext<Object?>(attemptNumber: 1);
      final secondContext = RetryContext<Object?>(attemptNumber: 1);
      final firstRandom = SequenceRandom([0.5, 0.5]).nextDouble;
      final secondRandom = SequenceRandom([0.5]).nextDouble;

      final firstDelay = delay.computeDelay(firstContext, firstRandom);
      final secondDelay = delay.computeDelay(firstContext, firstRandom);
      final freshExecutionDelay =
          delay.computeDelay(secondContext, secondRandom);

      expect(firstDelay, const Duration(milliseconds: 200));
      expect(secondDelay, const Duration(milliseconds: 350));
      expect(freshExecutionDelay, firstDelay);
    });

    test('retryIf false does not compute delay', () async {
      var delayComputed = false;

      final result = await RetryPolicy<int>(
        retryIf: RetryIf<int>.where((attempt) => false),
        delay: DelayStrategy.generated((attempt, random) {
          delayComputed = true;
          return Duration.zero;
        }),
      ).execute(() async => 1);

      expect(result, 1);
      expect(delayComputed, isFalse);
    });
  });

  group('public composition interfaces', () {
    test('retry decisions expose OR AND and NOT operators directly', () {
      final retry = RetryIf<int>.any();
      final fallback = FallbackPredicate<int>.any();
      final circuit = CircuitFailurePredicate.any();

      expect(retry | RetryIf<int>.never(), isA<RetryIf<int>>());
      expect(
        fallback & FallbackPredicate<int>.any(),
        isA<FallbackPredicate<int>>(),
      );
      expect(~circuit, isA<CircuitFailurePredicate>());
    });

    test('cancellation types can be extended by package users', () {
      final token = _DomainCancellationToken();
      const reason = _DomainCancelledException();

      token.cancel(reason);

      expect(token.isCancelled, isTrue);
      expect(() => token.throwIfCancelled(), throwsA(same(reason)));
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
        delay: DelayStrategy.none(),
        retryIf: RetryIf<String>.exception() & RetryIf<String>.maxRetries(2),
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
        delay: DelayStrategy.none(),
        retryIf: RetryIf.exceptionType<SocketException, String>() &
            RetryIf<String>.maxRetries(2),
      ).execute(() async {
        attempts++;
        throw error;
      });

      await expectLater(call, throwsA(same(error)));
      expect(attempts, 1);
    });

    test('rethrows final retry-handled exception with captured stack trace',
        () async {
      late StackTrace capturedStackTrace;

      try {
        await RetryPolicy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(0),
        ).execute(_throwFromNamedOperation);
        fail('expected operation to throw');
      } catch (_, stackTrace) {
        capturedStackTrace = stackTrace;
      }

      expect(
          capturedStackTrace.toString(), contains('_throwFromNamedOperation'));
    });

    test(
      'retries retryable results until a valid result is returned',
      () async {
        var attempts = 0;

        final result = await RetryPolicy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.result((value) => value < 10) &
              RetryIf<int>.maxRetries(2),
        ).execute(() async {
          attempts++;
          return attempts == 3 ? 42 : 0;
        });

        expect(result, 42);
        expect(attempts, 3);
      },
    );

    test(
      'returns the final result when retryable results are exhausted',
      () async {
        var attempts = 0;

        final result = await RetryPolicy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.result((value) => value < 10) &
              RetryIf<int>.maxRetries(1),
        ).execute(() async {
          attempts++;
          return 0;
        });

        expect(result, 0);
        expect(attempts, 2);
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
        delay: DelayStrategy.none(),
        retryIf: RetryIf<String>.exception() & RetryIf<String>.maxRetries(2),
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
        delay: DelayStrategy.none(),
        retryIf: RetryIf<String>.exception() & RetryIf<String>.maxRetries(2),
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

      final result = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        onRetry: (event) {
          retryAttempts.add(event.attemptNumber);
          retryDelays.add(event.nextDelay);
        },
        onGiveUp: (event) {
          giveUpAttempts.add(event.attemptNumber);
        },
      ).execute(() async => 0);

      expect(result, 0);
      expect(retryAttempts, [1]);
      expect(retryDelays, [Duration.zero]);
      expect(giveUpAttempts, [2]);
    });

    test('retry event exposes typed attempt outcome', () async {
      final retryOutcomes = <AttemptOutcome<int>>[];

      final result = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
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

    test('waits for asynchronous retry hooks before next attempt', () async {
      var attempts = 0;
      var hookCompleted = false;

      final result = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        onRetry: (_) async {
          await Future<void>.delayed(Duration.zero);
          hookCompleted = true;
        },
      ).execute(() async {
        attempts++;
        if (attempts == 2) {
          expect(hookCompleted, isTrue);
        }
        return attempts == 1 ? 0 : 1;
      });

      expect(result, 1);
      expect(attempts, 2);
    });

    test('propagates hook failures', () async {
      final hookError = StateError('hook failed');

      final call = RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        onRetry: (_) => throw hookError,
      ).execute(() async => 0);

      await expectLater(call, throwsA(same(hookError)));
    });

    test(
      'uses the same retry behavior for sync and convenience APIs',
      () async {
        var syncAttempts = 0;
        final syncResult = await RetryPolicy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
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
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
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
      expect(() => RetryIf<int>.maxRetries(-1), throwsArgumentError);
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

  group('retry decision composition', () {
    test('preserves OR AND and NOT behavior', () async {
      final socketError = AttemptOutcome<int>.error(
        const SocketException('offline'),
        StackTrace.current,
      );
      final argumentError = AttemptOutcome<int>.error(
        ArgumentError('bad input'),
        StackTrace.current,
      );
      const retryableResult = AttemptOutcome.result(0);

      final either = RetryIf.exceptionType<SocketException, int>() |
          RetryIf<int>.result((value) => value == 0);
      final both = RetryIf<int>.exception() &
          ~RetryIf.exceptionType<ArgumentError, int>();

      expect(await either.shouldRetryAttempt(_attempt(socketError)), isTrue);
      expect(
        await either.shouldRetryAttempt(_attempt(retryableResult)),
        isTrue,
      );
      expect(await both.shouldRetryAttempt(_attempt(socketError)), isTrue);
      expect(await both.shouldRetryAttempt(_attempt(argumentError)), isFalse);
    });
  });

  group('public retry extension points', () {
    test('custom retry decisions control retry decisions', () async {
      var classAttempts = 0;
      final classResult = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: const _RetryZeroResult() & RetryIf<int>.maxRetries(1),
      ).execute(() async {
        classAttempts++;
        return classAttempts == 1 ? 0 : 7;
      });

      var callbackAttempts = 0;
      final callbackResult = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.where(
          (attempt) => switch (attempt.outcome) {
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

class _DomainCancelledException extends RetryCancelledException {
  const _DomainCancelledException() : super('domain cancelled');
}

class _DomainCancellationToken extends CancellationToken {}

final class _RetryZeroResult extends RetryIf<int> {
  const _RetryZeroResult();

  @override
  bool shouldRetryAttempt(RetryAttempt<int> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeResult(:final result) => result == 0,
      AttemptOutcomeError() => false,
    };
  }
}

RetryAttempt<int> _attempt(AttemptOutcome<int> outcome) {
  return RetryAttempt<int>(
    outcome: outcome,
    context: RetryContext<int>(attemptNumber: 1, outcome: outcome),
    retryIndex: 0,
    attemptNumber: 1,
    elapsed: Duration.zero,
    attemptDuration: Duration.zero,
    nextDelay: Duration.zero,
  );
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

Future<int> _throwFromNamedOperation() async {
  throw StateError('trace marker');
}

final class SequenceRandom {
  SequenceRandom(this._values);

  final List<double> _values;
  var _index = 0;

  double nextDouble() => _values[_index++];
}
