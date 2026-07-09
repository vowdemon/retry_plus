## MODIFIED Requirements

### Requirement: Emit rate limiter rejection hook
The rate limiter strategy SHALL expose `rate_limiter.rejected` telemetry and an asynchronous rejection hook invoked before returning or throwing a rate-limit rejection failure.

#### Scenario: Rejection hook runs
- **WHEN** the limiter rejects execution
- **THEN** telemetry listeners receive `rate_limiter.rejected` and the strategy invokes the configured rejection hook with context, lease metadata, and limiter metadata

#### Scenario: Outer retry handles rejection
- **WHEN** a retry strategy wraps a rate limiter strategy and matches the rate-limit rejection failure
- **THEN** retry can schedule another attempt according to its retry decision and delay strategy
