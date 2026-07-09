## MODIFIED Requirements

### Requirement: Share pipeline execution context
The pipeline SHALL pass a shared `RetryPipelineContext<T>` through strategies containing pipeline execution state, cancellation token, retry phase, elapsed time, random source, timing helpers, and telemetry support.

#### Scenario: Strategy receives shared pipeline context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it receives `RetryPipelineContext<T>` with pipeline-level execution services
- **AND** the context does not expose retry attempt number, retry index, latest retry outcome, or retry attempt advancement

#### Scenario: Context carries retry phase control
- **WHEN** retry execution moves between lifecycle stages
- **THEN** the shared pipeline context can update the phase exposed by the returned `RetryFuture<T>`

### Requirement: Accept custom pipeline strategies
`RetryPipeline<T>` SHALL accept caller-defined `RetryPipelineStrategy<T>` implementations as first-class ordered strategies.

#### Scenario: Multiple custom strategies wrap operation in order
- **WHEN** a caller constructs a pipeline with multiple custom strategies
- **THEN** the pipeline applies those strategies in caller-provided order around the operation

#### Scenario: Custom strategy uses shared pipeline context
- **WHEN** a custom pipeline strategy executes
- **THEN** it receives the shared `RetryPipelineContext<T>` with cancellation, elapsed time, phase, random source, timing helpers, and telemetry support
- **AND** it cannot read retry attempt-local metadata from that context

## ADDED Requirements

### Requirement: Keep retry attempt state out of pipeline context
The pipeline context SHALL NOT contain retry attempt-local state.

#### Scenario: Non-retry strategy cannot inspect retry attempt state
- **WHEN** timeout, fallback, circuit breaker, rate limiter, hedging, injection, or a custom pipeline strategy executes
- **THEN** the strategy receives only `RetryPipelineContext<T>`
- **AND** it cannot read retry attempt number, retry index, retry attempt outcome, or retry attempt duration from the pipeline context

### Requirement: Keep nested retry strategies independent
Multiple retry strategies in one pipeline SHALL maintain independent retry attempt sequences according to normal pipeline nesting.

#### Scenario: Nested retries keep local attempt counts
- **WHEN** an outer retry strategy wraps an inner retry strategy
- **THEN** the outer retry strategy counts only executions of the inner pipeline as its local attempts
- **AND** the inner retry strategy counts only its own operation attempts for each execution of the inner pipeline

#### Scenario: Inner retry restarts for each outer attempt
- **WHEN** an outer retry schedules a second attempt after the inner retry has already exhausted or completed an earlier local sequence
- **THEN** the inner retry strategy starts a new local attempt sequence for the second outer attempt
