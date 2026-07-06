## Purpose

Defines per-attempt and overall timeout strategy behavior for retry pipeline execution.

## Requirements

### Requirement: Apply per-attempt timeout
The package SHALL provide a timeout strategy that limits the duration of each individual operation attempt.

#### Scenario: Attempt times out
- **WHEN** an operation attempt does not complete before the configured per-attempt timeout
- **THEN** the attempt completes with a timeout failure that retry predicates and fallback strategies can observe

#### Scenario: Later attempt can still succeed
- **WHEN** one attempt times out and retry allows another attempt
- **THEN** the next attempt starts with a fresh per-attempt timeout budget

### Requirement: Apply overall timeout
The package SHALL provide a timeout strategy that limits the duration of the whole pipeline execution.

#### Scenario: Overall timeout expires
- **WHEN** total pipeline execution exceeds the configured overall timeout
- **THEN** the pipeline stops and completes with an overall timeout failure

#### Scenario: Overall timeout includes retry delays
- **WHEN** retry delays consume time before the operation succeeds
- **THEN** those delays count toward the overall timeout budget

### Requirement: Distinguish timeout failure types
The package SHALL distinguish per-attempt timeout failures from overall timeout failures in exception and event metadata.

#### Scenario: Timeout metadata identifies scope
- **WHEN** a timeout failure is emitted
- **THEN** callers can determine whether it came from per-attempt timeout or overall timeout

### Requirement: Observe cancellation with timeout
Timeout strategy SHALL respect cancellation tokens at retry boundaries and during waits without claiming that arbitrary running user code was forcibly stopped.

#### Scenario: Cancellation wins before timeout
- **WHEN** cancellation is requested before a timeout duration expires
- **THEN** execution completes with cancellation rather than timeout
