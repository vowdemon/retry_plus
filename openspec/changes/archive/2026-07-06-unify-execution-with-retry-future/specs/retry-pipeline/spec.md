## MODIFIED Requirements

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

### Requirement: Share pipeline execution context
The pipeline SHALL pass a shared execution context through strategies containing operation metadata, attempt metadata, cancellation token, retry phase, runtime dependencies, and emitted events.

#### Scenario: Strategy receives shared context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it can read the current context and add strategy-specific event metadata without losing existing context data

#### Scenario: Context carries retry phase control
- **WHEN** retry execution moves between lifecycle stages
- **THEN** the shared pipeline context can update the phase exposed by the returned `RetryFuture<T>`

## ADDED Requirements

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
