import 'dart:async';
import 'dart:io';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

import 'test_support.dart';

void main() {
  group('unified retry decision', () {
    test('retryIf receives typed attempt metadata', () async {
      final seen = <RetryAttemptContext<int>>[];

      final result = await Retry<int>(
        delay: DelayPolicy.none(),
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
      expect(seen.first.pipelineContext, isA<RetryPipelineContext<int>>());
      expect(
        switch (seen.first.outcome) {
          AttemptOutcomeResult(:final result) => result,
          AttemptOutcomeError() => fail('expected result outcome'),
        },
        0,
      );
    });

    test('retry attempts expose shared strategy outcome metadata', () async {
      late StrategyOutcome<int> strategyOutcome;

      await Retry<int>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf<int>.where((attempt) {
          strategyOutcome = attempt.strategyOutcome;
          return false;
        }),
      ).execute(() async => 0);

      expect(strategyOutcome.context, isA<RetryPipelineContext<int>>());
      expect(strategyOutcome.metadata['retryIndex'], 0);
      expect(strategyOutcome.metadata['attemptNumber'], 1);
      expect(strategyOutcome.metadata['attemptDuration'], isA<Duration>());
      expect(
        switch (strategyOutcome) {
          StrategyOutcomeResult<int>(:final result) => result,
          StrategyOutcomeError<int>() => fail('expected result outcome'),
        },
        0,
      );
    });

    test('retryIf supports synchronous and asynchronous callbacks', () async {
      var syncAttempts = 0;
      final syncResult = await Retry<int>(
        delay: DelayPolicy.none(),
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
      final asyncResult = await Retry<int>(
        delay: DelayPolicy.none(),
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
      final computedDelays = <Duration>[];

      final result = await Retry<int>(
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        delay: DelayPolicy.generated((attempt, random) async {
          await Future<void>.delayed(Duration.zero);
          final delay = Duration(milliseconds: 2 + attempt.retryIndex);
          computedDelays.add(delay);
          return delay;
        }),
      ).execute(() async => computedDelays.isEmpty ? 0 : 5);

      expect(result, 5);
      expect(computedDelays, [const Duration(milliseconds: 2)]);
    });

    test('generated delay can fall back when it returns null', () async {
      final listener = InMemoryTelemetryListener();
      var attempts = 0;

      final result = await Retry<int>(
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        delay: DelayPolicy.generated((attempt, random) => null)
            .fallbackTo(DelayPolicy.fixed(const Duration(milliseconds: 3))),
        telemetry: TelemetryOptions(listeners: [listener]),
      ).execute(() async {
        attempts++;
        return attempts == 1 ? 0 : 5;
      });

      expect(result, 5);
      final scheduled = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.retryScheduled,
      );
      expect(
        scheduled.attributes['nextDelay'],
        const Duration(milliseconds: 3),
      );
    });

    test('stateful jitter remains scoped to one retry execution', () async {
      final delay = DelayPolicy.decorrelatedJitter(
        medianFirstRetryDelay: const Duration(milliseconds: 100),
      );
      final firstPipelineContext = RetryPipelineContext<Object?>();
      final secondPipelineContext = RetryPipelineContext<Object?>();
      final firstContext = _attemptContext<Object?>(
        attemptNumber: 1,
        pipelineContext: firstPipelineContext,
      );
      final secondContext = _attemptContext<Object?>(
        attemptNumber: 1,
        pipelineContext: secondPipelineContext,
      );
      final nextFirstContext = _attemptContext<Object?>(
        attemptNumber: 2,
        pipelineContext: firstPipelineContext,
      );
      final firstRandom = SequenceRandom([0.5, 0.5]).nextDouble;
      final secondRandom = SequenceRandom([0.5]).nextDouble;

      final firstDelay = await delay.compute(firstContext, firstRandom);
      final secondDelay = await delay.compute(nextFirstContext, firstRandom);
      final freshExecutionDelay = await delay.compute(
        secondContext,
        secondRandom,
      );

      expect(firstDelay, const Duration(milliseconds: 200));
      expect(secondDelay, const Duration(milliseconds: 350));
      expect(freshExecutionDelay, firstDelay);
    });

    test('retryIf false does not compute delay', () async {
      var delayComputed = false;

      final result = await Retry<int>(
        retryIf: RetryIf<int>.where((attempt) => false),
        delay: DelayPolicy.generated((attempt, random) {
          delayComputed = true;
          return Duration.zero;
        }),
      ).execute(() async => 1);

      expect(result, 1);
      expect(delayComputed, isFalse);
    });
  });

  group('Retry', () {
    test('returns a successful async result without retrying', () async {
      var attempts = 0;
      final retryEvents = <RetryAttemptContext<String>>[];

      final result = await Retry<String>(
        delay: DelayPolicy.none(),
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

      final result = await Retry<String>(
        delay: DelayPolicy.none(),
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

      final call = Retry<String>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf.exceptionType<SocketException, String>() &
            RetryIf<String>.maxRetries(2),
      ).execute(() async {
        attempts++;
        throw error;
      });

      await expectLater(call, throwsA(same(error)));
      expect(attempts, 1);
    });

    test('rethrows final retry-exhausted exception with captured stack trace',
        () async {
      late StackTrace capturedStackTrace;

      try {
        await Retry<int>(
          delay: DelayPolicy.none(),
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

        final result = await Retry<int>(
          delay: DelayPolicy.none(),
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

    test('returns non-retryable results immediately', () async {
      var attempts = 0;

      final result = await Retry<int>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf<int>.result((value) => value < 0) &
            RetryIf<int>.maxRetries(2),
      ).execute(() async {
        attempts++;
        return 10;
      });

      expect(result, 10);
      expect(attempts, 1);
    });

    test(
      'returns the final result when retryable results are exhausted',
      () async {
        var attempts = 0;

        final result = await Retry<int>(
          delay: DelayPolicy.none(),
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
      'rethrows the final exception when retryable exceptions are exhausted',
      () async {
        var attempts = 0;
        final failures = [StateError('first'), StateError('last')];

        final call = Retry<int>(
          delay: DelayPolicy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        ).execute(() async {
          throw failures[attempts++];
        });

        await expectLater(call, throwsA(same(failures.last)));
        expect(attempts, 2);
      },
    );

    test(
      'computes composed exponential and random delays deterministically',
      () async {
        final delay = DelayPolicy.exponential(
              initial: const Duration(milliseconds: 100),
              factor: 2,
              max: const Duration(milliseconds: 250),
            ) +
            DelayPolicy.random(
              min: const Duration(milliseconds: 10),
              max: const Duration(milliseconds: 20),
            );
        final random = SequenceRandom([0.5, 0.5]).nextDouble;

        expect(
          [
            await delay.compute(
              _attemptContext<Object?>(attemptNumber: 1),
              random,
            ),
            await delay.compute(
              _attemptContext<Object?>(attemptNumber: 2),
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
      final delay = DelayPolicy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: Jitter.full(),
      );

      expect(
        await delay.compute(
          _attemptContext<Object?>(attemptNumber: 1),
          SequenceRandom([0.25]).nextDouble,
        ),
        const Duration(milliseconds: 25),
      );
    });

    test('cancels promptly during a retry delay', () async {
      final token = CancellationToken();
      late RetryFuture<String> call;
      var attempts = 0;

      call = Retry<String>(
        delay: DelayPolicy.none(),
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
      final giveUpEvents = <RetryAttemptContext<String>>[];

      final call = Retry<String>(
        delay: DelayPolicy.none(),
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
      final giveUpAttempts = <int>[];

      final result = await Retry<int>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        onRetry: (event) {
          retryAttempts.add(event.attemptNumber);
        },
        onGiveUp: (event) {
          giveUpAttempts.add(event.attemptNumber);
        },
      ).execute(() async => 0);

      expect(result, 0);
      expect(retryAttempts, [1]);
      expect(giveUpAttempts, [2]);
    });

    test('retry hook can affect state read by delay generation', () async {
      var multiplier = 1;
      final computedDelays = <Duration>[];

      final result = await Retry<int>(
        retryIf: RetryIf<int>.result((value) => value == 0) &
            RetryIf<int>.maxRetries(1),
        delay: DelayPolicy.generated((attempt, random) {
          final delay = Duration(milliseconds: 2 * multiplier);
          computedDelays.add(delay);
          return delay;
        }),
        onRetry: (_) {
          multiplier = 5;
        },
      ).execute(() async => computedDelays.isEmpty ? 0 : 1);

      expect(result, 1);
      expect(computedDelays, [const Duration(milliseconds: 10)]);
    });

    test('retry event exposes typed attempt outcome', () async {
      final retryOutcomes = <AttemptOutcome<int>>[];

      final result = await Retry<int>(
        delay: DelayPolicy.none(),
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

      final result = await Retry<int>(
        delay: DelayPolicy.none(),
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

      final call = Retry<int>(
        delay: DelayPolicy.none(),
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
        final syncResult = await Retry<int>(
          delay: DelayPolicy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        ).execute(() {
          syncAttempts++;
          if (syncAttempts == 1) {
            throw StateError('try again');
          }
          return 7;
        });

        var retryAttempts = 0;
        final retryResult = await Retry<int>(
          delay: DelayPolicy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        )(
          () async {
            retryAttempts++;
            if (retryAttempts == 1) {
              throw StateError('try again');
            }
            return 9;
          },
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
        () => DelayPolicy.fixed(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => DelayPolicy.exponential(
          initial: const Duration(milliseconds: 1),
          factor: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => DelayPolicy.random(
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

      expect(await either.shouldHandle(_attempt(socketError)), isTrue);
      expect(
        await either.shouldHandle(_attempt(retryableResult)),
        isTrue,
      );
      expect(await both.shouldHandle(_attempt(socketError)), isTrue);
      expect(await both.shouldHandle(_attempt(argumentError)), isFalse);
    });
  });

  group('public retry extension points', () {
    test('custom retry decisions control retry decisions', () async {
      var classAttempts = 0;
      final classResult = await Retry<int>(
        delay: DelayPolicy.none(),
        retryIf: const _RetryZeroResult() & RetryIf<int>.maxRetries(1),
      ).execute(() async {
        classAttempts++;
        return classAttempts == 1 ? 0 : 7;
      });

      var callbackAttempts = 0;
      final callbackResult = await Retry<int>(
        delay: DelayPolicy.none(),
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
      () async {
        final randomValues = <double>[];
        final delay = DelayPolicy.custom((context, random) {
          final randomValue = random();
          randomValues.add(randomValue);
          return Duration(
            milliseconds:
                context.attemptNumber * 100 + (randomValue * 8).round(),
          );
        });
        final random = SequenceRandom([0.5, 0.25]).nextDouble;

        final delays = [
          await delay.compute(
            _attemptContext<Object?>(attemptNumber: 1),
            random,
          ),
          await delay.compute(
            _attemptContext<Object?>(attemptNumber: 2),
            random,
          ),
        ];

        expect(randomValues, [0.5, 0.25]);
        expect(delays, [
          const Duration(milliseconds: 104),
          const Duration(milliseconds: 202),
        ]);
      },
    );

    test('custom jitter implementations and callbacks transform delays',
        () async {
      final context = _attemptContext<int>(
        attemptNumber: 1,
        elapsed: Duration.zero,
        outcome: AttemptOutcome.result(0),
      );
      final classDelay = DelayPolicy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: const _FixedJitter(Duration(milliseconds: 12)),
      );
      final callbackDelay = DelayPolicy.exponential(
        initial: const Duration(milliseconds: 100),
        jitter: Jitter.custom(
          (baseDelay, random) => Duration(
            milliseconds:
                baseDelay.inMilliseconds ~/ 2 + (random() * 10).round(),
          ),
        ),
      );

      expect(
        await classDelay.compute(context, SequenceRandom([0.5]).nextDouble),
        const Duration(milliseconds: 12),
      );
      expect(
        await callbackDelay.compute(context, SequenceRandom([0.5]).nextDouble),
        const Duration(milliseconds: 55),
      );
    });
  });

  group('strategy boolean logic', () {
    test('retry decision AND requires both conditions', () async {
      const outcome = AttemptOutcome.result(0);
      final retryIf = RetryIf<int>.result((value) => value == 0) &
          RetryIf<int>.maxRetries(2);

      expect(
        await retryIf.shouldHandle(
          RetryAttemptContext<int>(
            pipelineContext:
                RetryPipelineContext<int>(elapsed: Duration(seconds: 1)),
            attemptNumber: 2,
            retryIndex: 1,
            elapsed: Duration(seconds: 1),
            attemptDuration: Duration.zero,
            outcome: outcome,
          ),
        ),
        isTrue,
      );
      expect(
        await retryIf.shouldHandle(
          RetryAttemptContext<int>(
            pipelineContext: RetryPipelineContext<int>(),
            attemptNumber: 3,
            retryIndex: 2,
            elapsed: Duration.zero,
            attemptDuration: Duration.zero,
            outcome: outcome,
          ),
        ),
        isFalse,
      );
    });

    test('negated retry decision excludes specific errors', () async {
      final retryIf = RetryIf<int>.exception() &
          ~RetryIf.exceptionType<ArgumentError, int>();

      expect(
        await retryIf.shouldHandle(
          _attempt(
              AttemptOutcome.error(StateError('retry'), StackTrace.current)),
        ),
        isTrue,
      );
      expect(
        await retryIf.shouldHandle(
          _attempt(
              AttemptOutcome.error(ArgumentError('no'), StackTrace.current)),
        ),
        isFalse,
      );
    });
  });
}

final class _RetryZeroResult extends RetryIf<int> {
  const _RetryZeroResult();

  @override
  bool shouldHandle(RetryAttemptContext<int> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeResult(:final result) => result == 0,
      AttemptOutcomeError() => false,
    };
  }
}

RetryAttemptContext<int> _attempt(AttemptOutcome<int> outcome) {
  return _attemptContext<int>(
    outcome: outcome,
    attemptNumber: 1,
  );
}

RetryAttemptContext<T> _attemptContext<T>({
  required int attemptNumber,
  AttemptOutcome<T>? outcome,
  Duration elapsed = Duration.zero,
  RetryPipelineContext<T>? pipelineContext,
}) {
  return RetryAttemptContext<T>(
    outcome: outcome ??
        AttemptOutcome<T>.error(StateError('attempt'), StackTrace.current),
    pipelineContext:
        pipelineContext ?? RetryPipelineContext<T>(elapsed: elapsed),
    retryIndex: attemptNumber - 1,
    attemptNumber: attemptNumber,
    elapsed: elapsed,
    attemptDuration: Duration.zero,
  );
}

final class _FixedJitter implements Jitter {
  const _FixedJitter(this.duration);

  final Duration duration;

  @override
  Duration compute(Duration baseDelay, double Function() random) => duration;
}

Future<int> _throwFromNamedOperation() async {
  throw StateError('trace marker');
}
