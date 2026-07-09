## ADDED Requirements

### Requirement: Support failure ratio circuit metering
The circuit breaker SHALL support opening based on the ratio of handled failures within a sampling duration after minimum throughput is reached.

#### Scenario: Failure ratio opens circuit
- **WHEN** the number of sampled executions reaches minimum throughput and the handled failure ratio meets or exceeds the configured threshold
- **THEN** the circuit breaker transitions to open state

#### Scenario: Minimum throughput prevents opening
- **WHEN** the handled failure ratio exceeds the threshold but sampled executions are below minimum throughput
- **THEN** the circuit breaker remains closed

### Requirement: Generate break duration
The circuit breaker SHALL support fixed and generated break durations using circuit-open metadata.

#### Scenario: Generated break duration is used
- **WHEN** the break duration generator returns a duration after the circuit opens
- **THEN** the circuit remains open for that generated duration before allowing half-open probes

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
The circuit breaker SHALL expose asynchronous hooks for opened, half-opened, closed, and rejected events.

#### Scenario: Open hook runs
- **WHEN** the circuit transitions to open
- **THEN** the configured hook receives state, outcome, break duration, and context metadata

#### Scenario: Rejected hook runs
- **WHEN** an open or isolated circuit rejects execution
- **THEN** the configured hook receives rejection metadata including retry-after when available

## MODIFIED Requirements

### Requirement: Open circuit after configured failures
The circuit breaker SHALL open after the configured circuit meter determines that handled outcomes have exceeded the configured threshold.

#### Scenario: Failure threshold opens circuit
- **WHEN** guarded executions produce handled outcomes enough times to satisfy a consecutive-failure meter
- **THEN** the circuit breaker transitions to open state and emits a state-change event

#### Scenario: Unhandled outcome does not open circuit
- **WHEN** guarded executions produce outcomes that do not match the circuit failure predicate
- **THEN** those outcomes do not contribute to opening the circuit

### Requirement: Classify circuit breaker failures
Circuit breaker strategy SHALL allow callers to configure which final result or exception outcomes count toward opening the circuit.

#### Scenario: Non-matching failure does not count
- **WHEN** a guarded execution fails with an exception outcome that does not match the circuit failure predicate
- **THEN** circuit breaker state and failure count remain unchanged

#### Scenario: Matching exception counts
- **WHEN** a guarded execution fails with an exception outcome that matches the circuit failure predicate
- **THEN** circuit breaker records one handled guarded execution failure

#### Scenario: Matching result counts
- **WHEN** a guarded execution returns a result outcome that matches the circuit failure predicate
- **THEN** circuit breaker records one handled guarded execution failure

### Requirement: Support custom circuit failure predicates
Circuit failure predicates SHALL remain open to caller-defined outcome classification through documented public extension contracts and callback-based factories.

#### Scenario: Custom circuit failure predicate class controls failure accounting
- **WHEN** a caller supplies a custom circuit failure predicate implementation
- **THEN** the circuit breaker uses that predicate to decide whether a guarded execution outcome counts toward opening the circuit

#### Scenario: Custom circuit failure predicate callback controls failure accounting
- **WHEN** a caller supplies a callback-based circuit failure predicate
- **THEN** the circuit breaker uses that callback with typed outcome metadata

#### Scenario: Custom circuit failure predicate composes with built-ins
- **WHEN** a custom circuit failure predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics
