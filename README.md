# retry_plus

Retry utilities for Dart and Flutter.

`retry_plus` runs an operation again when its result or exception matches a
retry decision. It also includes optional timeout, fallback, circuit breaker,
rate limiter, hedging, delay, hook, and cancellation support.

The main entry points are:

- `retry<T>()` for one-off calls with inline retry configuration.
- `Retry<T>` for reusable retry configuration.
- `RetryPipeline<T>` for explicit strategy ordering.

## API Overview

- Retry by exception or result.
- Decide continuation with composable `retryIf` rules, including attempt and
  retry-count budgets.
- Wait with fixed, linear, exponential, random, composed, or jittered delays.
- Apply timeouts by placing `TimeoutStrategy` at the desired pipeline position.
- Return fallback values or callback results after final failure.
- Track circuit breaker state on a shared strategy instance.
- Guard work with custom rate limiters or the built-in FIFO concurrency
  limiter.
- Hedge slow or handled outcomes by racing additional actions.
- Observe pipeline and strategy activity with structured telemetry.
- Cancel cooperatively through the returned retry future.
- Observe the current retry execution phase.
- Extend retry decisions, delays, hooks, and pipeline strategies.

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
  maxRetries: 2,
  initialDelay: const Duration(milliseconds: 200),
  delayFactor: 2,
  maxDelay: const Duration(seconds: 5),
  jitter: Jitter.full(),
);
```

`maxRetries: 2` means up to two retries after the initial attempt.

## Reusable Retry

Use `Retry<T>` when the same configuration is used in more than one
place.

```dart
final policy = Retry<HttpResponse>(
  maxRetries: 4,
  delay: DelayPolicy.exponential(
    initial: const Duration(milliseconds: 200),
    max: const Duration(seconds: 5),
    jitter: Jitter.full(),
  ),
  retryIf: RetryIf<HttpResponse>.result(
    (response) => response.statusCode >= 500,
  ),
  onRetry: (event) {
    print('retry #${event.attemptNumber}');
  },
  timeout: TimeoutStrategy(const Duration(seconds: 30)),
);

final response = await policy.execute(() => client.get(uri));
```

Synchronous work uses the same engine:

```dart
final config = await Retry<Map<String, Object?>>(
  delay: DelayPolicy.none(),
  maxRetries: 1,
).execute(loadConfig);
```

## Fallbacks

Fallbacks run after the wrapped operation fails.

```dart
final policy = Retry<String>(
  delay: DelayPolicy.none(),
  maxRetries: 1,
  fallback: FallbackStrategy.value('cached value'),
);

final value = await policy.execute(loadValue);
```

Fallback predicates can be composed with OR, AND, and NOT:

```dart
final fallback = FallbackStrategy.value(
  'cached value',
  fallbackIf: FallbackPredicate.exceptionType<SocketException, String>() |
      FallbackPredicate.exceptionType<FormatException, String>(),
);
```

Fallback can also replace matching result outcomes when explicitly configured:

```dart
final fallback = FallbackStrategy.value(
  'cached value',
  fallbackIf: FallbackPredicate<String>.result((value) => value.isEmpty),
);
```

By default fallback handles non-cancellation exception outcomes. Use
`FallbackPredicate.any()` only when the fallback should also handle matching
successful result outcomes.

## Circuit Breakers

Circuit breaker state is stored on the `CircuitBreaker` instance. Reuse the
same breaker for calls that should affect the same circuit.

```dart
final breaker = CircuitBreaker(
  failureThreshold: 3,
  recoveryDuration: const Duration(seconds: 30),
  failureIf: CircuitFailurePredicate.exceptionType<SocketException>() |
      CircuitFailurePredicate.exceptionType<RetryTimeoutException>(),
);

final policy = Retry<String>(
  circuitBreaker: breaker,
  fallback: FallbackStrategy.value(
    'cached value',
    fallbackIf: FallbackPredicate.exceptionType<CircuitOpenException, String>(),
  ),
);
```

## Rate Limiters

Rate limiter strategies acquire a lease before invoking the wrapped operation.
Custom limiters can provide retry-after metadata when rejecting execution.

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    RetryStrategy(
      retryIf: RetryIf.exceptionType<RateLimitRejectedException, String>() &
          RetryIf.maxRetries(2),
    ),
    RateLimiterStrategy(
      ConcurrencyLimiter(permitLimit: 8, queueLimit: 32),
    ),
  ],
);
```

## Hedging

Hedging starts additional actions when the current action is slow or produces a
handled outcome. The first acceptable outcome wins.

```dart
final pipeline = RetryPipeline<HttpResponse>(
  strategies: [
    HedgingStrategy<HttpResponse>(
      delay: const Duration(milliseconds: 200),
      maxHedgedAttempts: 2,
      hedgeIf: HedgingPredicate<HttpResponse>.result(
        (response) => response.statusCode >= 500,
      ),
    ),
    TimeoutStrategy(const Duration(seconds: 1)),
  ],
);
```

Custom hedged actions can route later attempts to alternate endpoints:

```dart
final hedging = HedgingStrategy<HttpResponse>(
  delay: const Duration(milliseconds: 150),
  actionGenerator: (context) {
    final endpoint = replicas[context.actionIndex - 1];
    return (_) => client.get(endpoint);
  },
);
```

## Fault Injection

Injection strategies deliberately disturb executions during tests or resilience
drills. They are explicit `RetryPipeline<T>` strategies, so placement controls
which resilience strategies observe the injected behavior.

```dart
final pipeline = RetryPipeline<HttpResponse>(
  strategies: [
    RetryStrategy(
      retryIf: RetryIf.exception() & RetryIf.maxRetries(2),
    ),
    InjectionThrowStrategy<HttpResponse>(
      name: 'transient-network-error',
      injectIf: InjectionTrigger<HttpResponse>.rate(0.05),
      error: (_) => StateError('injected network failure'),
    ),
  ],
);
```

The built-in injection strategies can throw errors, delay execution, return a
synthetic result, or run custom behavior before the inner operation:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    TimeoutStrategy(const Duration(seconds: 2)),
    InjectionDelayStrategy<String>(
      injectIf: InjectionTrigger<String>.where(
        (context) => context.elapsed < const Duration(seconds: 1),
      ),
      delay: (_) => const Duration(milliseconds: 250),
    ),
  ],
);
```

Putting injection inside retry lets retry handle injected results or errors.
Putting timeout outside injection makes injected delay part of the timeout
budget. Putting fallback or circuit breaker outside injection lets those
strategies handle or count injected failures. `Retry<T>` does not add
injection implicitly.

## Telemetry

Telemetry is listener based. Listeners receive structured events with source,
severity, timestamps, elapsed time, outcome/error data, and event-specific
attributes.

```dart
final events = InMemoryTelemetryListener();

final policy = Retry<String>(
  pipelineKey: 'user-api',
  telemetry: TelemetryOptions(listeners: [events]),
  maxRetries: 2,
);

final value = await policy.execute(
  () => client.get(uri),
  operationKey: 'GET /users/{id}',
);
```

Custom listeners can forward events to logging, metrics, tracing, or test
assertions. Listener failures are ignored so observability does not change
pipeline behavior.

```dart
final telemetry = TelemetryOptions(
  listeners: [
    CallbackTelemetryListener((event) {
      print('${event.source.operationKey} ${event.type} ${event.severity}');
    }),
  ],
  severityProvider: (event) => event.type == TelemetryEventType.retryAttempt
      ? TelemetrySeverity.debug
      : defaultTelemetrySeverity(event),
);
```

Built-in telemetry event names use `"<strategy>.<event>"`, such as
`pipeline.succeeded`, `retry.scheduled`, `timeout.timed_out`, and
`fallback.applied`. Telemetry is the observation path. Strategy hooks such as
`onRetry`, `onFallback`, and `onOpened` are awaited side-effect callbacks; hook
failures are visible to the caller.

## Cancellation

Cancellation is cooperative. It is checked between attempts and during retry
waits, but it does not forcibly interrupt a currently running operation.

```dart
final future = Retry(
  maxRetries: 4,
)(
  () async => fetchValue(),
);

future.cancel();
await future;
```

The returned value is a `RetryFuture<T>`, so it can be awaited like a normal
future while also exposing its `cancelToken` and current `phase`. When a
caller-provided token is passed, the retry future exposes that same token;
otherwise the execution creates one.

## Advanced Pipelines

`RetryPipeline<T>` applies strategies in list order as outer-to-inner wrappers.
Changing the order changes how fallback, retry, timeout, circuit breaker, rate
limiter, hedging, and injection behavior interact.

`Retry<T>` is a convenience facade with a documented default order:

```text
Fallback -> CircuitBreaker -> OverallTimeout? -> Retry -> PerAttemptTimeout? -> Operation
```

Use `RetryPipeline<T>` for advanced composition. For example, a timeout outside
retry limits the whole retry flow:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    TimeoutStrategy(const Duration(seconds: 5)),
    RetryStrategy(
      delay: DelayPolicy.fixed(const Duration(milliseconds: 100)),
      retryIf: RetryIf.exception() & RetryIf.maxRetries(2),
    ),
    FallbackStrategy.value('cached value'),
  ],
);

final value = await pipeline.execute(loadValue);
```

Putting timeout inside retry gives each retry attempt its own timeout budget:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    RetryStrategy(
      retryIf: RetryIf.exceptionType<RetryTimeoutException, String>() &
          RetryIf.maxRetries(2),
    ),
    TimeoutStrategy(const Duration(seconds: 1)),
  ],
);
```

Putting timeout inside hedging gives every hedged action its own timeout budget:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    HedgingStrategy<String>(
      delay: const Duration(milliseconds: 100),
      maxHedgedAttempts: 1,
    ),
    TimeoutStrategy(const Duration(seconds: 1)),
  ],
);
```

Putting timeout outside hedging limits the whole hedged race:

```dart
final pipeline = RetryPipeline<String>(
  strategies: [
    TimeoutStrategy(const Duration(seconds: 2)),
    HedgingStrategy<String>(
      delay: const Duration(milliseconds: 100),
      maxHedgedAttempts: 2,
    ),
  ],
);
```

## Extension Points

Use callback factories for small custom rules.

```dart
final policy = Retry<HttpResponse>(
  maxRetries: 4,
  delay: DelayPolicy.custom((context, random) {
    final base = Duration(milliseconds: 100 * context.attemptNumber);
    final jitter = Duration(milliseconds: (random() * 50).round());
    return base + jitter;
  }),
  retryIf: RetryIf<HttpResponse>.result(
    (response) => response.statusCode >= 500,
  ),
  timeout: TimeoutStrategy(const Duration(seconds: 30)),
);
```

For domain-specific or reused rules, define named classes.

```dart
final class RetryZeroResult extends RetryIf<int> {
  const RetryZeroResult();

  @override
  bool shouldHandle(RetryAttemptContext<int> attempt) {
    return switch (attempt.outcome) {
      AttemptOutcomeResult(:final result) => result == 0,
      AttemptOutcomeError() => false,
    };
  }
}

final policy = Retry<int>(
  retryIf: const RetryZeroResult(),
);
```

For behavior that wraps execution, extend `RetryPipelineStrategy<T>` and use an
explicit `RetryPipeline<T>`.

```dart
final class AuditStrategy<T> extends RetryPipelineStrategy<T> {
  const AuditStrategy() : super(name: 'audit');

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    await context.telemetry?.emit<T>(
      type: const TelemetryEventType('audit.before'),
      strategyName: name,
      attributes: {'source': 'audit'},
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
- If retrying stops after retryable results, the last result is returned.
- Timeout scope is determined by pipeline order; place timeout inside retry for
  per-attempt budgets or outside retry for a whole-flow budget.
- Fallback runs outside retry, handles exceptions by default, and is not retried
  by default.
- Fallback predicates support `|`, `&`, and `~` composition.
- Circuit breaker `failureIf` controls which non-cancellation outcomes affect
  breaker state; by default only exception outcomes count.
- Cancellation bypasses retry, fallback, and circuit breaker failure
  accounting.
- Hook exceptions are not swallowed; a throwing hook completes the retry
  operation with that hook error.

## License

BSD-3-Clause.
