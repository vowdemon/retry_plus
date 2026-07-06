## ADDED Requirements

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
