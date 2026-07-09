## ADDED Requirements

### Requirement: Apply position-scoped timeout
The package SHALL provide a timeout strategy whose scope is determined by its position in the ordered pipeline.

#### Scenario: Timeout inside retry scopes each attempt
- **WHEN** a retry strategy wraps a timeout strategy
- **THEN** each retry attempt receives a fresh timeout budget from the inner timeout strategy

#### Scenario: Timeout outside retry scopes whole retry flow
- **WHEN** a timeout strategy wraps a retry strategy
- **THEN** the timeout budget includes all retry attempts and retry delays executed by the inner retry strategy

#### Scenario: Multiple timeouts compose by position
- **WHEN** a pipeline includes nested timeout strategies
- **THEN** each timeout applies only to the inner pipeline it wraps

### Requirement: Support generated timeout durations
Timeout strategy SHALL support fixed and generated timeout durations using pipeline context.

#### Scenario: Timeout generator returns duration
- **WHEN** the timeout duration generator returns a positive duration
- **THEN** the strategy applies that duration to the wrapped inner pipeline

#### Scenario: Timeout generator disables timeout
- **WHEN** the timeout duration generator returns a value indicating no timeout
- **THEN** the strategy invokes the inner pipeline without applying a timeout for that execution

## MODIFIED Requirements

### Requirement: Observe cancellation with timeout
Timeout strategy SHALL distinguish caller cancellation from timeout cancellation and MUST NOT report caller cancellation as timeout.

#### Scenario: Cancellation wins before timeout
- **WHEN** cancellation is requested before a timeout duration expires
- **THEN** execution completes with cancellation rather than timeout

#### Scenario: Strategy timeout creates timeout failure
- **WHEN** the timeout strategy's own budget expires and the inner pipeline observes that cancellation
- **THEN** execution completes with a timeout failure visible to outer strategies

## REMOVED Requirements

### Requirement: Apply per-attempt timeout
**Reason**: Per-attempt timeout is now expressed by placing a timeout strategy inside retry or hedging action execution.
**Migration**: Use explicit ordered pipeline composition with `RetryStrategy` outside `TimeoutStrategy`.

### Requirement: Apply overall timeout
**Reason**: Overall timeout is now expressed by placing a timeout strategy outside the strategies it should wrap.
**Migration**: Use explicit ordered pipeline composition with `TimeoutStrategy` outside `RetryStrategy`, `HedgingStrategy`, or other inner strategies.

### Requirement: Distinguish timeout failure types
**Reason**: Timeout identity is now represented by strategy position, event metadata, and optional strategy labels rather than fixed per-attempt/overall scope enum values.
**Migration**: Use pipeline ordering, strategy metadata, and timeout events to identify which timeout strategy produced a failure.
