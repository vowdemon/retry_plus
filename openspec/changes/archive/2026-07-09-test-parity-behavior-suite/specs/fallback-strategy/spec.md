## ADDED Requirements

### Requirement: Cover fallback behavior parity
The fallback test suite SHALL cover fallback behavior classes represented by the reference suite while expressing fallback applicability through rp outcome predicates.

#### Scenario: Fallback handles matching outcomes
- **WHEN** fallback receives a matching exception or result outcome
- **THEN** tests SHALL prove fallback returns the configured or computed fallback result

#### Scenario: Fallback preserves non-matching outcomes
- **WHEN** fallback receives a non-matching exception or result outcome
- **THEN** tests SHALL prove the original outcome is preserved

#### Scenario: Fallback callback receives outcome context
- **WHEN** fallback computes a value through a callback
- **THEN** tests SHALL prove the callback can read result, error, stack trace, elapsed time, and pipeline context through public helpers

#### Scenario: Fallback callback failure propagates
- **WHEN** fallback callback or fallback hook throws
- **THEN** tests SHALL prove the hook or callback failure is propagated according to rp hook semantics

#### Scenario: Fallback bypasses cancellation
- **WHEN** the guarded outcome is cancellation
- **THEN** tests SHALL prove fallback does not handle it, even when using broad fallback predicates

#### Scenario: Fallback emits lifecycle observations
- **WHEN** fallback starts, applies, or fails
- **THEN** tests SHALL cover hook arguments, telemetry event data, strategy name, and ordering
