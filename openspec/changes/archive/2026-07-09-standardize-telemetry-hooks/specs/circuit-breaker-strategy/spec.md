## MODIFIED Requirements

### Requirement: Emit circuit lifecycle hooks
The circuit breaker SHALL expose asynchronous hooks and telemetry for opened, half-opened, closed, and rejected lifecycle events.

#### Scenario: Open hook runs
- **WHEN** the circuit transitions to open
- **THEN** telemetry listeners receive `circuit.opened` and the configured hook receives state, outcome, break duration, and context metadata

#### Scenario: Half-open hook runs
- **WHEN** the circuit transitions from open to half-open
- **THEN** telemetry listeners receive `circuit.half_opened` and the configured hook receives context metadata before the probe execution continues

#### Scenario: Closed hook runs
- **WHEN** the circuit transitions to closed
- **THEN** telemetry listeners receive `circuit.closed` and the configured hook receives previous-state and context metadata

#### Scenario: Rejected hook runs
- **WHEN** an open or isolated circuit rejects execution
- **THEN** telemetry listeners receive `circuit.rejected` and the configured hook receives rejection metadata including retry-after when available
