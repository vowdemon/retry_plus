## MODIFIED Requirements

### Requirement: Share pipeline execution context
The pipeline SHALL pass a shared `RetryContext<T>` through strategies containing operation metadata, attempt metadata, cancellation token, retry phase, elapsed time, and an optional telemetry sink.

#### Scenario: Strategy receives shared context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it can read the current context and emit strategy-specific telemetry through the context telemetry sink without losing existing context data

#### Scenario: Context carries retry phase control
- **WHEN** retry execution moves between lifecycle stages
- **THEN** the shared pipeline context can update the phase exposed by the returned `RetryFuture<T>`

### Requirement: Surface pipeline events
The pipeline SHALL emit structured telemetry for strategy decisions, retries, retry attempts, timeout failures, fallback execution, circuit breaker state changes, rate limiter rejections, hedging actions, triggered injection behavior, cancellation, and final completion through configured telemetry listeners.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** telemetry listeners receive events in the order the decisions occur

#### Scenario: Observer receives structured source
- **WHEN** a named pipeline emits telemetry for an operation key
- **THEN** telemetry listeners can read source fields without parsing metadata

### Requirement: Support explicit custom pipeline order
The package SHALL provide an explicit advanced API for constructing a `RetryPipeline<T>` with caller-defined strategy order and optional telemetry configuration.

#### Scenario: Custom order follows caller list
- **WHEN** a caller constructs a custom pipeline with strategies in a specific order
- **THEN** the pipeline applies strategies in that caller-defined order

#### Scenario: High-level policy does not limit advanced composition
- **WHEN** a caller needs strategy order not represented by `RetryPolicy<T>` convenience fields
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list

#### Scenario: Custom pipeline accepts telemetry
- **WHEN** a caller constructs a pipeline with telemetry options
- **THEN** the pipeline emits telemetry through those options during execution

### Requirement: Accept custom pipeline strategies
`RetryPipeline<T>` SHALL accept caller-defined `RetryPipelineStrategy<T>` implementations as first-class ordered strategies.

#### Scenario: Multiple custom strategies wrap operation in order
- **WHEN** a caller constructs a pipeline with multiple custom strategies
- **THEN** the pipeline applies those strategies in caller-provided order around the operation

#### Scenario: Custom strategy uses shared pipeline context
- **WHEN** a custom pipeline strategy executes
- **THEN** it receives the shared `RetryContext<T>` with cancellation, attempt metadata, elapsed time, and an optional telemetry sink
