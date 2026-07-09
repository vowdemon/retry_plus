## ADDED Requirements

### Requirement: Acquire limiter lease before execution
The package SHALL provide a rate limiter strategy that acquires a lease before invoking the inner pipeline.

#### Scenario: Lease acquired
- **WHEN** the limiter returns an acquired lease
- **THEN** the strategy executes the inner pipeline and releases the lease after completion

#### Scenario: Lease rejected
- **WHEN** the limiter rejects the lease request
- **THEN** the strategy does not invoke the inner pipeline and completes with a rate-limit rejection failure

### Requirement: Support concurrency limiter
The package SHALL provide a built-in concurrency limiter that limits the number of concurrent executions and optionally queues pending executions.

#### Scenario: Permit available
- **WHEN** the number of in-flight executions is lower than the permit limit
- **THEN** the concurrency limiter grants a lease immediately

#### Scenario: Queue has capacity
- **WHEN** no permit is available and queue capacity remains
- **THEN** the concurrency limiter waits for a permit or cancellation before resolving the lease request

#### Scenario: Queue is full
- **WHEN** no permit is available and the queue is full
- **THEN** the concurrency limiter rejects the lease request

### Requirement: Support rate limiter extension contracts
The package SHALL expose public limiter and lease contracts so callers can provide custom rate limiting algorithms.

#### Scenario: Custom limiter grants lease
- **WHEN** a custom limiter returns an acquired lease
- **THEN** the strategy executes the inner pipeline using that lease

#### Scenario: Custom limiter provides retry after
- **WHEN** a rejected custom lease includes retry-after metadata
- **THEN** the rejection failure exposes that retry-after duration to outer strategies

### Requirement: Emit rate limiter rejection hook
The rate limiter strategy SHALL expose an asynchronous rejection hook invoked before returning or throwing a rate-limit rejection failure.

#### Scenario: Rejection hook runs
- **WHEN** the limiter rejects execution
- **THEN** the strategy invokes the configured rejection hook with context, lease metadata, and limiter metadata

#### Scenario: Outer retry handles rejection
- **WHEN** a retry strategy wraps a rate limiter strategy and matches the rate-limit rejection failure
- **THEN** retry can schedule another attempt according to its retry decision and delay strategy

### Requirement: Preserve cancellation while waiting for lease
The rate limiter strategy SHALL observe caller cancellation while waiting for a queued lease.

#### Scenario: Queued request is cancelled
- **WHEN** caller cancellation occurs while waiting in the limiter queue
- **THEN** the lease request is removed from the queue and execution completes with cancellation
