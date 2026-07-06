## ADDED Requirements

### Requirement: Support custom fallback predicates
Fallback predicates SHALL remain open to caller-defined final failure classification through documented public extension contracts and callback-based factories.

#### Scenario: Custom fallback predicate class controls fallback handling
- **WHEN** a caller supplies a custom `FallbackPredicate<T>` implementation
- **THEN** fallback uses that predicate to decide whether to handle the final failure

#### Scenario: Custom fallback predicate callback controls fallback handling
- **WHEN** a caller supplies a callback-based fallback predicate
- **THEN** fallback uses that callback with `FallbackContext<T>`

#### Scenario: Custom fallback predicate composes with built-ins
- **WHEN** a custom fallback predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics
