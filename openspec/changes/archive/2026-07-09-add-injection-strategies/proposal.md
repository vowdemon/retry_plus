## Why

`retry_plus` has composable resilience strategies, but users still need a first-class way to deliberately disturb executions during tests and resilience drills. An injection strategy suite gives callers controlled bad conditions without coupling retry, timeout, fallback, circuit breaker, hedging, or rate limiting to test-only behavior.

## What Changes

- Add a new `injection-strategy` capability for explicit pipeline strategies that can throw errors, delay execution, return synthetic results, or run custom disturbance behavior.
- Add an open `InjectionTrigger<T>` model using the existing context-predicate composition style instead of fixed enum-style configuration.
- Use `RetryPipelineContext<T>` directly for trigger and generator callbacks, including elapsed time, cancellation, random source, and pipeline execution access.
- Add four strategies:
  - `InjectionThrowStrategy<T>`
  - `InjectionDelayStrategy<T>`
  - `InjectionResultStrategy<T>`
  - `InjectionBehaviorStrategy<T>`
- Emit pipeline events for triggered injection behavior; skipped injection remains silent.
- Keep injection out of `RetryPolicy<T>` convenience parameters so strategy order remains explicit through `RetryPipeline<T>`.

## Capabilities

### New Capabilities

- `injection-strategy`: Disturb pipeline executions through explicit throw, delay, result, and behavior strategies for tests and resilience drills.

### Modified Capabilities

- `retry-pipeline`: Add injection pipeline event types and document that injection participates in explicit ordered strategy composition.
- `public-extension-points`: Add injection triggers and injection callbacks to the documented extension surface.

## Impact

- Adds new public API in `lib/src/injection_strategy.dart` and exports it from `retry_plus.dart`.
- Adds new `PipelineEventType` values for injection events.
- Adds tests covering trigger composition, ordering with retry/timeout/fallback/circuit breaker/hedging, cancellation behavior, deterministic random decisions, and event metadata.
- Updates README examples for explicit pipeline-based injection use.
