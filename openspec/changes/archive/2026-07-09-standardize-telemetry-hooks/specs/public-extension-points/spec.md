## MODIFIED Requirements

### Requirement: Support callback-based custom extensions
The package SHALL provide callback-based custom factories for extension points where callers commonly need simple custom behavior, including telemetry listeners, severity providers, and awaited side-effect hooks.

#### Scenario: Caller creates simple custom behavior without named class
- **WHEN** a caller configures custom behavior with a public callback factory
- **THEN** the behavior runs with the same context and composition semantics as an equivalent named implementation

#### Scenario: Callback receives shared outcome context
- **WHEN** a callback-based predicate factory classifies an execution outcome
- **THEN** the callback receives a context that implements the shared outcome-context contract when that extension point is outcome-aware

#### Scenario: Callback extension returns a future
- **WHEN** a strategy predicate, generator, action, hook callback, or telemetry listener returns a future
- **THEN** the package waits for that future at the documented lifecycle point when the contract is asynchronous

#### Scenario: Caller configures severity provider callback
- **WHEN** a caller provides a telemetry severity provider callback
- **THEN** the callback can change or suppress telemetry events without changing strategy behavior

### Requirement: Keep extension model focused on resilience composition
The package SHALL keep custom extension support focused on retry execution, retry decisions, timing, fallback handling, circuit failure classification, hedging classification, rate limiter behavior, telemetry observation, side-effect lifecycle hooks, and ordered pipeline wrapping.

#### Scenario: Resilience pattern is built into core
- **WHEN** a caller needs retry, timeout, fallback, circuit breaker, hedging, rate limiting, concurrency limiting, telemetry observation, or side-effect lifecycle hooks
- **THEN** the core package provides a documented built-in strategy or public extension contract for that pattern

#### Scenario: Unrelated integration remains outside core
- **WHEN** a caller needs dependency injection, pipeline registry, dynamic reload, logging adapters, metrics exporters, OpenTelemetry exporters, or unrelated framework integration
- **THEN** the core package does not add those patterns as built-in requirements

#### Scenario: external retry behavior is expressible through retry extension points
- **WHEN** a caller needs retry behavior equivalent to external retry configuration
- **THEN** the caller can express that behavior through retry decision, delay, and hook extension points without requiring fixed external option objects
