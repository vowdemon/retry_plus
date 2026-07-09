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

#### Scenario: Retry facade delegates to pipeline
- **WHEN** a caller executes an operation through `Retry<T>`
- **THEN** the retry facade executes the operation through a `RetryPipeline<T>` built from the retry configuration

### Requirement: Use ordered strategy composition as authoritative scope
The package SHALL use explicit `RetryPipeline<T>` strategy order as the authoritative model for strategy scope, interaction, and visibility.

#### Scenario: Earlier strategy wraps later strategy
- **WHEN** a caller constructs a pipeline with strategies `[A, B, C]`
- **THEN** strategy `A` wraps `B`, strategy `B` wraps `C`, and strategy `C` wraps the user operation

#### Scenario: Outer strategy sees inner outcome
- **WHEN** an inner strategy returns a result or throws an exception
- **THEN** the directly wrapping outer strategy can observe that outcome according to its contract

### Requirement: Apply canonical strategy order
The high-level retry facade SHALL provide a convenience default order, but explicit `RetryPipeline<T>` ordering SHALL be the primary API for advanced strategy composition.

#### Scenario: Fallback handles circuit-open failure
- **WHEN** the convenience retry order places fallback outside circuit breaker and the circuit breaker rejects execution
- **THEN** fallback can return the fallback result without invoking retry or the user operation

#### Scenario: Retry wraps inner timeout by explicit order
- **WHEN** a caller places retry outside timeout in an explicit pipeline
- **THEN** every retry attempt executes the inner pipeline through the timeout strategy

#### Scenario: Timeout wraps retry by explicit order
- **WHEN** a caller places timeout outside retry in an explicit pipeline
- **THEN** the timeout applies to the whole retry flow including retry delays

### Requirement: Support multiple strategies of the same kind
The pipeline SHALL allow callers to place multiple instances of the same strategy kind in one pipeline.

#### Scenario: Multiple timeouts are nested
- **WHEN** a caller places two timeout strategies at different positions
- **THEN** each timeout applies to the inner pipeline it wraps

#### Scenario: Multiple retries are nested
- **WHEN** a caller places two retry strategies at different positions
- **THEN** each retry strategy retries the inner pipeline it wraps according to its own retry decision and delay

### Requirement: Share pipeline execution context
The pipeline SHALL pass a shared `RetryPipelineContext<T>` through strategies containing pipeline execution state, cancellation token, retry phase, elapsed time, random source, timing helpers, and telemetry support.

#### Scenario: Strategy receives shared pipeline context
- **WHEN** a strategy runs inside a pipeline
- **THEN** it receives `RetryPipelineContext<T>` with pipeline-level execution services
- **AND** the context does not expose retry attempt number, retry index, latest retry outcome, or retry attempt advancement

#### Scenario: Context carries retry phase control
- **WHEN** retry execution moves between lifecycle stages
- **THEN** the shared pipeline context can update the phase exposed by the returned `RetryFuture<T>`

### Requirement: Support execution context for cooperative strategies
The pipeline SHALL provide enough execution context for strategies to coordinate cancellation, metadata, and operation invocation in advanced scenarios such as hedging and timeout.

#### Scenario: Strategy creates child execution
- **WHEN** a strategy such as hedging starts an additional action
- **THEN** it can provide that action with context metadata and cooperative cancellation state

### Requirement: Return future-compatible pipeline execution handle
`RetryPipeline<T>.execute` SHALL return a `RetryFuture<T>` that is compatible with `Future<T>` and exposes execution cancellation and phase.

#### Scenario: Pipeline retry future delegates future behavior
- **WHEN** a caller uses `then`, `catchError`, `whenComplete`, `timeout`, `asStream`, or `await` on the returned retry future
- **THEN** those operations behave as they would on the underlying execution future

#### Scenario: Pipeline retry future exposes effective cancellation token
- **WHEN** a caller executes an operation through a retry pipeline
- **THEN** the returned retry future exposes the effective cancellation token for that pipeline execution

### Requirement: Surface pipeline events
The pipeline SHALL emit lifecycle events for strategy decisions, retries, timeout failures, fallback execution, circuit breaker state changes, rate limiter rejections, hedging actions, triggered injection behavior, cancellation, and final completion through explicit `onEvent` callbacks.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** observers receive events in the order the decisions occur

#### Scenario: Observer receives triggered injection event
- **WHEN** an injection strategy triggers inside a pipeline execution
- **THEN** the observer receives the corresponding injection event with public metadata

### Requirement: Support explicit custom pipeline order
The package SHALL provide an explicit advanced API for constructing a `RetryPipeline<T>` with caller-defined strategy order and optional telemetry configuration.

#### Scenario: Custom order follows caller list
- **WHEN** a caller constructs a custom pipeline with strategies in a specific order
- **THEN** the pipeline applies strategies in that caller-defined order

#### Scenario: High-level retry facade does not limit advanced composition
- **WHEN** a caller needs strategy order not represented by `Retry<T>` convenience fields
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list

#### Scenario: Custom pipeline accepts telemetry
- **WHEN** a caller constructs a pipeline with telemetry options
- **THEN** the pipeline emits telemetry through those options during execution

### Requirement: Document custom order semantics
The package SHALL document that custom pipeline order changes fallback handling, retry visibility, timeout scope, rate limiting scope, hedging scope, injection scope, and circuit breaker failure counting.

#### Scenario: Documentation warns about order changes
- **WHEN** documentation shows custom pipeline usage
- **THEN** it explains that custom order is the main model for advanced composition and changes observable behavior

#### Scenario: Documentation explains injection placement
- **WHEN** documentation shows injection strategy usage
- **THEN** it explains that placement controls whether retry, timeout, fallback, circuit breaker, hedging, or rate limiter strategies observe the injection behavior

### Requirement: Cancellation bypasses pipeline recovery
The pipeline SHALL preserve cancellation as cancellation across strategy boundaries.

#### Scenario: Cancellation reaches caller
- **WHEN** cancellation is thrown inside a pipeline execution
- **THEN** the caller receives the cancellation failure unless it is outside the pipeline and explicitly handled by caller code

### Requirement: Accept custom pipeline strategies
`RetryPipeline<T>` SHALL accept caller-defined `RetryPipelineStrategy<T>` implementations as first-class ordered strategies.

#### Scenario: Multiple custom strategies wrap operation in order
- **WHEN** a caller constructs a pipeline with multiple custom strategies
- **THEN** the pipeline applies those strategies in caller-provided order around the operation

#### Scenario: Custom strategy uses shared pipeline context
- **WHEN** a custom pipeline strategy executes
- **THEN** it receives the shared `RetryPipelineContext<T>` with cancellation, elapsed time, phase, random source, timing helpers, and telemetry support
- **AND** it cannot read retry attempt-local metadata from that context

### Requirement: Preserve canonical retry facade while allowing custom pipeline order
The package SHALL keep `Retry<T>` as a convenience facade while allowing arbitrary custom order through `RetryPipeline<T>`.

#### Scenario: Retry remains convenience API
- **WHEN** a caller uses `Retry<T>`
- **THEN** the retry facade builds a documented convenience strategy order

#### Scenario: Pipeline supports advanced custom order
- **WHEN** a caller needs order different from the convenience retry order
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list

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

### Requirement: Cover pipeline behavior parity
The pipeline test suite SHALL cover execution, ordering, nesting, context visibility, and cross-strategy scope behavior represented by the reference suite and rp pipeline specs.

#### Scenario: Empty pipeline is transparent
- **WHEN** a pipeline has no strategies
- **THEN** tests SHALL prove synchronous and asynchronous result/error behavior is unchanged

#### Scenario: Strategy order defines scope
- **WHEN** a pipeline contains multiple strategies
- **THEN** tests SHALL prove earlier strategies wrap later strategies and observe inner outcomes according to order

#### Scenario: Same-kind strategies are nested
- **WHEN** a pipeline contains multiple strategies of the same kind
- **THEN** tests SHALL prove each strategy instance applies to the inner pipeline it wraps

#### Scenario: Pipeline context hides retry attempt state
- **WHEN** a non-retry strategy or custom strategy receives pipeline context
- **THEN** tests SHALL prove retry attempt number, retry index, and retry-local outcome are not exposed through pipeline context

#### Scenario: Order-dependent composition differs predictably
- **WHEN** retry, timeout, fallback, circuit breaker, hedging, rate limiter, or injection strategies are placed in different orders
- **THEN** tests SHALL prove the changed scope and outcome are consistent with explicit pipeline ordering

#### Scenario: Pipeline telemetry remains ordered
- **WHEN** a pipeline execution triggers multiple strategy events
- **THEN** tests SHALL prove telemetry events are emitted in decision order with pipeline and strategy source identity

