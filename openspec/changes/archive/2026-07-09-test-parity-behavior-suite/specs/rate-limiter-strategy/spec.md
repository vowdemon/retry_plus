## ADDED Requirements

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
