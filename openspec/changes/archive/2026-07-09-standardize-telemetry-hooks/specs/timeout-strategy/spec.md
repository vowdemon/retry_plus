## ADDED Requirements

### Requirement: Emit timeout telemetry and hook
Timeout strategy SHALL emit `timeout.timed_out` telemetry and expose an awaited timeout side-effect hook when its own timeout budget expires.

#### Scenario: Timeout emits timed-out telemetry
- **WHEN** the timeout strategy's own budget expires
- **THEN** telemetry listeners receive `timeout.timed_out` with timeout duration and timeout error

#### Scenario: Timeout hook runs
- **WHEN** the timeout strategy's own budget expires
- **THEN** the strategy invokes the configured timeout hook with timeout duration, timeout error, and pipeline context before rethrowing the timeout error

#### Scenario: Caller cancellation bypasses timeout telemetry and hook
- **WHEN** caller cancellation wins before the timeout budget expires
- **THEN** the timeout strategy does not emit `timeout.timed_out` and does not invoke the timeout hook
