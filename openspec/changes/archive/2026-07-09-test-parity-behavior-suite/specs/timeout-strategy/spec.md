## ADDED Requirements

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
