# retry_plus

Retry utilities for Dart and Flutter.

`retry_plus` runs an operation again when its result or exception matches a
retry predicate. It also includes optional timeout, fallback, circuit breaker,
delay, hook, and cancellation support.

The main entry points are:

- `retry<T>(...)` for one-off calls.
- `RetryPolicy<T>` for reusable retry configuration.
- `RetryPipeline<T>` for explicit strategy ordering.

## API Overview

- Retry by exception or result.
- Stop by attempt count or elapsed time.
- Wait with fixed, linear, exponential, random, composed, or jittered delays.
- Apply per-attempt or overall timeouts.
- Return fallback values or callback results after final failure.
- Track circuit breaker state on a shared strategy instance.
- Receive retry and give-up events.
- Cancel cooperatively between attempts and during retry waits.
- Extend predicates, delays, stop rules, and pipeline strategies.

## Installation

```sh
dart pub add retry_plus
```

For Flutter projects:

```sh
flutter pub add retry_plus
```

## Basic Retry

```dart
import 'package:retry_plus/retry_plus.dart';

final value = await retry(
  () async => fetchValue(),
  attempts: 3,
  delay: DelayStrategy.fixed(const Duration(milliseconds: 200)),
);
```

`attempts: 3` means three total attempts: the initial call and up to two
additional attempts.

## Reusable Policies

Use `RetryPolicy<T>` when the same configuration is used in more than one
place.

```dart
final policy = RetryPolicy<HttpResponse>(
  retry: RetryStrategy(
    stop: StopStrategy.afterAttempt(5),
    delay: DelayStrategy.exponential(
      initial: const Duration(milliseconds: 200),
      max: const Duration(seconds: 5),
      jitter: Jitter.full(),
    ),
    retryIf: RetryPredicate<HttpResponse>.exception() |
        RetryPredicate<HttpResponse>.result(
          (response) => response.statusCode >= 500,
        ),
    onRetry: (event) {
      print('retry #${event.attemptNumber} after ${event.nextDelay}');
    },
  ),
  timeout: TimeoutStrategy.perAttempt(const Duration(seconds: 3)),
);

final response = await policy.execute(() => client.get(uri));
```

Synchronous work uses the same engine:

```dart
final config = await RetryPolicy<Map<String, Object?>>(
  stop: StopStrategy.afterAttempt(2),
  delay: DelayStrategy.none(),
).executeSync(loadConfig);
```

## Fallbacks

Fallbacks run after the wrapped operation fails.

```dart
final policy = RetryPolicy<String>(
  retry: RetryStrategy(
    stop: StopStrategy.afterAttempt(2),
    delay: DelayStrategy.none(),
    retryIf: RetryPredicate<String>.exception(),
  ),
  fallback: FallbackStrategy.value('cached value'),
);

final value = await policy.execute(loadValue);
```

Fallback predicates can be composed with OR, AND, and NOT:

```dart
final fallback = FallbackStrategy.value(
  'cached value',
  fallbackIf: FallbackPredicate.exceptionType<SocketException, String>() |
      FallbackPredicate<String>.retryExhausted(),
);
```

## Circuit Breakers

Circuit breaker state is stored on the strategy instance. Reuse the same
instance for calls that should affect the same breaker.

```dart
final breaker = CircuitBreakerStrategy(
  failureThreshold: 3,
  recoveryDuration: const Duration(seconds: 30),
  failureIf: CircuitFailurePredicate.exceptionType<SocketException>() |
      CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
);

final policy = RetryPolicy<String>(
  circuitBreaker: breaker,
  fallback: FallbackStrategy.value(
    'cached value',
    fallbackIf: FallbackPredicate.exceptionType<CircuitOpenException, String>(),
  ),
);
```

## Cancellation

Cancellation is cooperative. It is checked between attempts and during retry
waits, but it does not forcibly interrupt a currently running operation.

```dart
final token = CancellationToken();

final future = retry(
  () async => fetchValue(),
  attempts: 5,
  cancellationToken: token,
);

token.cancel();
await future;
```

## Advanced Pipelines

`RetryPipeline<T>` applies strategies in list order as outer-to-inner wrappers.
Changing the order changes how fallback, retry, timeout, and circuit breaker
behavior interact.

`RetryPolicy<T>` uses this order:

```text
Fallback -> CircuitBreaker -> OverallTimeout? -> Retry -> PerAttemptTimeout? -> Operation
```

Use `RetryPipeline<T>` to choose a different order:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    TimeoutStrategy.overall(const Duration(seconds: 5)),
    RetryStrategy(
      stop: StopStrategy.afterAttempt(3),
      delay: DelayStrategy.fixed(const Duration(milliseconds: 100)),
    ),
    FallbackStrategy.value('cached value'),
  ],
);

final value = await pipeline.execute(loadValue);
```

## Extension Points

Use callback factories for small custom rules.

```dart
final policy = RetryPolicy<HttpResponse>(
  retry: RetryStrategy(
    stop: StopStrategy.custom(
      shouldStop: (context) => context.attemptNumber >= 5,
      shouldStopBeforeDelay: (context, delay) =>
          context.elapsed + delay > const Duration(seconds: 30),
    ),
    delay: DelayStrategy.custom((context, random) {
      final base = Duration(milliseconds: 100 * context.attemptNumber);
      final jitter = Duration(milliseconds: (random() * 50).round());
      return base + jitter;
    }),
    retryIf: RetryPredicate<HttpResponse>.where((outcome) {
      return outcome.hasError || (outcome.result?.statusCode ?? 0) >= 500;
    }),
  ),
);
```

For domain-specific or reused rules, define named classes.

```dart
final class RetryZeroResult extends RetryPredicate<int> {
  const RetryZeroResult();

  @override
  bool shouldRetry(AttemptOutcome<int> outcome) {
    return !outcome.hasError && outcome.result == 0;
  }
}

final policy = RetryPolicy<int>(
  retryIf: const RetryZeroResult(),
);
```

For behavior that wraps execution, implement `PipelineStrategy<T>` and use an
explicit `RetryPipeline<T>`.

```dart
final class AuditStrategy<T> implements PipelineStrategy<T> {
  @override
  Future<T> execute(
    PipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    context.emit(
      const PipelineEvent(
        type: PipelineEventType.retry,
        metadata: {'source': 'audit'},
      ),
    );
    return next();
  }
}

final pipeline = RetryPipeline<String>(
  strategies: [
    AuditStrategy<String>(),
    RetryStrategy<String>(),
  ],
);
```

## Behavior Notes

- Non-retryable exceptions are rethrown immediately.
- If retrying stops after a retryable exception, the last exception is
  rethrown with its stack trace.
- If retrying stops after retryable results, `RetryExhaustedException<T>` is
  thrown with the last result and attempt metadata.
- Per-attempt timeout can be retried when the retry predicate matches
  `RetryTimeoutException`.
- Fallback runs outside retry and is not retried by default.
- Fallback predicates support `|`, `&`, and `~` composition.
- Circuit breaker `failureIf` controls which non-cancellation failures affect
  breaker state.
- Cancellation bypasses retry, fallback, and circuit breaker failure
  accounting.
- Hook exceptions are not swallowed; a throwing hook completes the retry
  operation with that hook error.

## License

BSD-3-Clause.
