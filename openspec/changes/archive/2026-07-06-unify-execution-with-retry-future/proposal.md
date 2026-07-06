## Why

The current execution API splits sync and async entry points and returns a plain `Future<T>`, so each retry execution cannot directly expose its own cancellation handle or current retry phase. Because the package has not shipped yet, this change can reshape the API directly before release.

## What Changes

- **BREAKING** Change `RetryPolicy.execute` to accept `FutureOr<T> Function()` and return `RetryFuture<T>`.
- **BREAKING** Change the top-level `retry` convenience API to accept `FutureOr<T> Function()` and return `RetryFuture<T>`.
- **BREAKING** Remove the separate synchronous execution API.
- Add `RetryFuture<T>` as a `Future<T>`-compatible execution object for one retry run.
- Expose the execution's `CancellationToken` from `RetryFuture<T>`.
- Use a caller-provided cancellation token when one is supplied; otherwise generate one for the execution.
- Expose `RetryFuture.cancel([reason])` as the direct control entry point for cancellation.
- Expose the current retry execution phase through `RetryFuture.phase` using `RetryPhase`.
- Do not introduce a separate public `RetryState` abstraction.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `strategy-retry`: Change public retry execution APIs to use `FutureOr` operations and return `RetryFuture<T>` with cancellation and phase observability.
- `retry-pipeline`: Change lower-level pipeline execution to support `FutureOr` operations and shared execution state needed by `RetryFuture<T>`.

## Impact

- Public API changes in `RetryPolicy<T>`, top-level `retry<T>`, and exports.
- Removal of `executeSync` and related documentation/examples.
- New public `RetryFuture<T>` and `RetryPhase` types.
- Internal pipeline context and retry strategy updates so attempt lifecycle transitions update the live execution phase.
- Tests and README examples must be updated for the new unified API.
