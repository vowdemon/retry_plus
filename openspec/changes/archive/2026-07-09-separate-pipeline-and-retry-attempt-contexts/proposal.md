## Why

`RetryStrategy` is a normal pipeline strategy and callers may place multiple retry strategies in one pipeline. The current shared retry context carries retry attempt state, which makes nested retry strategies share and corrupt attempt numbers, retry indexes, outcomes, and delay calculations.

## What Changes

- **BREAKING** Rename the pipeline-wide execution context to `RetryPipelineContext<T>` and limit it to pipeline execution state.
- **BREAKING** Replace retry attempt metadata with `RetryAttemptContext<T>` scoped to one `RetryStrategy` instance.
- **BREAKING** Remove retry attempt state from the pipeline context, including attempt number, retry index, retry outcome, and attempt advancement.
- **BREAKING** Update `RetryIf`, retry hooks, and delay generation to receive `RetryAttemptContext<T>`.
- Ensure nested retry strategies keep independent local attempt sequences.
- Ensure non-retry pipeline strategies only receive `RetryPipelineContext<T>` and cannot read retry attempt-local state.
- Keep retry attempt metadata available only through retry-owned callbacks, delay generation, and retry telemetry.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `retry-pipeline`: Separate pipeline execution context from retry attempt context and enforce strategy visibility boundaries.
- `strategy-retry`: Scope retry attempt metadata, retry decisions, delay calculations, and retry hooks to the current `RetryStrategy` instance.

## Impact

- Affects public types currently named `RetryContext<T>` and `RetryAttempt<T>`.
- Affects `RetryPipelineStrategy.execute`, `RetryPipeline`, `RetryPolicy`, `RetryStrategy`, `RetryIf`, `DelayStrategy`, retry hooks, telemetry emission, and tests.
- Affects strategy implementations that currently accept the shared context, including timeout, fallback, circuit breaker, rate limiter, hedging, injection, and custom strategies.
- No new runtime dependencies.
