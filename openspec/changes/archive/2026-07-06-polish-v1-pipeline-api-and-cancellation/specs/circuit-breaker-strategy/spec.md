## ADDED Requirements

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
