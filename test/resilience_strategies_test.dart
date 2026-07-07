import 'dart:async';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  group('timeout strategy', () {
    test('overall timeout reports overall scope', () async {
      final policy = RetryPolicy<int>(
        timeout: TimeoutStrategy.overall(const Duration(milliseconds: 1)),
      );

      final call = policy.execute(() => Completer<int>().future);

      await expectLater(
        call,
        throwsA(
          isA<RetryTimeoutException>().having(
            (error) => error.scope,
            'scope',
            TimeoutScope.overall,
          ),
        ),
      );
    });

    test('cancellation before timeout reports cancellation', () async {
      final token = CancellationToken();
      token.cancel(const RetryCancelledException('stopped'));
      final policy = RetryPolicy<int>(
        timeout: TimeoutStrategy.overall(const Duration(seconds: 1)),
      );

      await expectLater(
        policy.execute(() async => 1, cancellationToken: token),
        throwsA(isA<RetryCancelledException>()),
      );
    });
  });

  group('fallback strategy', () {
    test('does not handle cancellation even with fallback any', () async {
      final policy = RetryPolicy<int>(
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
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(0),
        ),
        fallback: FallbackStrategy.callback((context) {
          capturedFailure = context.failure;
          return 3;
        }),
      );

      final result = await policy.execute(() async => throw StateError('down'));

      expect(result, 3);
      expect(capturedFailure, isA<StateError>());
    });

    test('non-matching failure is propagated', () async {
      final error = StateError('down');
      final policy = RetryPolicy<int>(
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

      final statePolicy = RetryPolicy<int>(
        fallback: FallbackStrategy.value(3, fallbackIf: handlesStateOrArgument),
      );
      final excludedPolicy = RetryPolicy<int>(
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
      final classPolicy = RetryPolicy<int>(
        fallback: FallbackStrategy.value(
          3,
          fallbackIf: const _FallbackOnMessage('class handled'),
        ),
      );
      final callbackPolicy = RetryPolicy<int>(
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

    test(
      'custom predicates compose with built-in fallback predicates',
      () async {
        final predicate = const _FallbackOnMessage('transient') &
            FallbackPredicate.exceptionType<StateError, int>() &
            ~FallbackPredicate.exceptionType<ArgumentError, int>();
        final policy = RetryPolicy<int>(
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

  group('circuit breaker strategy', () {
    test('does not count cancellation as circuit failure', () async {
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = RetryPolicy<int>(circuitBreaker: breaker);

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
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = RetryPolicy<int>(circuitBreaker: breaker);

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

    test('half-open successful probe closes circuit', () async {
      final startedAt = DateTime(2026);
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(seconds: 10),
      );
      final policy = RetryPolicy<int>(circuitBreaker: breaker);

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

    test('retry exhaustion counts as one guarded failure', () async {
      var attempts = 0;
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 2,
        recoveryDuration: const Duration(minutes: 1),
      );
      final policy = RetryPolicy<int>(
        retry: RetryStrategy<int>(
          delay: DelayStrategy.none(),
          retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(2),
        ),
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
      final breaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.exceptionType<StateError>() &
            ~CircuitFailurePredicate.exceptionType<ArgumentError>(),
      );
      final policy = RetryPolicy<int>(circuitBreaker: breaker);

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

    test('custom predicates control circuit failure accounting', () async {
      final classBreaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: const _CircuitFailureOnMessage('class handled'),
      );
      final callbackBreaker = CircuitBreakerStrategy(
        failureThreshold: 1,
        recoveryDuration: const Duration(minutes: 1),
        failureIf: CircuitFailurePredicate.where(
          (context) => context.failure.toString().contains('callback'),
        ),
      );

      await expectLater(
        RetryPolicy<int>(
          circuitBreaker: classBreaker,
        ).execute(() async => throw StateError('class handled')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        RetryPolicy<int>(
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
        final breaker = CircuitBreakerStrategy(
          failureThreshold: 1,
          recoveryDuration: const Duration(minutes: 1),
          failureIf: const _CircuitFailureOnMessage('transient') &
              CircuitFailurePredicate.exceptionType<StateError>() &
              ~CircuitFailurePredicate.exceptionType<ArgumentError>(),
        );
        final policy = RetryPolicy<int>(circuitBreaker: breaker);

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

  group('strategy boolean logic', () {
    test('retry decision AND requires both conditions', () async {
      const outcome = AttemptOutcome.result(0);
      final retryIf = RetryIf<int>.result((value) => value == 0) &
          RetryIf<int>.maxRetries(2);

      expect(
        await retryIf.shouldRetryAttempt(
          RetryAttempt<int>(
            context: RetryContext<int>(
              attemptNumber: 2,
              elapsed: Duration(seconds: 1),
              outcome: outcome,
            ),
            attemptNumber: 2,
            retryIndex: 1,
            elapsed: Duration(seconds: 1),
            attemptDuration: Duration.zero,
            nextDelay: Duration.zero,
            outcome: outcome,
          ),
        ),
        isTrue,
      );
      expect(
        await retryIf.shouldRetryAttempt(
          RetryAttempt<int>(
            context: RetryContext<int>(
              attemptNumber: 3,
              elapsed: Duration.zero,
              outcome: outcome,
            ),
            attemptNumber: 3,
            retryIndex: 2,
            elapsed: Duration.zero,
            attemptDuration: Duration.zero,
            nextDelay: Duration.zero,
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
        await retryIf.shouldRetryAttempt(
          _attempt(
            AttemptOutcome.error(StateError('retry'), StackTrace.current),
          ),
        ),
        isTrue,
      );
      expect(
        await retryIf.shouldRetryAttempt(
          _attempt(
            AttemptOutcome.error(ArgumentError('no'), StackTrace.current),
          ),
        ),
        isFalse,
      );
    });
  });
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

final class _FallbackOnMessage extends FallbackPredicate<int> {
  const _FallbackOnMessage(this.text);

  final String text;

  @override
  bool shouldFallback(FallbackContext<int> context) {
    return context.failure.toString().contains(text);
  }
}

final class _CircuitFailureOnMessage extends CircuitFailurePredicate {
  const _CircuitFailureOnMessage(this.text);

  final String text;

  @override
  bool shouldRecordFailure(CircuitFailureContext context) {
    return context.failure.toString().contains(text);
  }
}
