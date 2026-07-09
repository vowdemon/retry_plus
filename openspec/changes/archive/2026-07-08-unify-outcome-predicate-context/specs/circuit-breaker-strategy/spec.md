## MODIFIED Requirements

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
