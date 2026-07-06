## ADDED Requirements

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
