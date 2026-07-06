## Context

`retry_plus` is a Dart package scaffold with placeholder API, README, example, and tests. The change turns it into a publishable retry library inspired by Tenacity's composable retry strategies, p-retry's lightweight async ergonomics, and Polly's policy-oriented resilience model without adopting a full resilience pipeline in the first release.

The primary consumers are Dart and Flutter developers retrying transient async work such as HTTP calls, SDK requests, database calls, and other IO. The implementation should remain dependency-light, deterministic in tests, and understandable as a small library.

## Goals / Non-Goals

**Goals:**

- Provide a reusable `RetryPolicy<T>` as the main public abstraction.
- Provide a `retry<T>(...)` convenience function for one-off calls.
- Use async `Future<T>` execution as the internal model.
- Support synchronous work through `executeSync` without duplicating the retry engine.
- Support retrying by exception and by returned result.
- Support composable stop, delay, retry predicate, jitter, cancellation, and lifecycle event primitives.
- Preserve original exceptions and stack traces when retries stop because of a final exception.
- Make delays, clocks, and randomness injectable internally so tests do not sleep in real time.

**Non-Goals:**

- Do not implement circuit breaker, timeout, fallback, bulkhead, rate limiting, or a general resilience pipeline.
- Do not add Flutter-only APIs or depend on Flutter.
- Do not add annotations, code generation, global retry configuration, or dependency injection integrations.
- Do not forcibly interrupt a currently running operation when cancellation is requested.

## Decisions

### Policy-first API with a convenience function

The public API will center on `RetryPolicy<T>`, configured with `stop`, `delay`, `retryIf`, cancellation, and hooks. This makes policies reusable and testable. A top-level `retry<T>(...)` function will delegate to `RetryPolicy<T>` for simple one-off usage.

Alternative considered: a p-retry style function-only API. It is easier to learn, but it makes reusable policies and strategy composition weaker and tends to grow into a large options object.

### Async engine with sync adapter

The retry loop will execute `Future<T> Function()` operations. `executeSync(T Function())` will wrap synchronous work in a future and use the same engine. This keeps stop, delay, error, hook, and cancellation behavior consistent.

Alternative considered: separate sync and async engines. That duplicates behavior and increases test surface without adding meaningful capability for the first version.

### Strategy objects instead of option enums

Stop, delay, and retry decisions will be small strategy types:

- `StopStrategy`: `StopStrategy.never()`, `StopStrategy.afterAttempt(n)`, `StopStrategy.afterElapsed(duration)`, `StopStrategy.beforeElapsed(duration)`.
- `DelayStrategy`: `DelayStrategy.none()`, `DelayStrategy.fixed(duration)`, `DelayStrategy.linear(...)`, `DelayStrategy.exponential(...)`, `DelayStrategy.random(...)`.
- `RetryPredicate<T>`: `RetryPredicate<T>.exception()`, `RetryPredicate.exceptionType<E, T>()`, `RetryPredicate<T>.exceptionWhere(...)`, `RetryPredicate<T>.result(...)`, `RetryPredicate<T>.any()`, `RetryPredicate<T>.never()`.

Strategies will support focused composition:

- `StopStrategy | StopStrategy` stops when either condition is met.
- `RetryPredicate<T> | RetryPredicate<T>` and `RetryPredicate<T> & RetryPredicate<T>` combine retry decisions.
- `DelayStrategy + DelayStrategy` adds delay durations, primarily for fixed delay plus jitter.

Alternative considered: a single `RetryOptions` class with scalar fields. That is simpler initially but less expressive for combinations such as maximum attempts or elapsed budget, result retry plus exception retry, or fixed delay plus random jitter.

### Clear execution state and event model

Each attempt will produce an `AttemptOutcome<T>` containing either `result` or `error` plus `stackTrace`. `RetryContext` will expose attempt number, elapsed time, last outcome, and computed next delay. Public hooks will start with `onRetry` and `onGiveUp`; internal event modeling can include attempt start, success, failure, retry, cancellation, and give-up events to keep future expansion possible.

Final failure semantics:

- If the last retryable outcome is an exception, rethrow the original exception with its stack trace.
- If the last retryable outcome is a result, throw `RetryExhaustedException<T>` with last result, attempts, elapsed time, and last event context.
- If an exception is not retryable, rethrow it immediately with its stack trace.

### Cancellation token modeled in Dart

The package will include a lightweight `CancellationToken` and cancellation exception. Cancellation is checked before attempts, before sleeping, and during retry delay waits. It will not cancel an operation already running because Dart has no safe generic interruption mechanism for arbitrary user code.

Alternative considered: relying only on `Future.timeout` or caller-owned cancellation. That does not cover waiting between retries and makes the retry loop harder to stop cleanly.

### Testability through internal time abstractions

The implementation will use internal injectable `Sleeper`, `Clock`, and random source abstractions. Public API can remain simple, while tests can assert elapsed stop behavior, delay schedules, and jitter without real waiting.

Alternative considered: real `Future.delayed` in tests. That makes tests slow and flaky, especially for elapsed budget and cancellation cases.

## Risks / Trade-offs

- Strategy composition may feel more advanced than a minimal retry helper -> Provide a short top-level `retry<T>(...)` API and README examples first.
- Generic result predicates can make type inference tricky in some calls -> Keep examples explicit and allow `RetryPolicy<Response>` construction when needed.
- `operator |`, `&`, and `+` may be surprising to some Dart users -> Use them only where they map cleanly to strategy composition and document named alternatives if implementation needs them.
- Cancellation cannot stop an in-flight operation -> Document that cancellation is cooperative between attempts and during retry waits.
- Default delay behavior can surprise callers if retries are expected to be immediate -> Keep defaults conservative and document them in README and API docs.
- Preserving stack traces requires care -> Use Dart mechanisms that rethrow or throw with captured stack traces rather than wrapping final exceptions by default.
