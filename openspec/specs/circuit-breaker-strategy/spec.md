## Purpose

Defines circuit breaker strategy behavior for guarding pipeline executions.

## Requirements

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

### Requirement: Do not count cancellation as circuit failure
Circuit breaker strategy SHALL rethrow cancellation without recording a guarded execution failure.

#### Scenario: Cancellation does not open circuit
- **WHEN** a guarded execution is cancelled
- **THEN** circuit breaker state and failure count remain unchanged

### Requirement: Classify circuit breaker failures
Circuit breaker strategy SHALL allow callers to configure which final failures count toward opening the circuit.

#### Scenario: Non-matching failure does not count
- **WHEN** a guarded execution fails with a failure that does not match the circuit failure predicate
- **THEN** circuit breaker state and failure count remain unchanged

#### Scenario: Matching failure counts
- **WHEN** a guarded execution fails with a failure that matches the circuit failure predicate
- **THEN** circuit breaker records one guarded execution failure

### Requirement: Compose circuit failure predicates
Circuit failure predicates SHALL support OR, AND, and NOT composition.

#### Scenario: Negated circuit failure predicate excludes condition
- **WHEN** a broad circuit failure predicate is combined with the negation of a more specific predicate
- **THEN** failures matching the negated predicate do not count toward opening the circuit

### Requirement: Support custom circuit failure predicates
Circuit failure predicates SHALL remain open to caller-defined failure classification through documented public extension contracts and callback-based factories.

#### Scenario: Custom circuit failure predicate class controls failure accounting
- **WHEN** a caller supplies a custom `CircuitFailurePredicate` implementation
- **THEN** the circuit breaker uses that predicate to decide whether a guarded execution failure counts toward opening the circuit

#### Scenario: Custom circuit failure predicate callback controls failure accounting
- **WHEN** a caller supplies a callback-based circuit failure predicate
- **THEN** the circuit breaker uses that callback with `CircuitFailureContext`

#### Scenario: Custom circuit failure predicate composes with built-ins
- **WHEN** a custom circuit failure predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics
