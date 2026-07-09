## ADDED Requirements

### Requirement: Name built-in telemetry events consistently
Built-in telemetry event types SHALL use stable names shaped as `"<strategy>.<event>"`, where the strategy segment identifies the strategy category or pipeline lifecycle and the event segment identifies the lifecycle point.

#### Scenario: Listener filters by canonical name
- **WHEN** a built-in strategy emits telemetry
- **THEN** the event type name uses the documented strategy category and event name without requiring instance-specific labels

#### Scenario: Custom telemetry remains extensible
- **WHEN** a custom strategy emits a custom `TelemetryEventType`
- **THEN** the custom event type can use its own const name without changing built-in event constants

### Requirement: Preserve optional strategy instance names in telemetry source
Pipeline strategies SHALL expose an optional strategy instance name, and strategy-owned telemetry SHALL include that name in the telemetry source when present.

#### Scenario: Same-kind strategies are distinguishable
- **WHEN** a named built-in strategy emits telemetry
- **THEN** the event type remains the canonical lifecycle event and `TelemetrySource.strategyName` contains the strategy instance name

#### Scenario: Custom strategy identifies its own telemetry
- **WHEN** a custom strategy emits telemetry and supplies its strategy name
- **THEN** telemetry listeners can read the name from `TelemetrySource.strategyName`

### Requirement: Define canonical pipeline telemetry events
The package SHALL expose pipeline telemetry event types named `pipeline.started`, `pipeline.succeeded`, `pipeline.failed`, and `pipeline.cancelled`.

#### Scenario: Pipeline succeeds
- **WHEN** a pipeline execution returns a result
- **THEN** telemetry listeners receive `pipeline.started` before execution and `pipeline.succeeded` before the caller receives the result

#### Scenario: Pipeline fails
- **WHEN** a pipeline execution completes with a non-cancellation error
- **THEN** telemetry listeners receive `pipeline.failed` with the error and stack trace

#### Scenario: Pipeline is cancelled
- **WHEN** a pipeline execution completes with cancellation
- **THEN** telemetry listeners receive `pipeline.cancelled` with the cancellation error

### Requirement: Define canonical retry telemetry events
The package SHALL expose retry telemetry event types named `retry.attempt`, `retry.scheduled`, and `retry.give_up`.

#### Scenario: Retry attempt records continuation decision
- **WHEN** an attempt outcome is accepted by `retryIf` for another retry
- **THEN** telemetry listeners receive `retry.attempt` with handled metadata for that attempt

#### Scenario: Retry delay is scheduled
- **WHEN** retry delay calculation has produced the delay for the next retry
- **THEN** telemetry listeners receive `retry.scheduled` with the computed delay

#### Scenario: Retry gives up
- **WHEN** retry continuation is denied after at least one retry was handled
- **THEN** telemetry listeners receive `retry.give_up` before the final outcome is returned or thrown

### Requirement: Define canonical strategy telemetry events
The package SHALL expose strategy telemetry event types named `timeout.timed_out`, `fallback.handling`, `fallback.applied`, `fallback.failed`, `circuit.opened`, `circuit.half_opened`, `circuit.closed`, `circuit.rejected`, `rate_limiter.rejected`, `hedging.scheduled`, `hedging.outcome`, `hedging.selected`, `injection.throw`, `injection.delay`, `injection.result`, and `injection.behavior`.

#### Scenario: Strategy event uses strategy category
- **WHEN** timeout, fallback, circuit breaker, rate limiter, hedging, or injection emits telemetry
- **THEN** the event type name begins with the documented strategy category

#### Scenario: Strategy event uses lifecycle event
- **WHEN** a strategy emits telemetry for a decision or state change
- **THEN** the event type name identifies the specific lifecycle point rather than a broad strategy-only name

### Requirement: Separate telemetry from side-effect hooks
Telemetry SHALL be non-fatal observation, while `onXxx` hooks SHALL be awaited side-effect callbacks at documented lifecycle points.

#### Scenario: Telemetry listener throws
- **WHEN** a telemetry listener throws while handling an event
- **THEN** resilience execution continues according to strategy behavior

#### Scenario: Side-effect hook throws
- **WHEN** an `onXxx` side-effect hook throws
- **THEN** the hook failure is visible to the caller according to normal async error propagation

#### Scenario: Telemetry and hook share lifecycle point
- **WHEN** a strategy emits telemetry and invokes a hook for the same lifecycle point
- **THEN** the strategy emits telemetry before awaiting the hook

### Requirement: Keep injection hook surface minimal
Injection strategies SHALL use their configured trigger and behavior callbacks as behavior extension points and SHALL NOT add a separate generic injection side-effect hook.

#### Scenario: Injection is observed through telemetry
- **WHEN** an injection strategy triggers
- **THEN** telemetry listeners receive the corresponding injection event without requiring an injection hook
- **AND** the event attributes do not repeat the injection kind already encoded by the event type
