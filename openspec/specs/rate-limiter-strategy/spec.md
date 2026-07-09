## Purpose

Defines rate limiter and concurrency limiter behavior for guarding pipeline executions.
## Requirements
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
The rate limiter strategy SHALL expose `rate_limiter.rejected` telemetry and an asynchronous rejection hook invoked before returning or throwing a rate-limit rejection failure.

#### Scenario: Rejection hook runs
- **WHEN** the limiter rejects execution
- **THEN** telemetry listeners receive `rate_limiter.rejected` and the strategy invokes the configured rejection hook with context, lease metadata, and limiter metadata

#### Scenario: Outer retry handles rejection
- **WHEN** a retry strategy wraps a rate limiter strategy and matches the rate-limit rejection failure
- **THEN** retry can schedule another attempt according to its retry decision and delay strategy

### Requirement: Preserve cancellation while waiting for lease
The rate limiter strategy SHALL observe caller cancellation while waiting for a queued lease.

#### Scenario: Queued request is cancelled
- **WHEN** caller cancellation occurs while waiting in the limiter queue
- **THEN** the lease request is removed from the queue and execution completes with cancellation

### Requirement: Cover rate limiter behavior parity
The rate limiter test suite SHALL cover lease acquisition, rejection, retry-after metadata, concurrency queuing, cancellation, hook, telemetry, and resource ownership behavior represented by the reference suite.

#### Scenario: Lease controls execution
- **WHEN** a lease is acquired
- **THEN** tests SHALL prove the guarded operation executes and the lease is released after success or failure

#### Scenario: Rejected lease skips execution
- **WHEN** a lease is rejected
- **THEN** tests SHALL prove the guarded operation is not invoked and the rejection outcome carries retry-after metadata when available

#### Scenario: Outer retry can observe rejection
- **WHEN** retry wraps rate limiter and the limiter rejects
- **THEN** tests SHALL prove retry can handle the rejection according to retry predicates

#### Scenario: Concurrency limiter queues and rejects
- **WHEN** concurrency permits are exhausted
- **THEN** tests SHALL cover FIFO queueing, queue-full rejection, and queued cancellation without permit leakage

#### Scenario: Limiter observations and ownership are correct
- **WHEN** rejection occurs or the pipeline is disposed
- **THEN** tests SHALL cover rejection hook arguments, telemetry event data, strategy name, internal limiter disposal, and external limiter non-disposal

### Requirement: Support token bucket limiter
The package SHALL provide a built-in token bucket limiter that grants leases by consuming tokens from a bounded bucket that refills over time.

#### Scenario: Token is available
- **WHEN** a token bucket limiter has at least one token available
- **THEN** acquiring a lease consumes one token and returns an acquired lease

#### Scenario: Token bucket is empty
- **WHEN** a token bucket limiter has no token available
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the time until the next token can be available

#### Scenario: Token bucket refills over time
- **WHEN** enough time has elapsed for one or more refill periods
- **THEN** later acquisitions can use the refilled tokens

#### Scenario: Token bucket respects capacity
- **WHEN** more refill time elapses than needed to fill the bucket
- **THEN** the bucket stores no more than its configured capacity

### Requirement: Support fixed window limiter
The package SHALL provide a built-in fixed window limiter that allows a configured number of leases per fixed time window.

#### Scenario: Fixed window permit is available
- **WHEN** the current fixed window has remaining permits
- **THEN** acquiring a lease consumes one permit and returns an acquired lease

#### Scenario: Fixed window is exhausted
- **WHEN** the current fixed window has consumed all permits
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the remaining time in the current window

#### Scenario: Fixed window resets
- **WHEN** acquisition occurs after the current fixed window has ended
- **THEN** the limiter starts a new window with the full permit limit available

### Requirement: Support sliding window limiter
The package SHALL provide a built-in sliding window limiter that divides a window into segments and limits acquisitions across the rolling window.

#### Scenario: Sliding window permit is available
- **WHEN** the rolling window has fewer consumed permits than the configured permit limit
- **THEN** acquiring a lease records the acquisition in the current segment and returns an acquired lease

#### Scenario: Sliding window is exhausted
- **WHEN** the rolling window has consumed the configured permit limit
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the time until enough recorded acquisitions expire

#### Scenario: Sliding window drops stale segments
- **WHEN** acquisitions were recorded outside the active rolling window
- **THEN** those stale acquisitions no longer count against the current permit limit

### Requirement: Keep time-based limiters passive
Built-in time-based limiters SHALL update their state during lease acquisition and SHALL NOT require background timers, background workers, or explicit disposal.

#### Scenario: Time advances without acquisition
- **WHEN** time advances while no acquisition is attempted
- **THEN** the limiter performs no background work and applies elapsed time on the next acquisition

#### Scenario: Limiter is shared by multiple strategies
- **WHEN** the same built-in limiter instance is used by multiple rate limiter strategies
- **THEN** the limiter state is shared through that limiter instance and not through the strategies

