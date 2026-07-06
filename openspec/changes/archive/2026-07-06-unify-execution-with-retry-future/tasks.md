## 1. Public Execution API

- [x] 1.1 Add public `RetryFuture<T>` and `RetryPhase` exports with `cancelToken`, `phase`, and `cancel([reason])`.
- [x] 1.2 Change `RetryPolicy<T>.execute` to accept `FutureOr<T> Function()` and return `RetryFuture<T>`.
- [x] 1.3 Change top-level `retry<T>(...)` to accept `FutureOr<T> Function()` and return `RetryFuture<T>`.
- [x] 1.4 Remove `RetryPolicy<T>.executeSync` and update all internal call sites.

## 2. Pipeline Execution

- [x] 2.1 Change `RetryPipeline<T>.execute` to accept `FutureOr<T> Function()` and return `RetryFuture<T>`.
- [x] 2.2 Adapt synchronous returns and synchronous throws into the async pipeline with `Future.sync` or equivalent behavior.
- [x] 2.3 Use the provided cancellation token or create one per execution and expose it through `RetryFuture<T>`.
- [x] 2.4 Ensure `RetryFuture<T>` delegates all `Future<T>` behavior to the underlying execution future.

## 3. Retry Phase Lifecycle

- [x] 3.1 Initialize new executions with `RetryPhase.pending`.
- [x] 3.2 Set phase to `attempting` while an operation attempt is running.
- [x] 3.3 Set phase to `waiting` while retry delay is pending.
- [x] 3.4 Set terminal phase to `completed`, `failed`, or `cancelled` according to final execution outcome.
- [x] 3.5 Keep phase exposure limited to `RetryFuture.phase` and avoid adding a public `RetryState` object.

## 4. Tests and Documentation

- [x] 4.1 Add tests that await `RetryFuture<T>` successfully and through errors.
- [x] 4.2 Add tests for synchronous success, synchronous retry, and synchronous non-retryable failure through `execute`.
- [x] 4.3 Add tests that `RetryFuture.cancel()` cancels the effective token and execution APIs expose caller-passed cancellation tokens when provided.
- [x] 4.4 Add tests for phase transitions across attempting, waiting, completed, failed, and cancelled paths.
- [x] 4.5 Update README and examples to remove `executeSync` and show unified sync/async `execute` plus `RetryFuture` cancellation and phase usage.
