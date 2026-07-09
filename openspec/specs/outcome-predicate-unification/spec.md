## Purpose

Defines shared outcome-context and context-predicate composition behavior for strategy predicate families.
## Requirements
### Requirement: Expose shared outcome context contract
The package SHALL provide a shared public outcome-context contract for strategy contexts that classify a completed execution outcome.

#### Scenario: Strategy context exposes common outcome metadata
- **WHEN** fallback, circuit breaker, hedging, or generic outcome predicate code receives a strategy context
- **THEN** that context exposes the outcome, retry context, and elapsed time through the shared outcome-context contract

#### Scenario: Strategy context keeps strategy-specific metadata
- **WHEN** a strategy needs additional metadata such as fallback-specific failure handling or hedging execution identity
- **THEN** that metadata remains on the strategy-specific context in addition to the shared outcome-context contract

### Requirement: Provide reusable context predicate composition
The package SHALL provide a reusable public context-predicate base that composes predicates by context type and concrete predicate type.

#### Scenario: Predicate family reuses OR composition
- **WHEN** a strategy predicate family implements the shared context-predicate base
- **THEN** OR composition is provided without a strategy-specific private OR predicate class

#### Scenario: Predicate family reuses AND composition
- **WHEN** a strategy predicate family implements the shared context-predicate base
- **THEN** AND composition is provided without a strategy-specific private AND predicate class

#### Scenario: Predicate family reuses NOT composition
- **WHEN** a strategy predicate family implements the shared context-predicate base
- **THEN** NOT composition is provided without a strategy-specific private NOT predicate class

#### Scenario: Async predicate composition preserves boolean semantics
- **WHEN** composed predicates return futures
- **THEN** OR, AND, and NOT composition evaluates them with the same boolean semantics as synchronous predicates

### Requirement: Normalize built-in outcome predicate factories
Built-in outcome-classification predicates SHALL use consistent factory semantics across generic outcome, fallback, circuit breaker, and hedging predicate families.

#### Scenario: Exception predicate matches exception outcomes
- **WHEN** an exception predicate evaluates an exception outcome
- **THEN** it matches according to its configured exception condition and does not match cancellation unless explicitly documented by that strategy

#### Scenario: Result predicate matches result outcomes
- **WHEN** a result predicate evaluates a successful result outcome
- **THEN** it matches according to its configured result condition

#### Scenario: Any predicate matches allowed non-cancellation outcomes
- **WHEN** an any predicate evaluates a non-cancellation outcome that the strategy is allowed to handle
- **THEN** it matches that outcome

#### Scenario: Never predicate matches no outcome
- **WHEN** a never predicate evaluates any outcome
- **THEN** it does not match

### Requirement: Provide shared outcome access helpers
The package SHALL provide shared helpers for reading result, error, and stack trace information from outcome contexts.

#### Scenario: Helper reads result from successful outcome
- **WHEN** a caller reads the result helper from an outcome context with a successful result
- **THEN** the helper returns that result

#### Scenario: Helper reads error metadata from failed outcome
- **WHEN** a caller reads error and stack trace helpers from an outcome context with a failed outcome
- **THEN** the helpers return the failed outcome metadata

#### Scenario: Helper rejects unavailable metadata
- **WHEN** a caller reads result metadata from a failed outcome or error metadata from a successful outcome
- **THEN** the helper throws a clear state error rather than returning misleading data

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

