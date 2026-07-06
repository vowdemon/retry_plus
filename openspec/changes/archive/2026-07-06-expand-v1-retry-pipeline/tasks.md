## 1. Module Structure And Runtime

- [x] 1.1 Split `lib/src/retry_plus_base.dart` into focused source files for public facade, pipeline, runtime, events, retry, timeout, fallback, circuit breaker, delays, predicates, stop strategies, cancellation, and exceptions.
- [x] 1.2 Update `lib/retry_plus.dart` exports so public API remains coherent after the module split.
- [x] 1.3 Implement `RetryRuntime` with clock, sleeper, random, timeout scheduling hooks, and observer support.
- [x] 1.4 Move existing fake clock, fake sleeper, and deterministic random helpers into reusable test utilities.

## 2. RetryPipeline Core

- [x] 2.1 Implement `RetryPipeline<T>` as the lower-level execution engine for async operations.
- [x] 2.2 Add pipeline context carrying runtime, cancellation token, operation metadata, attempt metadata, failure metadata, and event emission.
- [x] 2.3 Add strategy handler interfaces for wrapping an operation chain.
- [x] 2.4 Ensure an empty pipeline preserves raw operation success and error behavior.
- [x] 2.5 Add ordered observer events for pipeline start, strategy decisions, completion, failure, and cancellation.

## 3. RetryPolicy Facade And Retry Migration

- [x] 3.1 Refactor `RetryPolicy<T>` into a user-facing facade that builds the canonical pipeline.
- [x] 3.2 Move current retry loop behavior into a retry pipeline strategy.
- [x] 3.3 Preserve existing retry-only behavior for `RetryPolicy<T>`, `execute`, `executeSync`, and top-level `retry<T>(...)`.
- [x] 3.4 Add stop strategy AND composition.
- [x] 3.5 Add retry predicate negation and tests for excluding specific retry conditions.
- [x] 3.6 Preserve final exception stack traces and retry-exhausted result behavior inside the pipeline.

## 4. Timeout Strategy

- [x] 4.1 Implement per-attempt timeout strategy.
- [x] 4.2 Implement overall pipeline timeout strategy.
- [x] 4.3 Add distinct timeout exception and event metadata for per-attempt versus overall timeout.
- [x] 4.4 Ensure cancellation before timeout reports cancellation rather than timeout.
- [x] 4.5 Test retry behavior when per-attempt timeout is retryable.

## 5. Fallback Strategy

- [x] 5.1 Implement fallback value strategy.
- [x] 5.2 Implement fallback callback strategy with final failure context.
- [x] 5.3 Add fallback filtering for exceptions and retry-exhausted results.
- [x] 5.4 Ensure fallback runs outside retry and is not retried by default.
- [x] 5.5 Test fallback handling for final exception, retry exhaustion, timeout, and circuit-open failures.

## 6. Circuit Breaker Strategy

- [x] 6.1 Implement circuit breaker states: closed, open, and half-open.
- [x] 6.2 Implement failure threshold and recovery duration behavior.
- [x] 6.3 Implement half-open probe success and failure transitions.
- [x] 6.4 Ensure breaker state is shared across executions of the same policy or strategy instance.
- [x] 6.5 Count one circuit breaker success or failure per guarded pipeline execution rather than per retry attempt.
- [x] 6.6 Add state inspection and reset APIs if needed for tests and user control.

## 7. Canonical Composition

- [x] 7.1 Wire high-level `RetryPolicy<T>` order as `Fallback -> CircuitBreaker -> Retry -> Timeout -> Operation`.
- [x] 7.2 Test that circuit-open failures can be handled by fallback without invoking retry or the operation.
- [x] 7.3 Test that retry wraps per-attempt timeout for every attempt.
- [x] 7.4 Test that retry exhaustion can be handled by fallback.
- [x] 7.5 Test that fallback callback failures are propagated without retrying fallback.

## 8. Documentation And Verification

- [x] 8.1 Update README examples for retry-only, retry with timeout, fallback, circuit breaker, and advanced pipeline usage.
- [x] 8.2 Update API dartdocs for `RetryPipeline<T>`, `RetryPolicy<T>`, runtime, timeout, fallback, and circuit breaker types.
- [x] 8.3 Update example script to show high-level `RetryPolicy<T>` facade usage.
- [x] 8.4 Update changelog to describe the V1 development pipeline expansion.
- [x] 8.5 Run `dart format`, `dart analyze`, and `dart test`.
