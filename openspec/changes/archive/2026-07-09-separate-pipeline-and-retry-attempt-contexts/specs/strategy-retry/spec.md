## MODIFIED Requirements

### Requirement: Provide attempt metadata to retryIf
The package SHALL provide retry decision callbacks with `RetryAttemptContext<T>` containing typed outcome, local zero-based retry index, local one-based attempt number, elapsed execution time, attempt duration, and the shared pipeline context.

#### Scenario: Retry decision reads retry index
- **WHEN** a retry decision limits execution to three retries
- **THEN** it can compare the retry attempt context retry index without relying on a separate stop strategy

#### Scenario: Retry decision reads pipeline context
- **WHEN** a retry decision needs pipeline-level services
- **THEN** it can access them through `RetryAttemptContext<T>.pipelineContext`

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

## ADDED Requirements

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
