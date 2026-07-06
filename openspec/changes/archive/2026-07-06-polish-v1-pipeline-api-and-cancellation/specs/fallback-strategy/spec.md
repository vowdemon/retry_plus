## ADDED Requirements

### Requirement: Do not fallback on cancellation
Fallback strategy SHALL rethrow cancellation without evaluating fallback predicates, even when configured with `FallbackPredicate<T>.any()`.

#### Scenario: Cancellation bypasses fallback value
- **WHEN** execution fails with cancellation and fallback value is configured with `FallbackPredicate<T>.any()`
- **THEN** the policy rethrows cancellation rather than returning the fallback value

### Requirement: Compose fallback predicates
Fallback predicates SHALL support OR, AND, and NOT composition.

#### Scenario: Fallback predicate OR matches either condition
- **WHEN** two fallback predicates are combined with OR
- **THEN** fallback applies when either predicate matches the final failure

#### Scenario: Fallback predicate AND requires both conditions
- **WHEN** two fallback predicates are combined with AND
- **THEN** fallback applies only when both predicates match the final failure

#### Scenario: Fallback predicate NOT excludes a condition
- **WHEN** a fallback predicate is negated
- **THEN** fallback applies only when that predicate does not match the final failure
