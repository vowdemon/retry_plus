## Why

The current V1 development API implements retry behavior directly inside `RetryPolicy<T>`. To support timeout, fallback, circuit breaker, richer boolean strategy logic, and testable runtime dependencies without turning `RetryPolicy<T>` into a large mixed-responsibility class, the V1 design needs a lower-level `RetryPipeline<T>` execution engine with `RetryPolicy<T>` as the user-facing facade.

## What Changes

- Add a bottom-level `RetryPipeline<T>` that executes ordered resilience strategies around an operation.
- Keep `RetryPolicy<T>` as the top-level user API that assembles retry, timeout, fallback, circuit breaker, hooks, and runtime dependencies into a pipeline.
- Add timeout strategy support for per-attempt timeout and whole-execution timeout.
- Add fallback strategy support for fallback values and fallback callbacks based on final exceptions or retry-exhausted results.
- Add circuit breaker strategy support with closed, open, and half-open states.
- Extend retry strategy logic with stop AND composition and predicate negation while preserving existing OR and AND predicate behavior.
- Add a runtime dependency object for clock, sleeper, random, timer/scheduler behavior, and observer hooks.
- **BREAKING**: This is still V1 development, so public constructors and internals may be reorganized to make `RetryPolicy<T>` a facade over `RetryPipeline<T>`.

## Capabilities

### New Capabilities

- `retry-pipeline`: Defines how lower-level pipeline execution composes strategies, contexts, runtime dependencies, and events.
- `timeout-strategy`: Defines per-attempt and overall timeout behavior.
- `fallback-strategy`: Defines how final failures can be converted to fallback results.
- `circuit-breaker-strategy`: Defines circuit state transitions and failure protection behavior.
- `runtime-dependencies`: Defines injectable runtime services for deterministic execution and testing without a general-purpose DI container.

### Modified Capabilities

- `strategy-retry`: Refactors retry execution to run as a pipeline strategy and extends boolean strategy composition for V1 development.

## Impact

- Public API exported from `lib/retry_plus.dart` will expand and may be reorganized during V1 development.
- `lib/src/retry_plus_base.dart` should be split into focused modules for pipeline, retry, timeout, fallback, circuit breaker, runtime, events, and exceptions.
- Existing tests must be updated to validate equivalent retry behavior through the new pipeline-backed implementation.
- New deterministic tests are required for timeout, fallback, circuit breaker state transitions, strategy ordering, and runtime injection.
- Runtime dependencies should remain zero unless Dart core libraries cannot express the required behavior.
