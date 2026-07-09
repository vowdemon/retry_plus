import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('circuit breaker strategy', () {
    test('does not count cancellation as circuit failure', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(
          () async => throw const RetryCancelledException('stopped'),
        ),
        throwsA(isA<RetryCancelledException>()),
      );

      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('opens after threshold and rejects later executions', () async {
      var attempts = 0;
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        policy.execute(() async {
          attempts++;
          return 1;
        }),
        throwsA(isA<CircuitOpenException>()),
      );

      expect(attempts, 0);
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('default circuit breaker does not count successful results', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      expect(await policy.execute(() async => 1), 1);
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('consecutive failure meter resets after success', () async {
      final breaker = CircuitBreaker(
        meter: CircuitMeter.consecutive(2),
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(() async => throw StateError('first')),
        throwsA(isA<StateError>()),
      );
      expect(await policy.execute(() async => 1), 1);
      await expectLater(
        policy.execute(() async => throw StateError('second')),
        throwsA(isA<StateError>()),
      );

      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('failure ratio meter waits for minimum throughput', () async {
      final breaker = CircuitBreaker(
        meter: CircuitMeter.failureRatio(
          failureRatio: 0.5,
          samplingDuration: const Duration(seconds: 30),
          minimumThroughput: 4,
        ),
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(() async => throw StateError('first')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        policy.execute(() async => throw StateError('second')),
        throwsA(isA<StateError>()),
      );

      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('failure ratio meter opens after threshold in sampling window',
        () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreaker(
        meter: CircuitMeter.failureRatio(
          failureRatio: 0.5,
          samplingDuration: const Duration(seconds: 30),
          minimumThroughput: 4,
        ),
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(
        Clock.fixed(startedAt),
        () => policy.execute(() async => 1),
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () => policy.execute(() async => 2),
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 2))),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('first')),
            throwsA(isA<StateError>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 3))),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('second')),
            throwsA(isA<StateError>()),
          );
        },
      );

      expect(breaker.state, CircuitBreakerState.open);
    });

    test('failure ratio meter ignores samples outside sampling window',
        () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreaker(
        meter: CircuitMeter.failureRatio(
          failureRatio: 0.5,
          samplingDuration: const Duration(seconds: 5),
          minimumThroughput: 3,
        ),
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(
        Clock.fixed(startedAt),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('old')),
            throwsA(isA<StateError>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 6))),
        () => policy.execute(() async => 1),
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 7))),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('recent')),
            throwsA(isA<StateError>()),
          );
        },
      );

      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('half-open successful probe closes circuit', () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 10),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(Clock.fixed(startedAt), () async {
        await expectLater(
          policy.execute(() async => throw StateError('down')),
          throwsA(isA<StateError>()),
        );
      });

      final result = await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 10))),
        () => policy.execute(() async => 1),
      );

      expect(result, 1);
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('half-open failed probe reopens circuit', () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 10),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(Clock.fixed(startedAt), () async {
        await expectLater(
          policy.execute(() async => throw StateError('down')),
          throwsA(isA<StateError>()),
        );
      });

      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 10))),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('probe failed')),
            throwsA(isA<StateError>()),
          );
        },
      );

      expect(breaker.state, CircuitBreakerState.open);
    });

    test('generated break duration controls half-open timing', () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 1),
        breakDuration: (context) {
          expect(context.outcome, isA<StrategyOutcomeError<Object?>>());
          return const Duration(seconds: 5);
        },
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(
        Clock.fixed(startedAt),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('down')),
            throwsA(isA<StateError>()),
          );
        },
      );

      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          await expectLater(
            policy.execute(() async => 1),
            throwsA(
              isA<CircuitOpenException>().having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 4),
              ),
            ),
          );
        },
      );

      final result = await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 5))),
        () => policy.execute(() async => 1),
      );

      expect(result, 1);
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('state provider reports state without mutation', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      expect(breaker.stateProvider.state, CircuitBreakerState.closed);
      await expectLater(
        policy.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );

      expect(breaker.stateProvider.state, CircuitBreakerState.open);
      expect(breaker.stateProvider.openedAt, isNotNull);
      expect(breaker.stateProvider.retryAfter(), isNotNull);
    });

    test('manual control isolates and closes circuit', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await breaker.control.isolate();
      expect(breaker.stateProvider.state, CircuitBreakerState.isolated);
      await expectLater(
        policy.execute(() async => 1),
        throwsA(isA<CircuitOpenException>()),
      );

      await breaker.control.close();

      expect(breaker.stateProvider.state, CircuitBreakerState.closed);
      expect(await policy.execute(() async => 1), 1);
    });

    test('lifecycle hooks receive opened half-open closed and rejected',
        () async {
      final startedAt = DateTime(2026);
      final events = <String>[];
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 5),
        onOpened: (context) async {
          events.add('opened:${context.breakDuration}');
        },
        onRejected: (context) async {
          events.add('rejected:${context.retryAfter}');
        },
        onHalfOpened: (context) async {
          events.add('half-open');
        },
        onClosed: (context) async {
          events.add('closed:${context.previousState}');
        },
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await withClock(
        Clock.fixed(startedAt),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('down')),
            throwsA(isA<StateError>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          await expectLater(
            policy.execute(() async => 1),
            throwsA(isA<CircuitOpenException>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 5))),
        () => policy.execute(() async => 1),
      );

      expect(events, [
        'opened:0:00:05.000000',
        'rejected:0:00:04.000000',
        'half-open',
        'closed:CircuitBreakerState.halfOpen',
      ]);
    });

    test('lifecycle telemetry reports state changes and rejections', () async {
      final startedAt = DateTime(2026);
      final listener = InMemoryTelemetryListener();
      final breaker = CircuitBreaker(
        name: 'primary-breaker',
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 5),
      );
      final policy = Retry<int>(
        circuitBreaker: breaker,
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await withClock(
        Clock.fixed(startedAt),
        () async {
          await expectLater(
            policy.execute(() async => throw StateError('down')),
            throwsA(isA<StateError>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          await expectLater(
            policy.execute(() async => 1),
            throwsA(isA<CircuitOpenException>()),
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 5))),
        () => policy.execute(() async => 1),
      );

      final circuitEvents = listener.events
          .where((event) =>
              event.type.name.startsWith('circuit.') &&
              event.source.strategyName == 'primary-breaker')
          .map((event) => event.type)
          .toList();
      expect(circuitEvents, [
        TelemetryEventType.circuitOpened,
        TelemetryEventType.circuitRejected,
        TelemetryEventType.circuitHalfOpened,
        TelemetryEventType.circuitClosed,
      ]);
    });

    test('retry exhaustion counts as one guarded failure', () async {
      var attempts = 0;
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 2,
        circuitBreaker: breaker,
      );

      await expectLater(
        policy.execute(() async {
          attempts++;
          throw StateError('down');
        }),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 3);
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('failure predicate controls what opens the circuit', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.exceptionType<StateError>() &
            ~CircuitFailurePredicate.exceptionType<ArgumentError>(),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(() async => throw ArgumentError('bad input')),
        throwsA(isA<ArgumentError>()),
      );
      expect(breaker.state, CircuitBreakerState.closed);

      await expectLater(
        policy.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('failure predicate can count matching result outcomes', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 1),
        failureIf: CircuitFailurePredicate.result<int>((value) => value == 0),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      final result = await policy.execute(() async => 0);

      expect(result, 0);
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('explicit circuit any can count result outcomes', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 1),
        failureIf: CircuitFailurePredicate.any(),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      expect(await policy.execute(() async => 1), 1);
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('cancellation bypasses custom circuit predicate', () async {
      var evaluated = false;
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.where((context) {
          evaluated = true;
          return true;
        }),
      );
      final policy = Retry<int>(circuitBreaker: breaker);

      await expectLater(
        policy.execute(
          () async => throw const RetryCancelledException('stopped'),
        ),
        throwsA(isA<RetryCancelledException>()),
      );

      expect(evaluated, isFalse);
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('custom predicates control circuit failure accounting', () async {
      final classBreaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: const _CircuitFailureOnMessage('class handled'),
      );
      final callbackBreaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.where(
          (context) => context.failure.toString().contains('callback'),
        ),
      );

      await expectLater(
        Retry<int>(
          circuitBreaker: classBreaker,
        ).execute(() async => throw StateError('class handled')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        Retry<int>(
          circuitBreaker: callbackBreaker,
        ).execute(() async => throw StateError('callback')),
        throwsA(isA<StateError>()),
      );

      expect(classBreaker.state, CircuitBreakerState.open);
      expect(callbackBreaker.state, CircuitBreakerState.open);
    });

    test(
      'custom predicates compose with built-in circuit predicates',
      () async {
        final breaker = CircuitBreaker(
          failureThreshold: 1,
          recoveryDuration: const Duration(minutes: 1),
          failureIf: const _CircuitFailureOnMessage('transient') &
              CircuitFailurePredicate.exceptionType<StateError>() &
              ~CircuitFailurePredicate.exceptionType<ArgumentError>(),
        );
        final policy = Retry<int>(circuitBreaker: breaker);

        await expectLater(
          policy.execute(() async => throw ArgumentError('transient')),
          throwsA(isA<ArgumentError>()),
        );
        expect(breaker.state, CircuitBreakerState.closed);

        await expectLater(
          policy.execute(() async => throw StateError('transient')),
          throwsA(isA<StateError>()),
        );
        expect(breaker.state, CircuitBreakerState.open);
      },
    );
  });
}

final class _CircuitFailureOnMessage extends CircuitFailurePredicate {
  const _CircuitFailureOnMessage(this.text);

  final String text;

  @override
  bool shouldHandle(CircuitFailureContext context) {
    return context.failure.toString().contains(text);
  }
}
