## ADDED Requirements

### Requirement: Cover telemetry behavior parity
The telemetry test suite SHALL cover structured event identity, source identity, listener behavior, severity, pipeline lifecycle, and strategy telemetry represented by the reference suite and rp telemetry specs.

#### Scenario: Event identity is stable
- **WHEN** built-in or custom telemetry events are emitted
- **THEN** tests SHALL prove event types expose stable string names and custom const event types remain supported

#### Scenario: Source identity is emitted
- **WHEN** telemetry is emitted from a pipeline or strategy
- **THEN** tests SHALL prove pipeline key, operation key, and strategy name are available when configured

#### Scenario: Listener fan-out is isolated
- **WHEN** multiple listeners are configured and one listener fails
- **THEN** tests SHALL prove later listeners still receive events and execution behavior is not affected

#### Scenario: Severity can suppress events
- **WHEN** severity provider maps an event to suppression
- **THEN** tests SHALL prove the listener does not receive the suppressed event

#### Scenario: Pipeline lifecycle is observed
- **WHEN** a pipeline succeeds, fails, or is cancelled
- **THEN** tests SHALL prove lifecycle telemetry carries outcome, error, stack trace, cancellation state, duration, and source data as applicable

#### Scenario: Strategy telemetry is observed
- **WHEN** retry, timeout, fallback, circuit breaker, rate limiter, hedging, or injection emits telemetry
- **THEN** tests SHALL prove the event name, strategy name, handled flag, outcome, duration, and attributes are correct for that strategy event
