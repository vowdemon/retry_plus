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
    test('call delegates to execute', () async {
      var attempts = 0;
      final retry = Retry<int>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
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
