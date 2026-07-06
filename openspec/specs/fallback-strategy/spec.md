## Purpose

Defines fallback strategy behavior for converting final pipeline failures into fallback results.

## Requirements

### Requirement: Return fallback value for final failure
The package SHALL provide a fallback strategy that can convert a final pipeline failure into a configured fallback result.

#### Scenario: Fallback value handles final exception
- **WHEN** execution ends with an exception that matches the fallback condition
- **THEN** the policy returns the configured fallback value

#### Scenario: Fallback value handles retry-exhausted result
- **WHEN** execution ends with `RetryExhaustedException<T>` and the fallback condition matches
- **THEN** the policy returns the configured fallback value

### Requirement: Compute fallback with callback
The package SHALL support fallback callbacks that receive final failure metadata and return a fallback result.

#### Scenario: Fallback callback receives failure context
- **WHEN** a fallback callback runs after final failure
- **THEN** it receives metadata including the failure, elapsed time, attempt data, and pipeline context

### Requirement: Filter fallback applicability
The fallback strategy SHALL allow callers to decide which exceptions or exhausted results are eligible for fallback.

#### Scenario: Non-matching failure is not handled
- **WHEN** final failure does not match the fallback condition
- **THEN** the original final failure is propagated

### Requirement: Do not retry fallback by default
Fallback strategy SHALL run outside retry and MUST NOT be retried by the default high-level policy order.

#### Scenario: Fallback callback throws
- **WHEN** a fallback callback throws an exception
- **THEN** that fallback exception is propagated and retry does not schedule another fallback attempt

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
