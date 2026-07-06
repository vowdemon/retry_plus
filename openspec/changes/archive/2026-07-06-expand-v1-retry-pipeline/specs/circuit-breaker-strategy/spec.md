## ADDED Requirements

### Requirement: Protect execution with circuit breaker states
The package SHALL provide a circuit breaker strategy with closed, open, and half-open states.

#### Scenario: Closed circuit allows execution
- **WHEN** the circuit breaker is closed
- **THEN** the pipeline allows the guarded operation chain to execute

#### Scenario: Open circuit rejects execution
- **WHEN** the circuit breaker is open and the recovery duration has not elapsed
- **THEN** the pipeline rejects execution without invoking retry or the user operation

### Requirement: Open circuit after configured failures
The circuit breaker SHALL open after the configured failure threshold is reached.

#### Scenario: Failure threshold opens circuit
- **WHEN** guarded executions fail enough times to meet the configured threshold
- **THEN** the circuit breaker transitions to open state and emits a state-change event

### Requirement: Transition through half-open probes
The circuit breaker SHALL transition from open to half-open after the configured recovery duration and use probe executions to decide whether to close or reopen.

#### Scenario: Successful probe closes circuit
- **WHEN** the recovery duration has elapsed and the configured half-open probe succeeds
- **THEN** the circuit breaker transitions to closed state

#### Scenario: Failed probe reopens circuit
- **WHEN** the recovery duration has elapsed and the half-open probe fails
- **THEN** the circuit breaker transitions back to open state

### Requirement: Share breaker state across policy executions
Circuit breaker state SHALL belong to the strategy or policy instance rather than a single execution.

#### Scenario: Policy instance remembers open state
- **WHEN** one execution opens the circuit breaker
- **THEN** a later execution through the same policy instance observes the open circuit state

### Requirement: Count failures per guarded execution
The high-level policy SHALL count one circuit breaker success or failure per guarded pipeline execution rather than per retry attempt.

#### Scenario: Retry exhaustion counts as one breaker failure
- **WHEN** retry performs multiple failed attempts and then gives up
- **THEN** the circuit breaker records one guarded execution failure
