## Purpose

Defines fallback strategy behavior for converting matching final pipeline outcomes into fallback results.
## Requirements
### Requirement: Return fallback value for final failure
The package SHALL provide a fallback strategy that can convert a matching final outcome into a configured fallback result.

#### Scenario: Fallback value handles final exception
- **WHEN** execution ends with an exception outcome that matches the fallback condition
- **THEN** the policy returns the configured fallback value

#### Scenario: Fallback value handles final result
- **WHEN** execution ends with a result outcome that matches the fallback condition
- **THEN** the policy returns the configured fallback value

### Requirement: Compute fallback with callback
The package SHALL support fallback callbacks that receive final outcome metadata through `FallbackContext<T>` implementing the shared outcome-context contract and return or throw a fallback result synchronously or asynchronously.

#### Scenario: Fallback callback receives failure context
- **WHEN** a fallback callback runs after final failure
- **THEN** it receives metadata including the outcome, elapsed time, attempt data, and pipeline context through the shared outcome-context contract

#### Scenario: Fallback callback reads outcome helpers
- **WHEN** a fallback callback receives `FallbackContext<T>`
- **THEN** it can read shared result, error, and stack trace helpers according to the final outcome state

#### Scenario: Async fallback callback completes
- **WHEN** a fallback callback returns a future
- **THEN** the fallback strategy waits for that future and returns its value

#### Scenario: Fallback callback throws
- **WHEN** a fallback callback throws or returns a failed future
- **THEN** that fallback failure is propagated according to pipeline order

### Requirement: Filter fallback applicability
The fallback strategy SHALL allow callers to decide which exception outcomes or result outcomes are eligible for fallback through shared outcome-context predicate semantics.

#### Scenario: Non-matching failure is not handled
- **WHEN** final failure does not match the fallback condition
- **THEN** the original final failure is propagated

#### Scenario: Matching exception is handled
- **WHEN** final failure is an exception outcome that matches `FallbackPredicate<T>.exception(...)`
- **THEN** fallback returns the configured fallback value or callback result

#### Scenario: Matching result is handled
- **WHEN** final result matches the fallback condition
- **THEN** fallback produces the configured fallback result

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

### Requirement: Emit fallback telemetry and hook
Fallback strategy SHALL emit lifecycle telemetry for handling, applied, and failed fallback decisions and SHALL invoke `onFallback` before executing the fallback callback.

#### Scenario: Fallback handling starts
- **WHEN** fallback applicability matches a final outcome
- **THEN** telemetry listeners receive `fallback.handling` and the configured `onFallback` hook is invoked before the fallback callback runs

#### Scenario: Fallback result is applied
- **WHEN** the fallback callback returns a fallback result
- **THEN** telemetry listeners receive `fallback.applied` before the fallback result is returned to the outer pipeline

#### Scenario: Fallback callback fails
- **WHEN** the fallback callback throws or returns a failed future
- **THEN** telemetry listeners receive `fallback.failed` with the fallback failure before that failure is propagated

### Requirement: Cover fallback behavior parity
The fallback test suite SHALL cover fallback behavior classes represented by the reference suite while expressing fallback applicability through rp outcome predicates.

#### Scenario: Fallback handles matching outcomes
- **WHEN** fallback receives a matching exception or result outcome
- **THEN** tests SHALL prove fallback returns the configured or computed fallback result

#### Scenario: Fallback preserves non-matching outcomes
- **WHEN** fallback receives a non-matching exception or result outcome
- **THEN** tests SHALL prove the original outcome is preserved

#### Scenario: Fallback callback receives outcome context
- **WHEN** fallback computes a value through a callback
- **THEN** tests SHALL prove the callback can read result, error, stack trace, elapsed time, and pipeline context through public helpers

#### Scenario: Fallback callback failure propagates
- **WHEN** fallback callback or fallback hook throws
- **THEN** tests SHALL prove the hook or callback failure is propagated according to rp hook semantics

#### Scenario: Fallback bypasses cancellation
- **WHEN** the guarded outcome is cancellation
- **THEN** tests SHALL prove fallback does not handle it, even when using broad fallback predicates

#### Scenario: Fallback emits lifecycle observations
- **WHEN** fallback starts, applies, or fails
- **THEN** tests SHALL cover hook arguments, telemetry event data, strategy name, and ordering

