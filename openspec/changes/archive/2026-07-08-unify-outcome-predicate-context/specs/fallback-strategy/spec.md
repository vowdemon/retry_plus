## MODIFIED Requirements

### Requirement: Compute fallback with callback
The package SHALL support fallback callbacks that receive final outcome metadata through `FallbackContext<T>` implementing the shared outcome-context contract and return a fallback result.

#### Scenario: Fallback callback receives failure context
- **WHEN** a fallback callback runs after final failure
- **THEN** it receives metadata including the outcome, elapsed time, attempt data, and pipeline context through the shared outcome-context contract

#### Scenario: Fallback callback reads outcome helpers
- **WHEN** a fallback callback receives `FallbackContext<T>`
- **THEN** it can read shared result, error, and stack trace helpers according to the final outcome state

### Requirement: Filter fallback applicability
The fallback strategy SHALL allow callers to decide which exception outcomes or exhausted result outcomes are eligible for fallback through shared outcome-context predicate semantics.

#### Scenario: Non-matching failure is not handled
- **WHEN** final failure does not match the fallback condition
- **THEN** the original final failure is propagated

#### Scenario: Matching exception is handled
- **WHEN** final failure is an exception outcome that matches `FallbackPredicate<T>.exception(...)`
- **THEN** fallback returns the configured fallback value or callback result

#### Scenario: Matching exhausted result is handled
- **WHEN** final failure is a `RetryExhaustedException<T>` whose last outcome matches `FallbackPredicate<T>.result(...)`
- **THEN** fallback returns the configured fallback value or callback result

### Requirement: Do not fallback on cancellation
Fallback strategy SHALL rethrow cancellation without evaluating fallback predicates, even when configured with `FallbackPredicate<T>.any()`.

#### Scenario: Cancellation bypasses fallback value
- **WHEN** execution fails with cancellation and fallback value is configured with `FallbackPredicate<T>.any()`
- **THEN** the policy rethrows cancellation rather than returning the fallback value

#### Scenario: Cancellation bypasses custom fallback predicate
- **WHEN** execution fails with cancellation and fallback is configured with a custom fallback predicate
- **THEN** the custom predicate is not evaluated and the policy rethrows cancellation

### Requirement: Compose fallback predicates
Fallback predicates SHALL support OR, AND, and NOT composition through the shared context-predicate composition model.

#### Scenario: Fallback predicate OR matches either condition
- **WHEN** two fallback predicates are combined with OR
- **THEN** fallback applies when either predicate matches the final failure

#### Scenario: Fallback predicate AND requires both conditions
- **WHEN** two fallback predicates are combined with AND
- **THEN** fallback applies only when both predicates match the final failure

#### Scenario: Fallback predicate NOT excludes a condition
- **WHEN** a fallback predicate is negated
- **THEN** fallback applies only when that predicate does not match the final failure

#### Scenario: Fallback composition uses shared implementation
- **WHEN** fallback predicates are composed
- **THEN** the behavior does not depend on fallback-specific private OR, AND, or NOT predicate classes

### Requirement: Support custom fallback predicates
Fallback predicates SHALL remain open to caller-defined final outcome classification through documented public extension contracts and callback-based factories based on `FallbackContext<T>`.

#### Scenario: Custom fallback predicate class controls fallback handling
- **WHEN** a caller supplies a custom `FallbackPredicate<T>` implementation
- **THEN** fallback uses that predicate to decide whether to handle the final failure

#### Scenario: Custom fallback predicate callback controls fallback handling
- **WHEN** a caller supplies a callback-based fallback predicate
- **THEN** fallback uses that callback with `FallbackContext<T>`

#### Scenario: Custom fallback predicate composes with built-ins
- **WHEN** a custom fallback predicate is combined with built-in predicates using OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics
