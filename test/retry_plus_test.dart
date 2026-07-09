import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
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

  group('Retry facade', () {
    test('top-level retry executes with inline configuration', () async {
      var attempts = 0;

      final future = retry<int>(
        () {
          attempts++;
          if (attempts == 1) {
            throw StateError('try again');
          }
          return 11;
        },
        initialDelay: const Duration(microseconds: 1),
        maxRetries: 1,
      );

      expect(future, isA<RetryFuture<int>>());
      expect(await future, 11);
      expect(attempts, 2);
    });

    test('top-level retry exposes exponential backoff parameters', () async {
      final listener = InMemoryTelemetryListener();
      var attempts = 0;

      final result = await retry<int>(
        () {
          attempts++;
          if (attempts < 3) {
            throw StateError('try again');
          }
          return 13;
        },
        initialDelay: const Duration(milliseconds: 1),
        delayFactor: 3,
        maxDelay: const Duration(milliseconds: 2),
        maxRetries: 2,
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      final scheduledDelays = listener.events
          .where((event) => event.type == TelemetryEventType.retryScheduled)
          .map((event) => event.attributes['nextDelay'])
          .toList();

      expect(result, 13);
      expect(scheduledDelays, [
        const Duration(milliseconds: 1),
        const Duration(milliseconds: 2),
      ]);
    });

    test('top-level retry appends retryIf to default exception handling',
        () async {
      var attempts = 0;

      final result = await retry<int>(
        () {
          attempts++;
          if (attempts == 1) {
            throw StateError('default exception retry remains enabled');
          }
          return attempts == 2 ? 0 : 17;
        },
        initialDelay: const Duration(microseconds: 1),
        maxRetries: 2,
        retryIf: RetryIf<int>.result((value) => value == 0),
      );

      expect(result, 17);
      expect(attempts, 3);
    });

    test('call delegates to execute', () async {
      var attempts = 0;
      final retry = Retry<int>(
        delay: DelayPolicy.none(),
        maxRetries: 1,
      );

      final result = await retry(() async {
        attempts++;
        if (attempts == 1) {
          throw StateError('try again');
        }
        return 7;
      });

      expect(result, 7);
      expect(attempts, 2);
    });
  });
}

class _DomainCancelledException extends RetryCancelledException {
  const _DomainCancelledException() : super('domain cancelled');
}

class _DomainCancellationToken extends CancellationToken {}
