## ADDED Requirements

### Requirement: Use ordered strategy composition as authoritative scope
The package SHALL use explicit `RetryPipeline<T>` strategy order as the authoritative model for strategy scope, interaction, and visibility.

#### Scenario: Earlier strategy wraps later strategy
- **WHEN** a caller constructs a pipeline with strategies `[A, B, C]`
- **THEN** strategy `A` wraps `B`, strategy `B` wraps `C`, and strategy `C` wraps the user operation

#### Scenario: Outer strategy sees inner outcome
- **WHEN** an inner strategy returns a result or throws an exception
- **THEN** the directly wrapping outer strategy can observe that outcome according to its contract

### Requirement: Support multiple strategies of the same kind
The pipeline SHALL allow callers to place multiple instances of the same strategy kind in one pipeline.

#### Scenario: Multiple timeouts are nested
- **WHEN** a caller places two timeout strategies at different positions
- **THEN** each timeout applies to the inner pipeline it wraps

#### Scenario: Multiple retries are nested
- **WHEN** a caller places two retry strategies at different positions
- **THEN** each retry strategy retries the inner pipeline it wraps according to its own retry decision and delay

### Requirement: Support execution context for cooperative strategies
The pipeline SHALL provide enough execution context for strategies to coordinate cancellation, metadata, and operation invocation in advanced scenarios such as hedging and timeout.

#### Scenario: Strategy creates child execution
- **WHEN** a strategy such as hedging starts an additional action
- **THEN** it can provide that action with context metadata and cooperative cancellation state

## MODIFIED Requirements

### Requirement: Apply canonical strategy order
The high-level policy SHALL provide a convenience default order, but explicit `RetryPipeline<T>` ordering SHALL be the primary API for advanced strategy composition.

#### Scenario: Fallback handles circuit-open failure
- **WHEN** the convenience policy order places fallback outside circuit breaker and the circuit breaker rejects execution
- **THEN** fallback can return the fallback result without invoking retry or the user operation

#### Scenario: Retry wraps inner timeout by explicit order
- **WHEN** a caller places retry outside timeout in an explicit pipeline
- **THEN** every retry attempt executes the inner pipeline through the timeout strategy

#### Scenario: Timeout wraps retry by explicit order
- **WHEN** a caller places timeout outside retry in an explicit pipeline
- **THEN** the timeout applies to the whole retry flow including retry delays

### Requirement: Support explicit custom pipeline order
The package SHALL provide an explicit advanced API for constructing a `RetryPipeline<T>` with caller-defined strategy order.

#### Scenario: Custom order follows caller list
- **WHEN** a caller constructs a custom pipeline with strategies in a specific order
- **THEN** the pipeline applies strategies in that caller-defined order

#### Scenario: High-level policy does not limit advanced composition
- **WHEN** a caller needs strategy order not represented by `RetryPolicy<T>` convenience fields
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list

### Requirement: Document custom order semantics
The package SHALL document that custom pipeline order changes fallback handling, retry visibility, timeout scope, rate limiting scope, hedging scope, and circuit breaker failure counting.

#### Scenario: Documentation warns about order changes
- **WHEN** documentation shows custom pipeline usage
- **THEN** it explains that custom order is the main model for advanced composition and changes observable behavior

### Requirement: Preserve canonical policy while allowing custom pipeline order
The package SHALL keep `RetryPolicy<T>` as a convenience facade while allowing arbitrary custom order through `RetryPipeline<T>`.

#### Scenario: Policy remains convenience API
- **WHEN** a caller uses `RetryPolicy<T>`
- **THEN** the policy builds a documented convenience strategy order

#### Scenario: Pipeline supports advanced custom order
- **WHEN** a caller needs order different from the convenience policy order
- **THEN** the caller can construct `RetryPipeline<T>` directly with the desired strategy list
