import 'package:retry_plus/retry_plus.dart';

Future<void> main() async {
  var attempts = 0;

  final policy = RetryPolicy<String>(
    retry: RetryStrategy(
      delay: DelayStrategy.exponential(
        initial: const Duration(milliseconds: 100),
        max: const Duration(seconds: 1),
        jitter: Jitter.full(),
      ),
      retryIf: RetryIf<String>.exception() & RetryIf<String>.maxRetries(2),
      onRetry: (event) {
        print('attempt ${event.attemptNumber} failed; retrying');
      },
    ),
    timeout: TimeoutStrategy.perAttempt(const Duration(seconds: 2)),
    fallback: FallbackStrategy.value('fallback value'),
  );

  final result = await policy.execute(() async {
    attempts++;
    if (attempts < 3) {
      throw StateError('temporary failure');
    }
    return 'success';
  });

  print(result);

  final breaker = CircuitBreakerStrategy(
    failureThreshold: 2,
    recoveryDuration: const Duration(seconds: 30),
  );

  final guarded = RetryPolicy<String>(
    circuitBreaker: breaker,
    fallback: FallbackStrategy.value(
      'cached value',
      fallbackIf:
          FallbackPredicate.exceptionType<CircuitOpenException, String>(),
    ),
  );

  print(await guarded.execute(() async => 'healthy'));
}
