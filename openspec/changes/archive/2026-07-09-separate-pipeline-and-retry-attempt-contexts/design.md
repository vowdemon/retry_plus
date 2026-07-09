## Context

The pipeline model now treats every resilience behavior as an ordered `RetryPipelineStrategy<T>`. That means `RetryStrategy<T>` is not special at the pipeline level: callers can place multiple retry strategies in one pipeline and those strategies nest like timeout, fallback, circuit breaker, hedging, rate limiter, injection, and custom strategies.

The current shared context mixes pipeline execution state with retry attempt state. This creates invalid states when two retry strategies are nested because attempt number, retry index, and latest retry outcome are currently shared across the whole pipeline execution.

## Goals / Non-Goals

**Goals:**

- Split pipeline-wide execution state from retry-local attempt state.
- Make nested retry strategies maintain independent attempt sequences.
- Make retry attempt state visible only to retry-owned extension points.
- Keep non-retry strategies and custom pipeline strategies unable to read retry attempt details by type.
- Keep strategy outcome context pipeline-scoped so outcomes can cross strategy boundaries without leaking retry internals.

**Non-Goals:**

- Do not add compatibility aliases for the old context names.
- Do not add a global attempt counter for the whole pipeline.
- Do not let injection, timeout, fallback, circuit breaker, rate limiter, hedging, or custom pipeline strategies inspect retry-local attempt metadata.
- Do not change pipeline ordering semantics.

## Decisions

### Rename and narrow the shared context

The shared strategy context becomes `RetryPipelineContext<T>`. It owns only execution-wide state and services:

- elapsed execution time
- cancellation token and cancellation helpers
- telemetry sink
- random source
- sleep and timeout helpers
- phase updates
- current clock access

It does not expose retry attempt number, retry index, latest retry outcome, or attempt advancement.

Alternative considered: keep the `RetryContext<T>` name and remove fields. That reduces rename churn but leaves the name ambiguous because the type no longer means retry attempt context. The rename makes the boundary explicit.

### Replace RetryAttempt with RetryAttemptContext

Retry-local attempt metadata becomes `RetryAttemptContext<T>`. A retry strategy creates a fresh local sequence for each execution of that strategy. The context contains:

- `pipelineContext`
- typed attempt outcome
- local zero-based retry index
- local one-based attempt number
- elapsed execution time
- attempt duration

`RetryIf`, `DelayStrategy`, `onRetry`, `onGiveUp`, and retry telemetry assembly use this context.

Alternative considered: keep `RetryAttempt<T>`. The name hides that this is the public retry decision/hook/delay context and not merely a value object. `RetryAttemptContext<T>` is clearer and aligns with `RetryPipelineContext<T>`.

### Make retry attempts strategy-local

Each `RetryStrategy<T>` instance owns its local attempt counter inside `execute`. If an outer retry wraps an inner retry, the inner retry counter starts from one for each outer attempt. The outer retry only observes the final outcome of the inner pipeline execution.

Example:

```text
outer retry attempt 1
  inner retry attempt 1
  inner retry attempt 2
  inner retry attempt 3

outer retry attempt 2
  inner retry attempt 1
  inner retry attempt 2
  inner retry attempt 3
```

Alternative considered: keep a global pipeline attempt counter and also add local retry counters. That adds two competing meanings for "attempt" and invites strategies to use the wrong one.

### Keep retry attempt state out of non-retry strategies

`RetryPipelineStrategy<T>.execute` receives `RetryPipelineContext<T>`. All non-retry strategies and custom strategies therefore only receive pipeline-level context. They cannot read retry attempt number, retry index, or retry outcome unless a retry strategy explicitly reports that information through retry-owned telemetry.

Injection remains pipeline-scoped. Its triggers and callbacks receive `RetryPipelineContext<T>` and cannot use retry attempt number. Attempt-aware disturbance belongs in retry extension points such as `retryIf`, `delay`, or `onRetry`.

Alternative considered: add optional retry attempt metadata to the pipeline context when a retry is active. That reintroduces leakage and becomes ambiguous with nested retry strategies.

### Keep StrategyOutcome pipeline-scoped

`StrategyOutcome.context` remains pipeline-scoped. Retry attempt metadata may be attached to retry telemetry metadata/attributes, but other strategies cannot recover retry attempt context from a shared outcome.

Alternative considered: allow `StrategyOutcome` to carry `RetryAttemptContext` when emitted by retry. That would leak retry internals to fallback, circuit breaker, hedging, and custom outcome predicates.

### Move delay calculation to RetryAttemptContext

`DelayStrategy` computes from `RetryAttemptContext<T>`, not pipeline context. Linear and exponential delay use the retry strategy's local attempt number. Generated delay already conceptually depends on attempt metadata and follows the same context type.

Alternative considered: keep `DelayStrategy.custom` on pipeline context and only generated delay on retry attempt context. That keeps the current bug for custom linear/exponential-like delay implementations and splits one concept across two incompatible APIs.

## Risks / Trade-offs

- **Breaking API rename churn** -> Acceptable because the package is still in development and the old names encode the wrong model.
- **Custom strategies must update signatures** -> The new signature is simpler for non-retry strategies and prevents accidental retry-state coupling.
- **Injection loses attempt-number triggers** -> This is intended. Retry attempt numbers are local to a retry strategy and injection is a generic pipeline strategy.
- **Specs from active injection and telemetry changes mention old names** -> Update those changes during implementation or before archiving so all pending artifacts converge on `RetryPipelineContext<T>`.

## Migration Plan

1. Introduce `RetryPipelineContext<T>` as the shared pipeline execution context and update all pipeline strategy signatures.
2. Introduce `RetryAttemptContext<T>` and update retry decisions, delay strategies, hooks, retry telemetry, and tests.
3. Remove attempt and outcome state from the pipeline context.
4. Update non-retry strategies to use only `RetryPipelineContext<T>`.
5. Update injection and telemetry OpenSpec artifacts to use the new context names before archiving.

## Open Questions

None.
