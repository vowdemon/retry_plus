## Purpose

Defines circuit breaker behavior for guarding pipeline executions.
## Requirements
### Requirement: Protect execution with circuit breaker states
The package SHALL provide a circuit breaker strategy with closed, open, half-open, and isolated states.

#### Scenario: Closed circuit allows execution
- **WHEN** the circuit breaker is closed
- **THEN** the pipeline allows the guarded operation chain to execute

#### Scenario: Open circuit rejects execution
- **WHEN** the circuit breaker is open and the recovery duration has not elapsed
- **THEN** the pipeline rejects execution without invoking retry or the user operation

#### Scenario: Isolated circuit rejects execution
- **WHEN** the circuit breaker is manually isolated
- **THEN** the pipeline rejects execution until the circuit is manually closed

### Requirement: Open circuit after configured failures
The circuit breaker SHALL open after the configured circuit meter determines that handled outcomes have exceeded the configured threshold.

#### Scenario: Failure threshold opens circuit
- **WHEN** guarded executions produce handled outcomes enough times to satisfy a consecutive-failure meter
- **THEN** the circuit breaker transitions to open state and emits a state-change event

#### Scenario: Unhandled outcome does not open circuit
- **WHEN** guarded executions produce outcomes that do not match the circuit failure predicate
- **THEN** those outcomes do not contribute to opening the circuit

### Requirement: Support failure ratio circuit metering
The circuit breaker SHALL support opening based on the ratio of handled failures within a sampling duration after minimum throughput is reached.

#### Scenario: Failure ratio opens circuit
- **WHEN** the number of sampled executions reaches minimum throughput and the handled failure ratio meets or exceeds the configured threshold
- **THEN** the circuit breaker transitions to open state

#### Scenario: Minimum throughput prevents opening
- **WHEN** the handled failure ratio exceeds the threshold but sampled executions are below minimum throughput
- **THEN** the circuit breaker remains closed

### Requirement: Transition through half-open probes
The circuit breaker SHALL transition from open to half-open after the configured recovery duration and use probe executions to decide whether to close or reopen.

#### Scenario: Successful probe closes circuit
- **WHEN** the recovery duration has elapsed and the configured half-open probe succeeds
- **THEN** the circuit breaker transitions to closed state

#### Scenario: Failed probe reopens circuit
- **WHEN** the recovery duration has elapsed and the half-open probe fails
- **THEN** the circuit breaker transitions back to open state

### Requirement: Generate break duration
The circuit breaker SHALL support fixed and generated break durations using circuit-open metadata.

#### Scenario: Generated break duration is used
- **WHEN** the break duration generator returns a duration after the circuit opens
- **THEN** the circuit remains open for that generated duration before allowing half-open probes

### Requirement: Share breaker state across policy executions
Circuit breaker state SHALL belong to the `CircuitBreaker` instance rather than a single execution.

#### Scenario: Policy instance remembers open state
- **WHEN** one execution opens the circuit breaker
- **THEN** a later execution through the same policy instance observes the open circuit state

### Requirement: Count failures per guarded execution
The high-level policy SHALL count one circuit breaker success or failure per guarded pipeline execution rather than per retry attempt.

#### Scenario: Retry exhaustion counts as one breaker failure
- **WHEN** retry performs multiple failed attempts and then gives up
- **THEN** the circuit breaker records one guarded execution failure

### Requirement: Do not count cancellation as circuit failure
Circuit breaker strategy SHALL rethrow cancellation without evaluating circuit failure predicates or recording a guarded execution failure.

#### Scenario: Cancellation does not open circuit
- **WHEN** a guarded execution is cancelled
- **THEN** circuit breaker state and failure count remain unchanged

#### Scenario: Cancellation bypasses custom circuit predicate
- **WHEN** a guarded execution is cancelled and a custom circuit failure predicate is configured
- **THEN** the custom predicate is not evaluated and circuit breaker state remains unchanged

### Requirement: Classify circuit breaker failures
Circuit breaker strategy SHALL allow callers to configure which final outcomes count toward opening the circuit through shared outcome-context predicate semantics.

#### Scenario: Non-matching failure does not count
- **WHEN** a guarded execution fails with a failure that does not match the circuit failure predicate
- **THEN** circuit breaker state and failure count remain unchanged

#### Scenario: Matching failure counts
- **WHEN** a guarded execution fails with a failure that matches the circuit failure predicate
- **THEN** circuit breaker records one guarded execution failure

#### Scenario: Matching result outcome counts
- **WHEN** a guarded execution completes with a result outcome that matches the circuit failure predicate
- **THEN** circuit breaker records one guarded execution failure

### Requirement: Expose circuit state provider
The circuit breaker SHALL expose a public state provider that allows callers to observe current circuit state without mutating it.

#### Scenario: Caller reads state
- **WHEN** circuit breaker state changes
- **THEN** the state provider reports the current state to callers

### Requirement: Support manual circuit control
The circuit breaker SHALL support manual isolate and close operations through a public control object.

#### Scenario: Circuit is manually isolated
- **WHEN** a caller manually isolates the circuit
- **THEN** guarded executions are rejected until the circuit is manually closed

#### Scenario: Circuit is manually closed
- **WHEN** a caller manually closes an isolated or open circuit
- **THEN** subsequent guarded executions can proceed according to normal closed-state rules

### Requirement: Emit circuit lifecycle hooks
The circuit breaker SHALL expose asynchronous hooks and telemetry for opened, half-opened, closed, and rejected lifecycle events.

#### Scenario: Open hook runs
- **WHEN** the circuit transitions to open
- **THEN** telemetry listeners receive `circuit.opened` and the configured hook receives state, outcome, break duration, and context metadata

#### Scenario: Half-open hook runs
- **WHEN** the circuit transitions from open to half-open
- **THEN** telemetry listeners receive `circuit.half_opened` and the configured hook receives context metadata before the probe execution continues

#### Scenario: Closed hook runs
- **WHEN** the circuit transitions to closed
- **THEN** telemetry listeners receive `circuit.closed` and the configured hook receives previous-state and context metadata

#### Scenario: Rejected hook runs
- **WHEN** an open or isolated circuit rejects execution
- **THEN** telemetry listeners receive `circuit.rejected` and the configured hook receives rejection metadata including retry-after when available

### Requirement: Compose circuit failure predicates
Circuit failure predicates SHALL support OR, AND, and NOT composition through the shared context-predicate composition model.

#### Scenario: Negated circuit failure predicate excludes condition
- **WHEN** a broad circuit failure predicate is combined with the negation of a more specific predicate
- **THEN** failures matching the negated predicate do not count toward opening the circuit

#### Scenario: Circuit composition uses shared implementation
- **WHEN** circuit failure predicates are composed
- **THEN** the behavior does not depend on circuit-specific private OR, AND, or NOT predicate classes

### Requirement: Support custom circuit failure predicates
Circuit failure predicates SHALL remain open to caller-defined failure classification through documented public extension contracts and callback-based factories based on circuit failure contexts that implement the shared outcome-context contract.

#### Scenario: Custom circuit failure predicate class controls failure accounting
- **WHEN** a caller supplies a custom `CircuitFailurePredicate` implementation
- **THEN** the circuit breaker uses that predicate to decide whether a guarded execution failure counts toward opening the circuit

#### Scenario: Custom circuit failure predicate callback controls failure accounting
- **WHEN** a caller supplies a callback-based circuit failure predicate
- **THEN** the circuit breaker uses that callback with `CircuitFailureContext`

#### Scenario: Custom circuit failure predicate composes with built-ins
- **WHEN** a custom circuit failure predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics

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

