## ADDED Requirements

### Requirement: Cover circuit breaker behavior parity
The circuit breaker test suite SHALL cover circuit state, failure accounting, predicate, hook, telemetry, and manual control behavior represented by the reference suite.

#### Scenario: Circuit state transitions are observable
- **WHEN** failures open a circuit and recovery time passes
- **THEN** tests SHALL prove closed, open, half-open, closed-again, and reopened transitions

#### Scenario: Circuit rejects guarded execution by state
- **WHEN** the circuit is open or isolated
- **THEN** tests SHALL prove execution is rejected without invoking the guarded operation

#### Scenario: Circuit failure accounting follows predicates
- **WHEN** guarded executions produce matching and non-matching exceptions or results
- **THEN** tests SHALL prove only matching outcomes count as failures

#### Scenario: Circuit metering respects thresholds
- **WHEN** the breaker uses consecutive failure or failure-ratio metering
- **THEN** tests SHALL cover threshold, minimum throughput, sampling window, and reset-after-success behavior

#### Scenario: Retry exhaustion counts once for an outer breaker
- **WHEN** a circuit breaker guards an inner retry strategy
- **THEN** tests SHALL prove the whole inner retry flow counts as one guarded execution

#### Scenario: Circuit ignores cancellation
- **WHEN** guarded execution is cancelled
- **THEN** tests SHALL prove cancellation does not count as failure and bypasses custom circuit predicates

#### Scenario: Circuit lifecycle observations are emitted
- **WHEN** circuit opens, half-opens, closes, or rejects
- **THEN** tests SHALL cover hook arguments, telemetry event data, strategy name, state provider, and manual control behavior
