## 1. Package Surface

- [x] 1.1 Update `pubspec.yaml` metadata, description, SDK constraints, and package identity for `retry_plus`.
- [x] 1.2 Replace placeholder exports in `lib/retry_plus.dart` with the supported public API surface.
- [x] 1.3 Define public callback and operation typedefs for async execution, sync execution, retry predicates, hooks, and cancellation.

## 2. Core Retry Model

- [x] 2.1 Implement `RetryPolicy<T>` with immutable configuration defaults.
- [x] 2.2 Implement `RetryPolicy<T>.execute` for `Future<T> Function()` operations.
- [x] 2.3 Implement `RetryPolicy<T>.executeSync` by adapting `T Function()` operations into the async engine.
- [x] 2.4 Implement the top-level `retry<T>(...)` convenience function as a wrapper around `RetryPolicy<T>`.
- [x] 2.5 Implement attempt outcome, retry context, retry event, exhausted exception, and cancellation exception models.

## 3. Strategies

- [x] 3.1 Implement stop strategies: never, after attempt, after elapsed, before elapsed, and OR composition.
- [x] 3.2 Implement delay strategies: none, fixed, linear, exponential, random, and additive composition.
- [x] 3.3 Implement jitter support for exponential or bounded delay calculations.
- [x] 3.4 Implement retry predicates for all exceptions, typed exceptions, exception predicates, result predicates, any, never, OR composition, and AND composition.
- [x] 3.5 Validate strategy inputs and fail fast for invalid durations, attempt counts, factors, or random bounds.

## 4. Execution Semantics

- [x] 4.1 Ensure non-retryable results return immediately.
- [x] 4.2 Ensure non-retryable exceptions are rethrown immediately with original stack traces.
- [x] 4.3 Ensure exhausted retryable exceptions rethrow the final exception with its stack trace.
- [x] 4.4 Ensure exhausted retryable results throw `RetryExhaustedException<T>` with last result and metadata.
- [x] 4.5 Ensure `StopStrategy.beforeElapsed` does not schedule a delay that would exceed the elapsed budget.

## 5. Cancellation And Hooks

- [x] 5.1 Implement `CancellationToken` and cancellation checks before attempts and during retry waits.
- [x] 5.2 Ensure cancellation during delay completes promptly with the cancellation reason or cancellation exception.
- [x] 5.3 Implement `onRetry` hook with attempt number, elapsed time, outcome, and next delay metadata.
- [x] 5.4 Implement `onGiveUp` hook with final outcome metadata.
- [x] 5.5 Ensure hook failures have documented behavior and test coverage.

## 6. Deterministic Testing

- [x] 6.1 Add internal test utilities for fake clock, fake sleeper, and deterministic random source.
- [x] 6.2 Test immediate success, retry success, non-retryable exception, retryable result, and exhausted result behavior.
- [x] 6.3 Test attempt counting, elapsed stop behavior, and before-elapsed stop behavior.
- [x] 6.4 Test fixed, linear, exponential, random, jitter, and additive delay calculations.
- [x] 6.5 Test cancellation before attempts and during retry delay.
- [x] 6.6 Test `onRetry`, `onGiveUp`, `executeSync`, and top-level `retry<T>(...)` behavior.
- [x] 6.7 Run `dart test` and `dart analyze`.

## 7. Documentation And Examples

- [x] 7.1 Replace README template with concise package description and examples for basic retry, HTTP-style result retry, and exponential backoff with jitter.
- [x] 7.2 Replace generated example with a runnable `retry_plus` example.
- [x] 7.3 Add dartdoc comments for all public types and constructors.
- [x] 7.4 Update changelog for the initial strategy retry API.
