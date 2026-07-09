## ADDED Requirements

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
