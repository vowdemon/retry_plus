## ADDED Requirements

### Requirement: Emit fallback telemetry and hook
Fallback strategy SHALL emit lifecycle telemetry for handling, applied, and failed fallback decisions and SHALL invoke `onFallback` before executing the fallback callback.

#### Scenario: Fallback handling starts
- **WHEN** fallback applicability matches a final outcome
- **THEN** telemetry listeners receive `fallback.handling` and the configured `onFallback` hook is invoked before the fallback callback runs

#### Scenario: Fallback result is applied
- **WHEN** the fallback callback returns a fallback result
- **THEN** telemetry listeners receive `fallback.applied` before the fallback result is returned to the outer pipeline

#### Scenario: Fallback callback fails
- **WHEN** the fallback callback throws or returns a failed future
- **THEN** telemetry listeners receive `fallback.failed` with the fallback failure before that failure is propagated
