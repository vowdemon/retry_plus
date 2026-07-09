## ADDED Requirements

### Requirement: Cover unified predicate behavior parity
The predicate-unification test suite SHALL prove all strategy predicate families reuse common context predicate semantics while preserving strategy-specific context metadata.

#### Scenario: Predicate composition is shared
- **WHEN** retry, fallback, circuit breaker, hedging, or injection predicates compose with OR, AND, or NOT
- **THEN** tests SHALL prove the composition follows the same async boolean semantics

#### Scenario: Built-in predicates match outcome classes
- **WHEN** built-in predicates target exception outcomes, result outcomes, any non-cancellation outcome, or never
- **THEN** tests SHALL prove they match only the intended outcome classes

#### Scenario: Strategy-specific context remains available
- **WHEN** a predicate receives strategy-specific context
- **THEN** tests SHALL prove the common predicate model does not erase strategy-specific metadata
