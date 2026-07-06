## ADDED Requirements

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
