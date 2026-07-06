## ADDED Requirements

### Requirement: Execute async operations with a retry policy
The package SHALL provide `RetryPolicy<T>` as the primary public abstraction for executing `Future<T> Function()` operations with configured retry behavior.

#### Scenario: Async operation succeeds immediately
- **WHEN** a caller executes an async operation through a retry policy and the first attempt returns a non-retryable result
- **THEN** the policy returns that result without scheduling another attempt

#### Scenario: Async operation succeeds after retryable exceptions
- **WHEN** an async operation throws retryable exceptions and later returns a non-retryable result before the stop strategy is reached
- **THEN** the policy returns the successful result after the retry attempts

### Requirement: Provide one-off retry convenience API
The package SHALL provide a top-level `retry<T>(...)` function that executes one operation by creating and using an equivalent `RetryPolicy<T>`.

#### Scenario: Convenience function uses policy behavior
- **WHEN** a caller invokes `retry<T>(...)` with stop, delay, and retry predicate options
- **THEN** the operation follows the same retry behavior as an equivalent `RetryPolicy<T>`

### Requirement: Adapt synchronous operations
The package SHALL provide a way to execute synchronous `T Function()` operations through the same retry engine used for async operations.

#### Scenario: Synchronous operation is retried
- **WHEN** a synchronous operation throws retryable exceptions and later returns a valid result
- **THEN** the policy returns the valid result using the same stop, delay, hook, and failure behavior as async execution

### Requirement: Retry by exception
The package SHALL allow callers to retry exceptions using retry predicates, including a default exception retry predicate and typed exception predicates.

#### Scenario: Retryable exception is retried
- **WHEN** an operation throws an exception that matches the configured exception retry predicate
- **THEN** the policy schedules another attempt unless a stop condition prevents it

#### Scenario: Non-retryable exception is rethrown
- **WHEN** an operation throws an exception that does not match the configured exception retry predicate
- **THEN** the policy rethrows that exception without scheduling another attempt

### Requirement: Retry by result
The package SHALL allow callers to retry returned results using `RetryPredicate<T>.result(...)` predicates.

#### Scenario: Retryable result is retried
- **WHEN** an operation returns a result that matches the configured result retry predicate
- **THEN** the policy schedules another attempt unless a stop condition prevents it

#### Scenario: Non-retryable result is returned
- **WHEN** an operation returns a result that does not match the configured result retry predicate
- **THEN** the policy returns that result immediately

### Requirement: Stop retrying by attempts and elapsed time
The package SHALL support stop strategies for never stopping, maximum attempts, elapsed time budget, and avoiding a delay that would exceed an elapsed time budget.

#### Scenario: Maximum attempts exhausted by exception
- **WHEN** an operation keeps throwing retryable exceptions until `StopStrategy.afterAttempt(n)` is reached
- **THEN** the policy stops after exactly `n` total attempts and rethrows the last exception with its stack trace

#### Scenario: Maximum attempts exhausted by result
- **WHEN** an operation keeps returning retryable results until `StopStrategy.afterAttempt(n)` is reached
- **THEN** the policy throws `RetryExhaustedException<T>` containing the last result and attempt metadata

#### Scenario: Delay would exceed elapsed budget
- **WHEN** a retryable outcome occurs but the next delay would exceed `StopStrategy.beforeElapsed(duration)`
- **THEN** the policy stops without waiting for that delay

### Requirement: Delay retry attempts
The package SHALL support no delay, fixed delay, linear delay, exponential delay, random delay, and additive delay composition.

#### Scenario: Exponential delay is applied
- **WHEN** a policy is configured with exponential delay
- **THEN** each retry wait uses the configured initial duration, factor, and maximum duration

#### Scenario: Additive delay composition is applied
- **WHEN** a policy delay is configured as the sum of two delay strategies
- **THEN** the retry wait equals the sum of both computed durations for that attempt

### Requirement: Add jitter to retry waits
The package SHALL support jitter for delay strategies so callers can reduce coordinated retry bursts.

#### Scenario: Jitter changes computed delay within bounds
- **WHEN** a delay strategy is configured with jitter
- **THEN** the computed delay remains within the configured lower and upper bounds for that strategy

### Requirement: Compose retry strategies
The package SHALL support composition of stop strategies, retry predicates, and delay strategies using documented strategy composition semantics.

#### Scenario: Stop strategy uses either condition
- **WHEN** two stop strategies are combined with OR semantics
- **THEN** retrying stops when either strategy indicates that execution must stop

#### Scenario: Retry predicate uses combined conditions
- **WHEN** retry predicates are combined with OR or AND semantics
- **THEN** the policy retries only according to the documented combined predicate result

### Requirement: Support cancellation between attempts
The package SHALL support cancellation before attempts, while waiting between retry attempts, and before scheduling the next attempt.

#### Scenario: Cancellation during retry delay
- **WHEN** a cancellation token is cancelled while the policy is waiting before the next attempt
- **THEN** the policy stops waiting and completes with the cancellation reason or a retry cancellation exception

#### Scenario: Cancellation does not force-stop running operation
- **WHEN** a cancellation token is cancelled while the caller-provided operation is already running
- **THEN** the policy does not forcibly interrupt the operation and observes cancellation before the next retry boundary

### Requirement: Emit retry lifecycle hooks
The package SHALL expose retry lifecycle hooks that allow callers to observe retries and final give-up events without changing retry decisions.

#### Scenario: Retry hook receives attempt metadata
- **WHEN** a retryable outcome schedules another attempt
- **THEN** the retry hook receives metadata including attempt number, elapsed time, outcome, and next delay

#### Scenario: Give-up hook receives final metadata
- **WHEN** the policy stops because retry attempts are exhausted
- **THEN** the give-up hook receives metadata for the final outcome before the policy completes with its final failure

### Requirement: Preserve final failure semantics
The package SHALL preserve original exception identity and stack trace for final exception failures and use a typed exhausted exception for final result failures.

#### Scenario: Final exception is rethrown
- **WHEN** retries stop after a retryable exception outcome
- **THEN** the final exception is rethrown with the captured stack trace instead of being wrapped by default

#### Scenario: Final result raises exhausted exception
- **WHEN** retries stop after a retryable result outcome
- **THEN** the policy throws `RetryExhaustedException<T>` containing the last result, attempts, elapsed time, and retry context

### Requirement: Provide deterministic tests and examples
The package SHALL include tests and examples that exercise the public retry policy behavior without relying on real-time sleeps.

#### Scenario: Tests run without real retry delays
- **WHEN** the test suite verifies delay, elapsed time, random jitter, and cancellation behavior
- **THEN** the tests use deterministic time and randomness controls rather than waiting for production delays

#### Scenario: Documentation examples stay valid
- **WHEN** README and example usage demonstrate public APIs
- **THEN** smoke tests or equivalent coverage verify those examples continue to compile and reflect supported behavior
