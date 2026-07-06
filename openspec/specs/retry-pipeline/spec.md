## Purpose

Defines the lower-level retry pipeline execution engine and strategy composition order used by `retry_plus`.

## Requirements

### Requirement: Execute operations through a retry pipeline
The package SHALL provide `RetryPipeline<T>` as the lower-level execution engine for applying ordered resilience strategies around `FutureOr<T> Function()` operations and returning `RetryFuture<T>`.

#### Scenario: Pipeline executes operation without strategies
- **WHEN** a caller executes an operation through an empty retry pipeline
- **THEN** the returned `RetryFuture<T>` completes with the operation result or rethrows the operation error without changing behavior

#### Scenario: Pipeline executes synchronous operation without strategies
- **WHEN** a caller executes a synchronous operation through an empty retry pipeline
- **THEN** the returned `RetryFuture<T>` completes with the synchronous result or synchronous error without changing behavior

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
The pipeline SHALL pass a shared execution context through strategies containing operation metadata, attempt metadata, cancellation token, retry phase, runtime dependencies, and emitted events.

#### Scenario: Strategy receives shared context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it can read the current context and add strategy-specific event metadata without losing existing context data

#### Scenario: Context carries retry phase control
- **WHEN** retry execution moves between lifecycle stages
- **THEN** the shared pipeline context can update the phase exposed by the returned `RetryFuture<T>`

### Requirement: Return future-compatible pipeline execution handle
`RetryPipeline<T>.execute` SHALL return a `RetryFuture<T>` that is compatible with `Future<T>` and exposes execution cancellation and phase.

#### Scenario: Pipeline retry future delegates future behavior
- **WHEN** a caller uses `then`, `catchError`, `whenComplete`, `timeout`, `asStream`, or `await` on the returned retry future
- **THEN** those operations behave as they would on the underlying execution future

#### Scenario: Pipeline retry future exposes effective cancellation token
- **WHEN** a caller executes an operation through a retry pipeline
- **THEN** the returned retry future exposes the effective cancellation token for that pipeline execution

#### Scenario: Pipeline retry future exposes phase
- **WHEN** a caller executes an operation through a retry pipeline
- **THEN** the returned retry future exposes the current `RetryPhase` for that pipeline execution

### Requirement: Surface pipeline events
The pipeline SHALL emit lifecycle events for strategy decisions, retries, timeout failures, fallback execution, circuit breaker state changes, cancellation, and final completion.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** observers receive events in the order the decisions occur

### Requirement: Support explicit custom pipeline order
The package SHALL provide an explicit advanced API for constructing a `RetryPipeline<T>` with caller-defined strategy order.

#### Scenario: Custom order follows caller list
- **WHEN** a caller constructs a custom pipeline with strategies in a specific order
- **THEN** the pipeline applies strategies in that caller-defined order

#### Scenario: High-level policy remains canonical
- **WHEN** a caller uses `RetryPolicy<T>`
- **THEN** the policy continues to use the canonical strategy order rather than caller-defined order

### Requirement: Document custom order semantics
The package SHALL document that custom pipeline order changes fallback handling, retry visibility, timeout scope, and circuit breaker failure counting.

#### Scenario: Documentation warns about order changes
- **WHEN** documentation shows custom pipeline usage
- **THEN** it explains that custom order is an advanced API and can change observable behavior

### Requirement: Cancellation bypasses pipeline recovery
The pipeline SHALL preserve cancellation as cancellation across strategy boundaries.

#### Scenario: Cancellation reaches caller
- **WHEN** cancellation is thrown inside a pipeline execution
- **THEN** the caller receives the cancellation failure unless it is outside the pipeline and explicitly handled by caller code

### Requirement: Accept custom pipeline strategies
`RetryPipeline<T>` SHALL accept caller-defined `PipelineStrategy<T>` implementations as first-class ordered strategies.

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
