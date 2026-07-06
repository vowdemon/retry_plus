## Why

`retry_plus` is currently a generated Dart package skeleton and does not provide retry behavior. The package should become a reusable strategy-based retry library for Dart and Flutter applications, focused on transient failures in async work such as HTTP calls, SDK requests, database operations, and other IO.

## What Changes

- Replace the placeholder public API with a strategy-based retry API centered on `RetryPolicy<T>`.
- Add a convenient `retry<T>(...)` function for one-off usage while keeping policy objects reusable.
- Support async operations as the core execution model, with synchronous operations adapted through `executeSync`.
- Support retry decisions based on exceptions and returned results.
- Add composable stop, delay, retry predicate, jitter, cancellation, and lifecycle event primitives.
- Add deterministic tests, examples, README usage, and package metadata suitable for a publishable Dart package.

## Capabilities

### New Capabilities

- `strategy-retry`: Defines how callers configure and execute reusable retry policies, including retry predicates, stop conditions, delay strategies, cancellation, hooks, and failure behavior.

### Modified Capabilities

- None.

## Impact

- Public Dart API exported from `lib/retry_plus.dart`.
- Internal implementation under `lib/src/`.
- Existing generated placeholder class, example, test, and README content will be replaced.
- Runtime dependencies should remain zero unless implementation proves a dependency is necessary.
- Dev dependencies continue to use `test` and `lints`.
