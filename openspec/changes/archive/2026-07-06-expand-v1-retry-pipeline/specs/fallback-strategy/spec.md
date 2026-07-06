## ADDED Requirements

### Requirement: Return fallback value for final failure
The package SHALL provide a fallback strategy that can convert a final pipeline failure into a configured fallback result.

#### Scenario: Fallback value handles final exception
- **WHEN** execution ends with an exception that matches the fallback condition
- **THEN** the policy returns the configured fallback value

#### Scenario: Fallback value handles retry-exhausted result
- **WHEN** execution ends with `RetryExhaustedException<T>` and the fallback condition matches
- **THEN** the policy returns the configured fallback value

### Requirement: Compute fallback with callback
The package SHALL support fallback callbacks that receive final failure metadata and return a fallback result.

#### Scenario: Fallback callback receives failure context
- **WHEN** a fallback callback runs after final failure
- **THEN** it receives metadata including the failure, elapsed time, attempt data, and pipeline context

### Requirement: Filter fallback applicability
The fallback strategy SHALL allow callers to decide which exceptions or exhausted results are eligible for fallback.

#### Scenario: Non-matching failure is not handled
- **WHEN** final failure does not match the fallback condition
- **THEN** the original final failure is propagated

### Requirement: Do not retry fallback by default
Fallback strategy SHALL run outside retry and MUST NOT be retried by the default high-level policy order.

#### Scenario: Fallback callback throws
- **WHEN** a fallback callback throws an exception
- **THEN** that fallback exception is propagated and retry does not schedule another fallback attempt
