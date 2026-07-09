## ADDED Requirements

### Requirement: Define structured telemetry events
The package SHALL provide `TelemetryEvent<T>` with event type, source, severity, timestamp, elapsed time, optional duration, optional outcome, optional error, optional stack trace, and structured attributes.

#### Scenario: Listener receives structured event
- **WHEN** a pipeline emits a telemetry event
- **THEN** telemetry listeners receive a `TelemetryEvent<T>` with strongly typed core fields and event-specific attributes

#### Scenario: Event can carry outcome
- **WHEN** a strategy observes a result or error outcome
- **THEN** the telemetry event can carry a `StrategyOutcome<T>` representing that outcome

### Requirement: Support extensible telemetry event types
The package SHALL define `TelemetryEventType` as an extensible const value type with built-in constants for package events.

#### Scenario: Custom strategy emits custom event type
- **WHEN** a custom strategy emits a const `TelemetryEventType`
- **THEN** telemetry listeners receive that event type without requiring a package-defined enum member

### Requirement: Identify telemetry source
Telemetry events SHALL include `TelemetrySource` with optional pipeline key and operation key.

#### Scenario: Pipeline key is emitted
- **WHEN** a named pipeline emits a telemetry event
- **THEN** the event source includes the pipeline key when configured

#### Scenario: Operation key is emitted
- **WHEN** a caller executes an operation with an operation key
- **THEN** telemetry events for that execution include the operation key

### Requirement: Assign telemetry severity
Telemetry events SHALL have a `TelemetrySeverity` assigned by default and MAY be overridden or suppressed by a caller-provided severity provider.

#### Scenario: Default severity is assigned
- **WHEN** a retry, timeout, fallback, circuit breaker, rate limiter, hedging, injection, or pipeline lifecycle event is emitted
- **THEN** the event has a non-null default severity

#### Scenario: Severity provider changes severity
- **WHEN** a severity provider returns a different severity for an event
- **THEN** listeners receive the event with that severity

#### Scenario: Severity provider suppresses event
- **WHEN** a severity provider returns `TelemetrySeverity.none`
- **THEN** telemetry listeners do not receive that event

### Requirement: Fan out telemetry to listeners
The package SHALL provide `TelemetryOptions` with multiple `TelemetryListener` instances that all receive non-suppressed events.

#### Scenario: Multiple listeners receive event
- **WHEN** telemetry options contain multiple listeners
- **THEN** each listener receives every non-suppressed event in emission order

#### Scenario: Listener failure does not affect execution
- **WHEN** a telemetry listener throws while handling an event
- **THEN** pipeline execution continues according to resilience behavior

### Requirement: Emit pipeline lifecycle telemetry
The pipeline SHALL emit telemetry for pipeline start, completion, failure, and cancellation.

#### Scenario: Successful pipeline emits lifecycle
- **WHEN** a pipeline execution completes successfully
- **THEN** telemetry listeners receive pipeline started and completed events

#### Scenario: Failed pipeline emits lifecycle
- **WHEN** a pipeline execution fails with a non-cancellation error
- **THEN** telemetry listeners receive a failed event with the error and stack trace

#### Scenario: Cancelled pipeline emits lifecycle
- **WHEN** a pipeline execution is cancelled
- **THEN** telemetry listeners receive a cancelled event with the cancellation error

### Requirement: Emit strategy telemetry
Built-in strategies SHALL emit telemetry for retry scheduling, retry give-up, retry attempts, timeout, fallback, circuit breaker state changes and rejection, rate limiter rejection, hedging actions, and triggered injection behavior.

#### Scenario: Retry attempt emits telemetry
- **WHEN** a retry strategy completes an attempt
- **THEN** telemetry listeners receive retry attempt telemetry with attempt number, duration, handled flag, outcome, and next delay when known

#### Scenario: Retry scheduling emits telemetry
- **WHEN** a retry strategy schedules another attempt
- **THEN** telemetry listeners receive retry scheduled telemetry with attempt number and next delay

#### Scenario: Timeout emits telemetry
- **WHEN** a timeout strategy times out its inner execution
- **THEN** telemetry listeners receive timeout telemetry with timeout duration and error

#### Scenario: Fallback emits telemetry
- **WHEN** fallback produces a result
- **THEN** telemetry listeners receive fallback telemetry with the handled outcome

#### Scenario: Circuit breaker emits telemetry
- **WHEN** a circuit breaker opens, half-opens, closes, or rejects execution
- **THEN** telemetry listeners receive the corresponding circuit breaker telemetry

#### Scenario: Rate limiter emits telemetry
- **WHEN** a rate limiter rejects execution
- **THEN** telemetry listeners receive rate limiter rejection telemetry with retry-after when available

#### Scenario: Hedging emits telemetry
- **WHEN** hedging schedules an action, observes an outcome, or selects an outcome
- **THEN** telemetry listeners receive the corresponding hedging telemetry

#### Scenario: Injection emits telemetry
- **WHEN** an injection strategy triggers throw, delay, result, or behavior injection
- **THEN** telemetry listeners receive the corresponding injection telemetry

### Requirement: Keep telemetry independent from behavior
Telemetry SHALL NOT change retry, timeout, fallback, circuit breaker, rate limiter, hedging, injection, cancellation, or operation result behavior.

#### Scenario: Listener throws during success
- **WHEN** a telemetry listener throws during a successful execution
- **THEN** the caller still receives the operation result

#### Scenario: Listener throws during failure
- **WHEN** a telemetry listener throws during a failed execution
- **THEN** the caller still receives the original operation or strategy failure
