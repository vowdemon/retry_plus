## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: Adapt synchronous operations
The package SHALL execute synchronous `T Function()` operations through `RetryPolicy<T>.execute` and top-level `retry<T>(...)` by accepting `FutureOr<T> Function()` operations.

#### Scenario: Synchronous operation is retried
- **WHEN** a synchronous operation throws retryable exceptions and later returns a valid result
- **THEN** the returned `RetryFuture<T>` completes with the valid result using the same stop, delay, hook, and failure behavior as async execution

#### Scenario: Separate sync API is absent
- **WHEN** callers use the public retry policy API
- **THEN** synchronous operations are executed through `execute` rather than a separate sync-specific method
