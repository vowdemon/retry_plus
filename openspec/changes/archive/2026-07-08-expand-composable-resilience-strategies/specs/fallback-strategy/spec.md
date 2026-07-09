## MODIFIED Requirements

### Requirement: Return fallback value for final failure
The package SHALL provide a fallback strategy that can convert a matching final outcome into a configured fallback result.

#### Scenario: Fallback value handles final exception
- **WHEN** execution ends with an exception outcome that matches the fallback condition
- **THEN** the policy returns the configured fallback value

#### Scenario: Fallback value handles final result
- **WHEN** execution ends with a result outcome that matches the fallback condition
- **THEN** the policy returns the configured fallback value

### Requirement: Compute fallback with callback
The package SHALL support fallback callbacks that receive final outcome metadata and return or throw a fallback result synchronously or asynchronously.

#### Scenario: Fallback callback receives outcome context
- **WHEN** a fallback callback runs after a matching final outcome
- **THEN** it receives metadata including the outcome, elapsed time, attempt data when available, and pipeline context

#### Scenario: Async fallback callback completes
- **WHEN** a fallback callback returns a future
- **THEN** the fallback strategy waits for that future and returns its value

#### Scenario: Fallback callback throws
- **WHEN** a fallback callback throws or returns a failed future
- **THEN** that fallback failure is propagated according to pipeline order

### Requirement: Filter fallback applicability
The fallback strategy SHALL allow callers to decide which result or exception outcomes are eligible for fallback.

#### Scenario: Non-matching outcome is not handled
- **WHEN** final outcome does not match the fallback condition
- **THEN** the original final outcome is propagated

#### Scenario: Matching result is handled
- **WHEN** final result matches the fallback condition
- **THEN** fallback produces the configured fallback result

### Requirement: Support custom fallback predicates
Fallback predicates SHALL remain open to caller-defined final outcome classification through documented public extension contracts and callback-based factories.

#### Scenario: Custom fallback predicate class controls fallback handling
- **WHEN** a caller supplies a custom fallback predicate implementation
- **THEN** fallback uses that predicate to decide whether to handle the final outcome

#### Scenario: Custom fallback predicate callback controls fallback handling
- **WHEN** a caller supplies a callback-based fallback predicate
- **THEN** fallback uses that callback with typed final outcome metadata

#### Scenario: Custom fallback predicate composes with built-ins
- **WHEN** a custom fallback predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics
