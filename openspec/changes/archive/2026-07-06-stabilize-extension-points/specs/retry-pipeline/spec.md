## ADDED Requirements

### Requirement: Accept custom pipeline strategies
`RetryPipeline<T>` SHALL accept caller-defined `RetryPipelineStrategy<T>` implementations as first-class ordered strategies.

#### Scenario: Multiple custom strategies wrap operation in order
- **WHEN** a caller constructs a pipeline with multiple custom strategies
- **THEN** the pipeline applies those strategies in caller-provided order around the operation

#### Scenario: Custom strategy uses shared pipeline context
- **WHEN** a custom pipeline strategy executes
- **THEN** it receives the shared `PipelineContext<T>` with runtime dependencies, cancellation token, attempt metadata, elapsed time, and event emission support

### Requirement: Preserve canonical policy while allowing custom pipeline order
The package SHALL keep `RetryPolicy<T>` canonical while allowing arbitrary custom order only through `RetryPipeline<T>`.

#### Scenario: Policy remains canonical
- **WHEN** a caller uses `RetryPolicy<T>`
- **THEN** the policy builds the documented canonical strategy order

#### Scenario: Pipeline supports advanced custom order
- **WHEN** a caller needs order different from the canonical policy order
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list
