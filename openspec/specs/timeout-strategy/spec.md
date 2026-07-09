## Purpose

Defines position-scoped timeout strategy behavior for retry pipeline execution.
## Requirements
### Requirement: Apply position-scoped timeout
The package SHALL provide a timeout strategy whose scope is determined by its position in the ordered pipeline.

#### Scenario: Timeout inside retry scopes each attempt
- **WHEN** a retry strategy wraps a timeout strategy
- **THEN** each retry attempt receives a fresh timeout budget from the inner timeout strategy

#### Scenario: Timeout outside retry scopes whole retry flow
- **WHEN** a timeout strategy wraps a retry strategy
- **THEN** the timeout budget includes all retry attempts and retry delays executed by the inner retry strategy

#### Scenario: Multiple timeouts compose by position
- **WHEN** a pipeline includes nested timeout strategies
- **THEN** each timeout applies only to the inner pipeline it wraps

### Requirement: Support generated timeout durations
Timeout strategy SHALL support fixed and generated timeout durations using pipeline context.

#### Scenario: Timeout generator returns duration
- **WHEN** the timeout duration generator returns a positive duration
- **THEN** the strategy applies that duration to the wrapped inner pipeline

#### Scenario: Timeout generator disables timeout
- **WHEN** the timeout duration generator returns a value indicating no timeout
- **THEN** the strategy invokes the inner pipeline without applying a timeout for that execution

### Requirement: Observe cancellation with timeout
Timeout strategy SHALL distinguish caller cancellation from timeout cancellation and MUST NOT report caller cancellation as timeout.

#### Scenario: Cancellation wins before timeout
- **WHEN** cancellation is requested before a timeout duration expires
- **THEN** execution completes with cancellation rather than timeout

#### Scenario: Strategy timeout creates timeout failure
- **WHEN** the timeout strategy's own budget expires and the inner pipeline observes that cancellation
- **THEN** execution completes with a timeout failure visible to outer strategies

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

### Requirement: Cover timeout behavior parity
The timeout test suite SHALL cover timeout behavior classes represented by the reference suite while preserving rp's position-scoped timeout model.

#### Scenario: Timeout preserves fast operations
- **WHEN** the guarded operation completes before the timeout duration
- **THEN** tests SHALL prove the original result or error is preserved

#### Scenario: Timeout fails slow operations
- **WHEN** the guarded operation exceeds the timeout duration
- **THEN** tests SHALL prove timeout produces the rp timeout failure and records timeout metadata

#### Scenario: Timeout duration is computed per execution
- **WHEN** timeout uses a computed duration
- **THEN** tests SHALL cover generated durations and generated disabled timeout behavior

#### Scenario: Caller cancellation wins over timeout
- **WHEN** caller cancellation occurs before timeout
- **THEN** tests SHALL prove cancellation reaches the caller and timeout hooks or timeout telemetry are not emitted

#### Scenario: Timeout observations are emitted only for timeout
- **WHEN** timeout actually rejects an execution
- **THEN** tests SHALL cover timeout hook arguments, hook ordering, telemetry event data, and strategy name

