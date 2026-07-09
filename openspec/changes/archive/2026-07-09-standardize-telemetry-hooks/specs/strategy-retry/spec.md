## MODIFIED Requirements

### Requirement: Emit retry lifecycle hooks
The package SHALL expose retry lifecycle hooks that allow callers to run awaited side effects when retry continuation is accepted and when final non-cancellation give-up occurs.

#### Scenario: Retry hook receives attempt metadata before delay calculation
- **WHEN** a retryable outcome is accepted for another retry
- **THEN** the retry hook receives metadata including retry index, attempt number, elapsed time, attempt duration, outcome, and pipeline context before the retry delay is computed

#### Scenario: Retry hook can influence delay inputs
- **WHEN** a retry hook updates state that a configured delay strategy reads
- **THEN** the delay strategy observes that updated state when computing the next delay

#### Scenario: Retry hook can be asynchronous
- **WHEN** a retry hook returns a future
- **THEN** the policy waits for the hook future before computing and waiting for the retry delay

#### Scenario: Give-up hook receives final metadata
- **WHEN** retry continuation is denied after a retry-handled outcome
- **THEN** the give-up hook receives metadata for the final outcome before the policy completes with that final outcome

### Requirement: Expose typed retry event outcomes
Retry lifecycle hooks SHALL receive `RetryAttemptContext<T>` directly with typed attempt outcome and attempt metadata, without exposing next delay.

#### Scenario: Hook reads typed outcome
- **WHEN** a retry hook receives retry or give-up attempt arguments
- **THEN** the hook can read the typed outcome without casting

#### Scenario: Hook reads retry attempt metadata
- **WHEN** a retry hook receives retry or give-up attempt arguments
- **THEN** the hook can read retry index, attempt number, attempt duration, elapsed time, and pipeline context

#### Scenario: Hook cannot read next delay
- **WHEN** a retry hook receives retry or give-up attempt arguments
- **THEN** the attempt metadata does not expose next delay
