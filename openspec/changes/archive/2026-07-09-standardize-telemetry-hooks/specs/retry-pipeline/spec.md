## MODIFIED Requirements

### Requirement: Surface pipeline events
The pipeline SHALL emit structured telemetry events for strategy decisions, retries, timeout failures, fallback execution, circuit breaker state changes, cancellation, and final success or failure through configured telemetry listeners.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** telemetry listeners receive events in the order the decisions occur

#### Scenario: Pipeline success event is emitted
- **WHEN** a pipeline execution returns a result
- **THEN** telemetry listeners receive `pipeline.succeeded` before the returned result is delivered to the caller

#### Scenario: Pipeline failure event is emitted
- **WHEN** a pipeline execution fails with a non-cancellation error
- **THEN** telemetry listeners receive `pipeline.failed` with the error and stack trace

#### Scenario: Pipeline cancellation event is emitted
- **WHEN** a pipeline execution is cancelled
- **THEN** telemetry listeners receive `pipeline.cancelled` with the cancellation error
