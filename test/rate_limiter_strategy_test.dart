import 'dart:async';

import 'package:clock/clock.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('rate limiter strategy', () {
    test('acquires and releases lease after success', () async {
      final limiter = _TrackingLimiter(allowAcquire: true);
      final pipeline = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );

      final result = await pipeline.execute(() async => 1);

      expect(result, 1);
      expect(limiter.acquired, 1);
      expect(limiter.released, 1);
    });

    test('releases lease after failure', () async {
      final limiter = _TrackingLimiter(allowAcquire: true);
      final pipeline = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );

      await expectLater(
        pipeline.execute(() async => throw StateError('down')),
        throwsA(isA<StateError>()),
      );

      expect(limiter.acquired, 1);
      expect(limiter.released, 1);
    });

    test('rejects without invoking inner pipeline', () async {
      var invoked = false;
      RateLimitRejectedContext? rejected;
      final pipeline = RetryPipeline<int>(
        strategies: [
          RateLimiterStrategy<int>(
            _TrackingLimiter(
              allowAcquire: false,
              retryAfter: const Duration(seconds: 3),
            ),
            onRejected: (context) {
              rejected = context;
            },
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() async {
          invoked = true;
          return 1;
        }),
        throwsA(
          isA<RateLimitRejectedException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 3),
          ),
        ),
      );

      expect(invoked, isFalse);
      expect(rejected?.retryAfter, const Duration(seconds: 3));
    });

    test('rejection hook and telemetry receive retry-after metadata', () async {
      final listener = InMemoryTelemetryListener();
      RateLimitRejectedContext? rejected;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RateLimiterStrategy<int>(
            _TrackingLimiter(
              allowAcquire: false,
              retryAfter: const Duration(seconds: 3),
            ),
            name: 'api-limiter',
            onRejected: (context) {
              rejected = context;
            },
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() async => 1),
        throwsA(isA<RateLimitRejectedException>()),
      );

      final event = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.rateLimiterRejected,
      );
      expect(rejected?.retryAfter, const Duration(seconds: 3));
      expect(rejected?.error.retryAfter, const Duration(seconds: 3));
      expect(event.source.strategyName, 'api-limiter');
      expect(event.attributes['retryAfter'], const Duration(seconds: 3));
    });

    test('outer retry handles rate-limit rejection metadata', () async {
      final limiter = _RejectOnceLimiter(
        retryAfter: const Duration(milliseconds: 10),
      );
      final pipeline = RetryPipeline<int>(
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.none(),
            retryIf: RetryIf.exceptionType<RateLimitRejectedException, int>() &
                RetryIf.maxRetries(1),
          ),
          RateLimiterStrategy<int>(limiter),
        ],
      );

      final result = await pipeline.execute(() async => 1);

      expect(result, 1);
      expect(limiter.attempts, 2);
    });
  });

  group('concurrency limiter', () {
    test('limits concurrent executions and queues FIFO', () async {
      final limiter = ConcurrencyLimiter(permitLimit: 1, queueLimit: 2);
      final pipeline = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );
      final first = Completer<int>();
      final order = <int>[];

      final firstRun = pipeline.execute(() async {
        order.add(1);
        return first.future;
      });
      final secondRun = pipeline.execute(() async {
        order.add(2);
        return 2;
      });
      final thirdRun = pipeline.execute(() async {
        order.add(3);
        return 3;
      });
      await Future<void>.delayed(Duration.zero);

      expect(order, [1]);

      first.complete(1);

      expect(await firstRun, 1);
      expect(await secondRun, 2);
      expect(await thirdRun, 3);
      expect(order, [1, 2, 3]);
    });

    test('rejects when queue is full', () async {
      final limiter = ConcurrencyLimiter(permitLimit: 1, queueLimit: 0);
      final pipeline = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );
      final first = Completer<int>();

      final firstRun = pipeline.execute(() async => first.future);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        pipeline.execute(() async => 2),
        throwsA(isA<RateLimitRejectedException>()),
      );

      first.complete(1);
      expect(await firstRun, 1);
    });

    test('queued cancellation does not consume released permit', () async {
      final limiter = ConcurrencyLimiter(permitLimit: 1, queueLimit: 1);
      final pipeline = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );
      final token = CancellationToken();
      final first = Completer<int>();

      final firstRun = pipeline.execute(() async => first.future);
      await Future<void>.delayed(Duration.zero);

      final queued = pipeline.execute(
        () async => 2,
        cancellationToken: token,
      );
      final queuedExpectation = expectLater(
        queued,
        throwsA(isA<RetryCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel(const RetryCancelledException('stopped'));
      first.complete(1);

      expect(await firstRun, 1);
      await queuedExpectation;
      expect(await pipeline.execute(() async => 3), 3);
    });
  });

  group('token bucket limiter', () {
    test('consumes available tokens rejects when empty and refills over time',
        () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = TokenBucketLimiter(
        tokenLimit: 2,
        tokensPerPeriod: 1,
        refillPeriod: const Duration(seconds: 1),
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isTrue);
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isTrue);
        final rejected = limiter.acquire(_rateLimitContext());
        expect(rejected.isAcquired, isFalse);
        expect(rejected.retryAfter, const Duration(seconds: 1));
      });

      await withClock(
        Clock.fixed(startedAt.add(const Duration(milliseconds: 400))),
        () async {
          final rejected = limiter.acquire(_rateLimitContext());
          expect(rejected.isAcquired, isFalse);
          expect(rejected.retryAfter, const Duration(milliseconds: 600));
        },
      );

      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
        },
      );
    });

    test('clamps refilled tokens to bucket capacity', () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = TokenBucketLimiter(
        tokenLimit: 2,
        tokensPerPeriod: 1,
        refillPeriod: const Duration(seconds: 1),
        initialTokens: 0,
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isFalse);
      });
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 10))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isFalse,
          );
        },
      );
    });
  });

  group('fixed window limiter', () {
    test('consumes permits rejects with retry-after and resets by window',
        () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = FixedWindowLimiter(
        permitLimit: 2,
        window: const Duration(seconds: 1),
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isTrue);
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isTrue);
        final rejected = limiter.acquire(_rateLimitContext());
        expect(rejected.isAcquired, isFalse);
        expect(rejected.retryAfter, const Duration(seconds: 1));
      });

      await withClock(
        Clock.fixed(startedAt.add(const Duration(milliseconds: 250))),
        () async {
          final rejected = limiter.acquire(_rateLimitContext());
          expect(rejected.isAcquired, isFalse);
          expect(rejected.retryAfter, const Duration(milliseconds: 750));
        },
      );

      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
        },
      );
    });
  });

  group('sliding window limiter', () {
    test('tracks rolling permits and drops stale segments', () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = SlidingWindowLimiter(
        permitLimit: 2,
        window: const Duration(seconds: 4),
        segmentsPerWindow: 4,
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isTrue);
      });
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 1))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 2))),
        () async {
          final rejected = limiter.acquire(_rateLimitContext());
          expect(rejected.isAcquired, isFalse);
          expect(rejected.retryAfter, const Duration(seconds: 2));
        },
      );
      await withClock(
        Clock.fixed(
          startedAt.add(const Duration(seconds: 3, milliseconds: 999)),
        ),
        () async {
          final rejected = limiter.acquire(_rateLimitContext());
          expect(rejected.isAcquired, isFalse);
          expect(rejected.retryAfter, const Duration(milliseconds: 1));
        },
      );
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 4))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
        },
      );
    });
  });

  group('passive time-based limiters', () {
    test('apply elapsed time on next acquisition without background work',
        () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = TokenBucketLimiter(
        tokenLimit: 1,
        tokensPerPeriod: 1,
        refillPeriod: const Duration(seconds: 1),
        initialTokens: 0,
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(limiter.acquire(_rateLimitContext()).isAcquired, isFalse);
      });
      await withClock(
        Clock.fixed(startedAt.add(const Duration(seconds: 5))),
        () async {
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isTrue,
          );
          expect(
            limiter.acquire(_rateLimitContext()).isAcquired,
            isFalse,
          );
        },
      );
    });

    test('shared limiter instance shares state across strategies', () async {
      final startedAt = DateTime(2026, 1, 1, 12);
      final limiter = FixedWindowLimiter(
        permitLimit: 1,
        window: const Duration(seconds: 1),
      );
      final first = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );
      final second = RetryPipeline<int>(
        strategies: [RateLimiterStrategy<int>(limiter)],
      );

      await withClock(Clock.fixed(startedAt), () async {
        expect(await first.execute(() async => 1), 1);
        await expectLater(
          second.execute(() async => 2),
          throwsA(isA<RateLimitRejectedException>()),
        );
      });
    });
  });
}

RateLimitContext _rateLimitContext() {
  return RateLimitContext(pipelineContext: RetryPipelineContext<Object?>());
}

final class _RejectOnceLimiter implements RateLimiter {
  _RejectOnceLimiter({
    this.retryAfter,
  });

  final Duration? retryAfter;
  int attempts = 0;

  @override
  FutureOr<RateLimitLease> acquire(RateLimitContext context) {
    attempts++;
    if (attempts == 1) {
      return RateLimitLease.rejected(retryAfter: retryAfter);
    }
    return RateLimitLease.acquired();
  }
}

final class _TrackingLimiter implements RateLimiter {
  _TrackingLimiter({
    required this.allowAcquire,
    this.retryAfter,
  });

  final bool allowAcquire;
  final Duration? retryAfter;
  int acquired = 0;
  int released = 0;

  @override
  FutureOr<RateLimitLease> acquire(RateLimitContext context) {
    acquired++;
    if (!allowAcquire) {
      return RateLimitLease.rejected(retryAfter: retryAfter);
    }
    return RateLimitLease.acquired(
      retryAfter: retryAfter,
      onRelease: () {
        released++;
      },
    );
  }
}
