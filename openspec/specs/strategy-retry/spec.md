## Purpose

Defines the behavior of the strategy-based retry API exposed by `retry_plus`.

## Requirements

### Requirement: Execute async operations with a retry policy
The package SHALL provide `RetryPolicy<T>` as the primary public abstraction for executing `FutureOr<T> Function()` operations with configured retry behavior, returning `RetryFuture<T>`.

#### Scenario: Async operation succeeds immediately
- **WHEN** a caller executes an async operation through a retry policy and the first attempt returns a non-retryable result
- **THEN** the returned `RetryFuture<T>` completes with that result without scheduling another attempt

#### Scenario: Async operation succeeds after retryable exceptions
- **WHEN** an async operation throws retryable exceptions and later returns a non-retryable result before the stop strategy is reached
- **THEN** the returned `RetryFuture<T>` completes with the successful result after the retry attempts

#### Scenario: Synchronous operation succeeds immediately
- **WHEN** a caller executes a synchronous operation through a retry policy and the first attempt returns a non-retryable result
- **THEN** the returned `RetryFuture<T>` completes with that result without scheduling another attempt

#### Scenario: Synchronous operation is retried
- **WHEN** a synchronous operation throws retryable exceptions and later returns a valid result
- **THEN** the returned `RetryFuture<T>` completes with the valid result using the same stop, delay, hook, and failure behavior as async execution

### Requirement: Provide one-off retry convenience API
The package SHALL provide a top-level `retry<T>(...)` function that executes a `FutureOr<T> Function()` operation by creating and using an equivalent `RetryPolicy<T>`, returning `RetryFuture<T>`.

#### Scenario: Convenience function uses policy behavior
- **WHEN** a caller invokes `retry<T>(...)` with stop, delay, and retry predicate options
- **THEN** the operation follows the same retry behavior as an equivalent `RetryPolicy<T>`

#### Scenario: Convenience function supports synchronous operation
- **WHEN** a caller invokes `retry<T>(...)` with a synchronous operation
- **THEN** synchronous returns and synchronous throws are handled by the same retry behavior as asynchronous operations

### Requirement: Adapt synchronous operations
The package SHALL execute synchronous `T Function()` operations through `RetryPolicy<T>.execute` and top-level `retry<T>(...)` by accepting `FutureOr<T> Function()` operations.

#### Scenario: Synchronous operation is retried
- **WHEN** a synchronous operation throws retryable exceptions and later returns a valid result
- **THEN** the returned `RetryFuture<T>` completes with the valid result using the same stop, delay, hook, and failure behavior as async execution

#### Scenario: Separate sync API is absent
- **WHEN** callers use the public retry policy API
- **THEN** synchronous operations are executed through `execute` rather than a separate sync-specific method

### Requirement: Return retry execution futures
`RetryPolicy<T>` and the top-level `retry<T>(...)` function SHALL return `RetryFuture<T>` for retry executions.

#### Scenario: Retry future is awaitable
- **WHEN** a caller executes an operation through `RetryPolicy<T>.execute`
- **THEN** the returned value can be awaited as a `Future<T>` and completes with the same result or error as the retry execution

#### Scenario: Convenience retry returns retry future
- **WHEN** a caller invokes top-level `retry<T>(...)`
- **THEN** the returned value exposes `RetryFuture<T>` control while preserving the convenience retry behavior

### Requirement: Expose retry future cancellation
`RetryFuture<T>` SHALL expose the effective `CancellationToken` for its execution and provide `cancel([reason])` as a direct cancellation method.

#### Scenario: Caller cancels through retry future
- **WHEN** a caller invokes `cancel()` on a running `RetryFuture<T>`
- **THEN** the retry execution observes cancellation at supported cancellation boundaries and completes with cancellation

#### Scenario: Retry future exposes provided token
- **WHEN** a caller executes a retry operation with a cancellation token
- **THEN** the returned `RetryFuture<T>.cancelToken` is that same token

#### Scenario: Retry future exposes generated token
- **WHEN** a caller executes a retry operation without a cancellation token
- **THEN** the returned `RetryFuture<T>.cancelToken` is the cancellation token generated for that execution

### Requirement: Expose retry phase
`RetryFuture<T>` SHALL expose the current retry lifecycle phase through `RetryFuture.phase` using `RetryPhase`.

#### Scenario: Phase changes during retry lifecycle
- **WHEN** a retry execution moves between attempting, waiting, completed, failed, or cancelled lifecycle stages
- **THEN** `RetryFuture.phase` reflects the current lifecycle phase

#### Scenario: Phase is not a state object
- **WHEN** a caller inspects `RetryFuture<T>`
- **THEN** the public API exposes `RetryPhase` directly and does not require a separate public `RetryState` object

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

### Requirement: Run retry as a pipeline strategy
Retry behavior SHALL run as a pipeline strategy while preserving the existing `RetryPolicy<T>` and top-level `retry<T>(...)` behavior.

#### Scenario: Existing retry behavior is preserved
- **WHEN** callers use retry-only configuration from the existing public API
- **THEN** the operation behavior remains equivalent after retry execution is moved into the pipeline

#### Scenario: Retry strategy composes with timeout
- **WHEN** retry and per-attempt timeout are configured together
- **THEN** retry treats per-attempt timeout as an attempt outcome that can be retried when the retry predicate matches

### Requirement: Compose stop strategies with AND semantics
Stop strategies SHALL support AND composition in addition to existing OR composition.

#### Scenario: AND stop requires both conditions
- **WHEN** two stop strategies are combined with AND semantics
- **THEN** retrying stops only after both strategies indicate that execution must stop

### Requirement: Negate retry predicates
Retry predicates SHALL support negation so callers can exclude specific retryable conditions from broader retry rules.

#### Scenario: Negated predicate excludes condition
- **WHEN** a broad retry predicate is combined with the negation of a more specific predicate
- **THEN** outcomes matching the negated predicate are not retried

### Requirement: Preserve retry failure semantics inside pipeline
Retry strategy SHALL preserve existing final failure behavior when used inside a pipeline.

#### Scenario: Final retryable exception remains original failure
- **WHEN** retry gives up after a retryable exception and no outer strategy handles it
- **THEN** the final exception is rethrown with the captured stack trace

#### Scenario: Final retryable result remains exhausted failure
- **WHEN** retry gives up after retryable result outcomes and no outer strategy handles it
- **THEN** the pipeline completes with `RetryExhaustedException<T>`

### Requirement: Support cancellation between attempts
The package SHALL support cancellation before attempts, while waiting between retry attempts, and before scheduling the next attempt through the effective token exposed by `RetryFuture<T>.cancelToken`.

#### Scenario: Cancellation during retry delay
- **WHEN** a cancellation token is cancelled while the policy is waiting before the next attempt
- **THEN** the policy stops waiting and completes the `RetryFuture<T>` with the cancellation reason or a retry cancellation exception

#### Scenario: Cancellation does not force-stop running operation
- **WHEN** a cancellation token is cancelled while the caller-provided operation is already running
- **THEN** the policy does not forcibly interrupt the operation and observes cancellation before the next retry boundary

#### Scenario: Cancellation through retry future uses effective token
- **WHEN** a caller invokes `RetryFuture<T>.cancel([reason])`
- **THEN** the call cancels the token exposed by `RetryFuture<T>.cancelToken`

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

### Requirement: Provide behavior-focused tests and examples
The package SHALL include tests and examples that exercise public retry policy behavior through real execution paths and focused strategy calculations.

#### Scenario: Tests avoid runtime dependency injection
- **WHEN** the test suite verifies elapsed time, retry delays, jitter, timeout, and cancellation behavior
- **THEN** the tests use `package:clock`, direct delay strategy calculations, explicit callbacks, or short real timers instead of runtime dependency injection

#### Scenario: Documentation examples stay valid
- **WHEN** README and example usage demonstrate public APIs
- **THEN** smoke tests or equivalent coverage verify those examples continue to compile and reflect supported behavior

### Requirement: Treat cancellation as non-retryable control flow
Retry strategy SHALL rethrow cancellation without converting it into an attempt outcome for retry classification.

#### Scenario: Cancellation is not retried
- **WHEN** an operation or retry boundary throws `RetryCancelledException`
- **THEN** retry strategy rethrows cancellation without scheduling another attempt

#### Scenario: Cancellation does not trigger give-up hook
- **WHEN** cancellation stops execution
- **THEN** retry strategy does not emit a retry give-up event for cancellation

### Requirement: Expose typed retry event outcomes
Retry lifecycle events SHALL expose `AttemptOutcome<T>` from `RetryEvent<T>.outcome`.

#### Scenario: Hook reads typed outcome
- **WHEN** a retry hook receives `RetryEvent<T>`
- **THEN** the hook can read `event.outcome` as `AttemptOutcome<T>` without casting

### Requirement: Keep retry predicate behavior while removing duplicate internals
Retry predicate implementations SHALL preserve OR, AND, and NOT behavior while sharing operator implementation through internal reuse.

#### Scenario: Predicate composition remains equivalent
- **WHEN** callers combine retry predicates with OR, AND, or NOT
- **THEN** the composed predicate result remains the same after internal refactoring

### Requirement: Support custom retry predicates
Retry predicates SHALL remain open to caller-defined retry decisions through documented public extension contracts and callback-based factories.

#### Scenario: Custom retry predicate class controls retry decision
- **WHEN** a caller supplies a custom `RetryPredicate<T>` implementation
- **THEN** retry uses that predicate to decide whether an attempt outcome should be retried

#### Scenario: Custom retry predicate callback controls retry decision
- **WHEN** a caller supplies a callback-based retry predicate
- **THEN** retry uses that callback to classify attempt outcomes

### Requirement: Support custom delay strategies
Delay strategies SHALL remain open to caller-defined delay algorithms through documented public extension contracts and callback-based factories.

#### Scenario: Custom delay class computes retry wait
- **WHEN** a caller supplies a custom `DelayStrategy` implementation
- **THEN** retry uses that implementation to compute the next retry delay

#### Scenario: Custom delay callback computes retry wait
- **WHEN** a caller supplies a callback-based delay strategy
- **THEN** retry uses that callback with retry context and deterministic random input

### Requirement: Support custom stop strategies
Stop strategies SHALL remain open to caller-defined stop rules through documented public extension contracts and callback-based factories.

#### Scenario: Custom stop class decides final attempt
- **WHEN** a caller supplies a custom `StopStrategy` implementation
- **THEN** retry uses that implementation to decide whether retrying must stop

#### Scenario: Custom stop callback decides final attempt
- **WHEN** a caller supplies a callback-based stop strategy
- **THEN** retry uses that callback with retry context and next-delay metadata

### Requirement: Support custom jitter algorithms
Jitter SHALL remain open to caller-defined randomization algorithms through documented public extension contracts and callback-based factories.

#### Scenario: Custom jitter class transforms delay
- **WHEN** a caller supplies a custom `Jitter` implementation to a jitter-capable delay strategy
- **THEN** the delay strategy applies that jitter to the computed delay

#### Scenario: Custom jitter callback transforms delay
- **WHEN** a caller supplies a callback-based jitter implementation
- **THEN** the jitter receives the base delay and deterministic random input
