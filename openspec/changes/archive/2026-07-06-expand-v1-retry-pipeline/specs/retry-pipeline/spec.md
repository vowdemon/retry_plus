## ADDED Requirements

### Requirement: Execute operations through a retry pipeline
The package SHALL provide `RetryPipeline<T>` as the lower-level execution engine for applying ordered resilience strategies around `Future<T> Function()` and adapted synchronous operations.

#### Scenario: Pipeline executes operation without strategies
- **WHEN** a caller executes an operation through an empty retry pipeline
- **THEN** the pipeline returns the operation result or rethrows the operation error without changing behavior

#### Scenario: Policy delegates to pipeline
- **WHEN** a caller executes an operation through `RetryPolicy<T>`
- **THEN** the policy executes the operation through a `RetryPipeline<T>` built from the policy configuration

### Requirement: Apply canonical strategy order
The high-level policy SHALL apply strategies in the canonical order `Fallback -> CircuitBreaker -> Retry -> Timeout -> Operation`.

#### Scenario: Fallback handles circuit-open failure
- **WHEN** the circuit breaker rejects execution and fallback is configured for that failure
- **THEN** the policy returns the fallback result without invoking retry or the user operation

#### Scenario: Retry wraps per-attempt timeout
- **WHEN** retry and per-attempt timeout are both configured
- **THEN** every retry attempt executes the operation through the per-attempt timeout strategy

#### Scenario: Fallback handles retry exhaustion
- **WHEN** retry attempts are exhausted and fallback is configured for the final failure
- **THEN** the policy returns the fallback result after retry gives up

### Requirement: Share pipeline execution context
The pipeline SHALL pass a shared execution context through strategies containing operation metadata, attempt metadata, cancellation token, runtime dependencies, and emitted events.

#### Scenario: Strategy receives shared context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it can read the current context and add strategy-specific event metadata without losing existing context data

### Requirement: Surface pipeline events
The pipeline SHALL emit lifecycle events for strategy decisions, retries, timeout failures, fallback execution, circuit breaker state changes, cancellation, and final completion.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** observers receive events in the order the decisions occur
