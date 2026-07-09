## ADDED Requirements

### Requirement: Use retryIf as the unified retry continuation decision
The package SHALL use `retryIf` as the single public decision point for whether another retry attempt is scheduled after an operation outcome.

#### Scenario: Retry decision allows another attempt
- **WHEN** an attempt produces an outcome and `retryIf` returns true for that attempt metadata
- **THEN** the policy computes the retry delay, emits retry observation data, waits for the delay, and schedules another attempt

#### Scenario: Retry decision rejects another attempt after exception
- **WHEN** an attempt throws an exception and `retryIf` returns false
- **THEN** the policy rethrows that exception with its captured stack trace without scheduling another attempt

#### Scenario: Retry decision rejects another attempt after result
- **WHEN** an attempt returns a result and `retryIf` returns false
- **THEN** the policy returns that result without scheduling another attempt

### Requirement: Provide attempt metadata to retryIf
The package SHALL provide retry decision callbacks with attempt metadata including typed outcome, zero-based retry index, one-based attempt number, elapsed execution time, attempt duration, and retry context.

#### Scenario: Retry decision reads retry index
- **WHEN** a retry decision limits execution to three retries
- **THEN** it can compare the attempt metadata retry index without relying on a separate stop strategy

### Requirement: Support asynchronous retry decisions
Retry decision callbacks SHALL support `FutureOr<bool>` so callers can make synchronous or asynchronous retry decisions through the same API.

#### Scenario: Async retry decision allows retry
- **WHEN** `retryIf` returns a future that completes with true
- **THEN** the policy schedules the next retry after that future completes

#### Scenario: Async retry decision rejects retry
- **WHEN** `retryIf` returns a future that completes with false
- **THEN** the policy completes with the current final outcome without computing a retry delay

### Requirement: Provide retry decision combinators for budgets
The package SHALL provide retry decision combinators for common retry count budgets, and time budgets SHALL be expressed by composing retry with timeout/time strategies.

#### Scenario: Maximum retries budget stops continuation
- **WHEN** an operation keeps producing retryable outcomes and the max retries decision budget is exhausted
- **THEN** `retryIf` returns false and the policy does not schedule another attempt

### Requirement: Support asynchronous retry delays
Retry delay strategies SHALL support `FutureOr<Duration?>` delay generation using attempt metadata.

#### Scenario: Async generated delay is used
- **WHEN** a delay strategy returns a future that completes with a non-null non-negative duration
- **THEN** the policy waits for that generated duration before scheduling the next attempt

#### Scenario: Generated delay falls back
- **WHEN** a generated delay returns null and a fallback delay is configured
- **THEN** the policy computes and waits for the fallback delay

### Requirement: Preserve broad retry capability without fixed options
The package SHALL express mainstream retry capabilities through open retry decision, delay, and hook extension points rather than a fixed external options object or backoff enum.

#### Scenario: max retry behavior is expressed through retryIf
- **WHEN** a caller needs a maximum retry budget
- **THEN** the caller can express the same extra-retry budget through a retry decision combinator

#### Scenario: backoff behavior is expressed through delay strategies
- **WHEN** a caller needs fixed, linear, exponential, jittered, capped, or generated retry delays
- **THEN** the caller can express those delays through delay strategy implementations and combinators without a fixed backoff enum

## MODIFIED Requirements

### Requirement: Retry by exception
The package SHALL allow callers to retry exceptions using retry decisions, including default exception matching and typed exception matching.

#### Scenario: Retryable exception is retried
- **WHEN** an operation throws an exception and the configured retry decision returns true for that exception attempt
- **THEN** the policy schedules another attempt

#### Scenario: Non-retryable exception is rethrown
- **WHEN** an operation throws an exception and the configured retry decision returns false for that exception attempt
- **THEN** the policy rethrows that exception without scheduling another attempt

### Requirement: Retry by result
The package SHALL allow callers to retry returned results using retry decisions that inspect typed result outcomes.

#### Scenario: Retryable result is retried
- **WHEN** an operation returns a result and the configured retry decision returns true for that result attempt
- **THEN** the policy schedules another attempt

#### Scenario: Non-retryable result is returned
- **WHEN** an operation returns a result and the configured retry decision returns false for that result attempt
- **THEN** the policy returns that result immediately

### Requirement: Delay retry attempts
The package SHALL support no delay, fixed delay, linear delay, exponential delay, random delay, generated delay, fallback delay, capped delay, stateful delay, and additive delay composition.

#### Scenario: Exponential delay is applied
- **WHEN** a policy is configured with exponential delay
- **THEN** each retry wait uses the configured initial duration, factor, and maximum duration

#### Scenario: Additive delay composition is applied
- **WHEN** a policy delay is configured as the sum of two delay strategies
- **THEN** the retry wait equals the sum of both computed durations for that attempt

#### Scenario: Generated delay overrides fallback delay
- **WHEN** a generated delay produces a non-null duration
- **THEN** that duration is used for the retry wait instead of the fallback delay

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
- **THEN** the policy retries only according to the documented combined decision result

#### Scenario: Retry decision negates a condition
- **WHEN** a broad retry decision is combined with the negation of a more specific decision
- **THEN** attempts matching the negated decision are not retried

#### Scenario: Delay strategy uses combined calculation
- **WHEN** delay strategies are combined through documented delay composition
- **THEN** the retry wait follows the documented combined delay result

### Requirement: Emit retry lifecycle hooks
The package SHALL expose retry lifecycle hooks that allow callers to observe scheduled retries and final non-cancellation give-up events without changing retry decisions.

#### Scenario: Retry hook receives attempt metadata
- **WHEN** a retryable outcome schedules another attempt
- **THEN** the retry hook receives metadata including retry index, attempt number, elapsed time, attempt duration, outcome, and next delay

#### Scenario: Retry hook can be asynchronous
- **WHEN** a retry hook returns a future
- **THEN** the policy waits for the hook future before waiting for the retry delay

#### Scenario: Give-up hook receives final metadata
- **WHEN** retry continuation is denied after a retry-handled outcome
- **THEN** the give-up hook receives metadata for the final outcome before the policy completes with that final outcome

### Requirement: Expose typed retry event outcomes
Retry lifecycle events SHALL expose typed attempt outcome and attempt metadata from retry event arguments.

#### Scenario: Hook reads typed outcome
- **WHEN** a retry hook receives retry event arguments
- **THEN** the hook can read the typed outcome without casting

#### Scenario: Hook reads retry attempt metadata
- **WHEN** a retry hook receives retry event arguments
- **THEN** the hook can read retry index, attempt number, attempt duration, elapsed time, and next delay

### Requirement: Support custom retry decisions
The package SHALL support custom retry decisions that inspect attempt metadata and return `FutureOr<bool>`.

#### Scenario: Custom retry decision controls retry
- **WHEN** a caller configures a custom retry decision
- **THEN** the policy schedules another attempt only when that decision returns true

#### Scenario: Custom retry decision inspects context
- **WHEN** a caller configures a custom retry decision that reads retry context metadata
- **THEN** the decision receives the same execution context as built-in retry decision combinators

## REMOVED Requirements

### Requirement: Stop retrying by attempts and elapsed time
**Reason**: Separate stop strategies duplicate the continuation responsibility now owned by `retryIf`.
**Migration**: Use retry decision combinators for maximum retries; combine retry with timeout/time strategies for total execution budgets.
