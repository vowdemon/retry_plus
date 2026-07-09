## Purpose

Defines the behavior of the strategy-based retry API exposed by `retry_plus`.
## Requirements
### Requirement: Execute async operations with retry facade
The package SHALL provide `Retry<T>` as the primary public abstraction for executing `FutureOr<T> Function()` operations with configured retry behavior, returning `RetryFuture<T>`.

#### Scenario: Async operation succeeds immediately
- **WHEN** a caller executes an async operation through `Retry<T>` and the first attempt returns a non-retryable result
- **THEN** the returned `RetryFuture<T>` completes with that result without scheduling another attempt

#### Scenario: Async operation succeeds after retryable exceptions
- **WHEN** an async operation throws retryable exceptions and later returns a non-retryable result before retry continuation is denied
- **THEN** the returned `RetryFuture<T>` completes with the successful result after the retry attempts

#### Scenario: Synchronous operation is retried
- **WHEN** a synchronous operation throws retryable exceptions and later returns a valid result
- **THEN** the returned `RetryFuture<T>` completes with the valid result using the same retry decision, delay, hook, and failure behavior as async execution

### Requirement: Return retry execution futures
`Retry<T>.execute(...)` and `Retry<T>.call(...)` SHALL return `RetryFuture<T>` for retry executions.

#### Scenario: Retry future is awaitable
- **WHEN** a caller executes an operation through `Retry<T>.execute`
- **THEN** the returned value can be awaited as a `Future<T>` and completes with the same result or error as the retry execution

#### Scenario: Retry call delegates to execute behavior
- **WHEN** a caller executes an operation through `Retry<T>.call`
- **THEN** the returned retry future follows the same behavior as `Retry<T>.execute`

#### Scenario: Retry future exposes generated token
- **WHEN** a caller executes a retry operation without a cancellation token
- **THEN** the returned `RetryFuture<T>.cancelToken` is the cancellation token generated for that execution

### Requirement: Expose retry future cancellation
`RetryFuture<T>` SHALL expose the effective `CancellationToken` for its execution and provide `cancel([reason])` as a direct cancellation method.

#### Scenario: Caller cancels through retry future
- **WHEN** a caller invokes `cancel()` on a running `RetryFuture<T>`
- **THEN** the retry execution observes cancellation at supported cancellation boundaries and completes with cancellation

#### Scenario: Retry future exposes provided token
- **WHEN** a caller executes a retry operation with a cancellation token
- **THEN** the returned `RetryFuture<T>.cancelToken` is that same token

### Requirement: Expose retry phase
`RetryFuture<T>` SHALL expose the current retry lifecycle phase through `RetryFuture.phase` using `RetryPhase`.

#### Scenario: Phase changes during retry lifecycle
- **WHEN** a retry execution moves between attempting, waiting, completed, failed, or cancelled lifecycle stages
- **THEN** `RetryFuture.phase` reflects the current lifecycle phase

### Requirement: Use retryIf as the unified retry continuation decision
The package SHALL use `retryIf` as the single public decision point for whether another retry attempt is scheduled after an operation outcome.

#### Scenario: Retry decision allows another attempt
- **WHEN** an attempt produces an outcome and `retryIf` returns true for that attempt metadata
- **THEN** the retry execution computes the retry delay, emits retry observation data, waits for the delay, and schedules another attempt

#### Scenario: Retry decision rejects another attempt after exception
- **WHEN** an attempt throws an exception and `retryIf` returns false
- **THEN** the retry execution rethrows that exception with its captured stack trace without scheduling another attempt

#### Scenario: Retry decision rejects another attempt after result
- **WHEN** an attempt returns a result and `retryIf` returns false
- **THEN** the retry execution returns that result without scheduling another attempt

### Requirement: Provide attempt metadata to retryIf
The package SHALL provide retry decision callbacks with `RetryAttemptContext<T>` containing typed outcome, local zero-based retry index, local one-based attempt number, elapsed execution time, attempt duration, and the shared pipeline context.

#### Scenario: Retry decision reads retry index
- **WHEN** a retry decision limits execution to three retries
- **THEN** it can compare the retry attempt context retry index without relying on a separate stop strategy

#### Scenario: Retry decision reads pipeline context
- **WHEN** a retry decision needs pipeline-level services
- **THEN** it can access them through `RetryAttemptContext<T>.pipelineContext`

### Requirement: Support asynchronous retry decisions
Retry decision callbacks SHALL support `FutureOr<bool>` so callers can make synchronous or asynchronous retry decisions through the same API.

#### Scenario: Async retry decision allows retry
- **WHEN** `retryIf` returns a future that completes with true
- **THEN** the retry execution schedules the next retry after that future completes

#### Scenario: Async retry decision rejects retry
- **WHEN** `retryIf` returns a future that completes with false
- **THEN** the retry execution completes with the current final outcome without computing a retry delay

### Requirement: Provide retry decision combinators for budgets
The package SHALL provide retry decision combinators for common retry count budgets, and time budgets SHALL be expressed by composing retry with timeout/time strategies.

#### Scenario: Maximum retries budget stops continuation
- **WHEN** an operation keeps producing retryable outcomes and the max retries decision budget is exhausted
- **THEN** `retryIf` returns false and the retry execution does not schedule another attempt

### Requirement: Retry by exception
The package SHALL allow callers to retry exceptions using retry decisions, including default exception matching and typed exception matching.

#### Scenario: Retryable exception is retried
- **WHEN** an operation throws an exception and the configured retry decision returns true for that exception attempt
- **THEN** the retry execution schedules another attempt

#### Scenario: Non-retryable exception is rethrown
- **WHEN** an operation throws an exception and the configured retry decision returns false for that exception attempt
- **THEN** the retry execution rethrows that exception without scheduling another attempt

### Requirement: Retry by result
The package SHALL allow callers to retry returned results using retry decisions that inspect typed result outcomes.

#### Scenario: Retryable result is retried
- **WHEN** an operation returns a result and the configured retry decision returns true for that result attempt
- **THEN** the retry execution schedules another attempt

#### Scenario: Non-retryable result is returned
- **WHEN** an operation returns a result and the configured retry decision returns false for that result attempt
- **THEN** the retry execution returns that result immediately

### Requirement: Delay retry attempts
The package SHALL support no delay, fixed delay, linear delay, exponential delay, random delay, generated delay, fallback delay, capped delay, stateful delay, and additive delay composition using retry attempt context.

#### Scenario: Exponential delay is applied
- **WHEN** a retry strategy is configured with exponential delay
- **THEN** each retry wait uses that retry strategy's local attempt number with the configured initial duration, factor, and maximum duration

#### Scenario: Additive delay composition is applied
- **WHEN** a retry strategy delay is configured as the sum of two delay strategies
- **THEN** the retry wait equals the sum of both computed durations for that local retry attempt

#### Scenario: Generated delay overrides fallback delay
- **WHEN** a generated delay produces a non-null duration
- **THEN** that duration is used for the retry wait instead of the fallback delay

### Requirement: Support asynchronous retry delays
Retry delay strategies SHALL support `FutureOr<Duration?>` delay generation using `RetryAttemptContext<T>`.

#### Scenario: Async generated delay is used
- **WHEN** a delay strategy returns a future that completes with a non-null non-negative duration
- **THEN** the retry strategy waits for that generated duration before scheduling the next local attempt

#### Scenario: Generated delay falls back
- **WHEN** a generated delay returns null and a fallback delay is configured
- **THEN** the retry strategy computes and waits for the fallback delay using the same retry attempt context

### Requirement: Add jitter to retry waits
The package SHALL support jitter as delay strategy behavior and delay composition so callers can reduce coordinated retry bursts without enabling a fixed boolean option.

#### Scenario: Jitter changes computed delay within bounds
- **WHEN** a delay strategy is composed with bounded jitter
- **THEN** the computed delay remains within the documented lower and upper bounds for that jitter behavior

#### Scenario: Stateful jitter is scoped to one execution
- **WHEN** a jitter algorithm requires previous retry-delay state
- **THEN** its mutable state is scoped to one retry execution and does not leak into later executions using the same strategy instance

### Requirement: Compose retry strategies
The package SHALL support composition of retry decisions and delay strategies using documented composition semantics.

#### Scenario: Retry decision uses combined conditions
- **WHEN** retry decisions are combined with OR or AND semantics
- **THEN** the retry execution retries only according to the documented combined decision result

#### Scenario: Retry decision negates a condition
- **WHEN** a broad retry decision is combined with the negation of a more specific decision
- **THEN** attempts matching the negated decision are not retried

#### Scenario: Delay strategy uses combined calculation
- **WHEN** delay strategies are combined through documented delay composition
- **THEN** the retry wait follows the documented combined delay result

### Requirement: Run retry as a pipeline strategy
Retry behavior SHALL run as a pipeline strategy while preserving the existing `Retry<T>` behavior.

#### Scenario: Existing retry behavior is preserved
- **WHEN** callers use retry-only configuration from the existing public API
- **THEN** the operation behavior remains equivalent after retry execution is moved into the pipeline

#### Scenario: Retry strategy composes with timeout
- **WHEN** retry and timeout are configured together by pipeline order
- **THEN** retry treats timeout as an attempt outcome that can be retried when the retry decision matches

### Requirement: Preserve retry failure semantics inside pipeline
Retry strategy SHALL preserve final outcome behavior when used inside a pipeline.

#### Scenario: Final retryable exception remains original failure
- **WHEN** retry gives up after a retryable exception and no outer strategy handles it
- **THEN** the final exception is rethrown with the captured stack trace

#### Scenario: Final retryable result remains final result
- **WHEN** retry continuation is denied after retryable result outcomes and no outer strategy handles it
- **THEN** the pipeline completes with the last result outcome

### Requirement: Support cancellation between attempts
The package SHALL support cancellation before attempts, while waiting between retry attempts, and before scheduling the next attempt through the effective token exposed by `RetryFuture<T>.cancelToken`.

#### Scenario: Cancellation during retry delay
- **WHEN** a cancellation token is cancelled while the retry execution is waiting before the next attempt
- **THEN** the retry execution stops waiting and completes the `RetryFuture<T>` with the cancellation reason or a retry cancellation exception

#### Scenario: Cancellation does not force-stop running operation
- **WHEN** a cancellation token is cancelled while the caller-provided operation is already running
- **THEN** the retry execution does not forcibly interrupt the operation and observes cancellation before the next retry boundary

### Requirement: Treat cancellation as non-retryable control flow
Retry strategy SHALL rethrow cancellation without converting it into an attempt outcome for retry classification.

#### Scenario: Cancellation is not retried
- **WHEN** an operation or retry boundary throws `RetryCancelledException`
- **THEN** retry strategy rethrows cancellation without scheduling another attempt

#### Scenario: Cancellation does not trigger give-up hook
- **WHEN** cancellation stops execution
- **THEN** retry strategy does not emit a retry give-up event for cancellation

### Requirement: Emit retry lifecycle hooks
The package SHALL expose retry lifecycle hooks that allow callers to observe scheduled retries and final non-cancellation give-up events using `RetryAttemptContext<T>` without changing retry decisions.

#### Scenario: Retry hook receives attempt context
- **WHEN** a retryable outcome schedules another attempt
- **THEN** the retry hook receives context including retry index, attempt number, elapsed time, attempt duration, outcome, and pipeline context

#### Scenario: Retry hook can be asynchronous
- **WHEN** a retry hook returns a future
- **THEN** the retry strategy waits for the hook future before computing or waiting for the retry delay according to the documented lifecycle

#### Scenario: Give-up hook receives final context
- **WHEN** retry continuation is denied after a retry-handled outcome
- **THEN** the give-up hook receives context for the final outcome before the retry strategy completes with that final outcome

### Requirement: Expose typed retry event outcomes
Retry lifecycle callbacks SHALL expose typed attempt outcome and attempt metadata from `RetryAttemptContext<T>`.

#### Scenario: Hook reads typed outcome
- **WHEN** a retry hook receives retry attempt context
- **THEN** the hook can read the typed outcome without casting

#### Scenario: Hook reads retry attempt metadata
- **WHEN** a retry hook receives retry attempt context
- **THEN** the hook can read retry index, attempt number, attempt duration, elapsed time, and pipeline context

### Requirement: Support custom retry decisions
The package SHALL support custom retry decisions that inspect retry attempt context and return `FutureOr<bool>`.

#### Scenario: Custom retry decision controls retry
- **WHEN** a caller configures a custom retry decision
- **THEN** the retry strategy schedules another local attempt only when that decision returns true

#### Scenario: Custom retry decision inspects context
- **WHEN** a caller configures a custom retry decision that reads retry attempt metadata
- **THEN** the decision receives the same retry attempt context as built-in retry decision combinators

### Requirement: Preserve broad retry capability without fixed options
The package SHALL express mainstream retry capabilities through open retry decision, delay, and hook extension points rather than a fixed external options object or backoff enum.

#### Scenario: max retry behavior is expressed through retryIf
- **WHEN** a caller needs a maximum retry budget
- **THEN** the caller can express the same extra-retry budget through a retry decision combinator

#### Scenario: backoff behavior is expressed through delay strategies
- **WHEN** a caller needs fixed, linear, exponential, jittered, capped, or generated retry delays
- **THEN** the caller can express those delays through delay strategy implementations and combinators without a fixed backoff enum

### Requirement: Scope retry attempt context to one retry strategy
Each `RetryStrategy<T>` SHALL create and maintain `RetryAttemptContext<T>` values scoped to that strategy instance and execution.

#### Scenario: Attempt number is local to strategy instance
- **WHEN** two retry strategies are nested in one pipeline
- **THEN** each retry strategy reports attempt numbers relative to its own local execution sequence

#### Scenario: Retry index is local to strategy instance
- **WHEN** two retry strategies are nested in one pipeline
- **THEN** each retry strategy evaluates retry budgets using its own local retry index

### Requirement: Emit retry telemetry with local attempt metadata
Retry telemetry SHALL report retry attempt metadata for the emitting retry strategy instance only.

#### Scenario: Telemetry identifies retry strategy instance
- **WHEN** a named retry strategy emits retry telemetry
- **THEN** the event source contains that strategy instance name
- **AND** the event attributes contain local attempt number and local retry index for that strategy

#### Scenario: Nested retry telemetry is distinguishable
- **WHEN** nested retry strategies emit retry telemetry
- **THEN** listeners can distinguish the retry strategy instance through telemetry source
- **AND** each event's attempt metadata is local to that emitting strategy

### Requirement: Keep retry attempt context private to retry collaborators
`RetryAttemptContext<T>` SHALL be visible only through retry-owned decisions, delay strategies, hooks, and retry telemetry construction.

#### Scenario: Other strategies receive only pipeline context
- **WHEN** retry composes with timeout, fallback, circuit breaker, rate limiter, hedging, injection, or custom pipeline strategies
- **THEN** those strategies receive `RetryPipelineContext<T>` and do not receive `RetryAttemptContext<T>`

### Requirement: Cover retry behavior parity
The retry test suite SHALL cover retry behavior classes represented by the reference suite while expressing them through rp retry decisions, delay policies, hooks, telemetry, and local retry attempt context.

#### Scenario: Retry handles matching outcomes
- **WHEN** retry receives matching exception or result outcomes
- **THEN** tests SHALL prove retry continues according to local retry decision and budget

#### Scenario: Retry preserves unhandled outcomes
- **WHEN** retry receives non-matching exception, non-matching result, or cancellation
- **THEN** tests SHALL prove retry does not continue and preserves the original outcome semantics

#### Scenario: Retry preserves final outcome
- **WHEN** all allowed retry attempts are consumed
- **THEN** tests SHALL prove the final exception remains the thrown failure and the final result remains the returned result

#### Scenario: Retry computes delay through open policies
- **WHEN** retry schedules another attempt
- **THEN** tests SHALL cover zero delay, generated delay, null generated delay fallback, asynchronous delay computation, max/budget behavior, and jitter bounds through rp delay policies

#### Scenario: Retry emits local lifecycle observations
- **WHEN** retry decides, schedules, retries, gives up, or is cancelled
- **THEN** tests SHALL cover hook arguments, hook failure propagation, telemetry event data, strategy name, and local attempt metadata

#### Scenario: Retry attempt context is local
- **WHEN** multiple retry strategies are nested in one pipeline
- **THEN** tests SHALL prove each retry strategy has independent attempt numbers and retry indexes

