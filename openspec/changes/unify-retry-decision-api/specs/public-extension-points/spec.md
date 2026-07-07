## MODIFIED Requirements

### Requirement: Define stable public extension contracts
The package SHALL document and test public contracts that callers can implement or subclass to extend retry behavior without changing package internals, including retry decisions and delay strategies that receive attempt metadata and may return `FutureOr` values.

#### Scenario: Caller implements a public extension contract
- **WHEN** a caller provides an implementation of a documented extension contract
- **THEN** the package accepts that implementation through the corresponding public API and executes it according to the documented contract

#### Scenario: Built-in implementations remain internal details
- **WHEN** the package changes private built-in implementation classes
- **THEN** callers using documented public extension contracts remain compatible

#### Scenario: Custom retry decision receives attempt metadata
- **WHEN** a caller implements a custom retry decision extension
- **THEN** the extension receives typed outcome, retry index, attempt number, elapsed time, attempt duration, and retry context

### Requirement: Support callback-based custom extensions
The package SHALL provide callback-based custom factories for extension points where callers commonly need simple custom behavior, including retry decisions, delay generation, jitter calculation, and retry hooks.

#### Scenario: Caller creates simple custom behavior without named class
- **WHEN** a caller configures custom behavior with a public callback factory
- **THEN** the behavior runs with the same context and composition semantics as an equivalent named implementation

#### Scenario: Callback extension returns a future
- **WHEN** a retry decision, delay generator, or retry hook callback returns a future
- **THEN** the package waits for that future at the documented retry lifecycle point

### Requirement: Preserve testable custom behavior
Custom extension behavior SHALL receive retry metadata through public attempt/context objects and SHALL be testable through public strategy APIs, `package:clock` time control, direct delay calculations, explicit callbacks, and event observers instead of runtime dependency injection.

#### Scenario: Custom behavior uses public testing paths
- **WHEN** tests configure clock zones, direct delay calculations, timeout operations, or event callbacks
- **THEN** custom extensions observe the same public behavior as built-in strategies

#### Scenario: Stateful delay is testable per execution
- **WHEN** a custom delay strategy keeps per-execution state
- **THEN** tests can verify that state through repeated executions without relying on private internals

### Requirement: Keep extension model retry-focused
The package SHALL keep custom extension support focused on retry execution, retry decisions, timing, fallback handling, circuit failure classification, and ordered pipeline wrapping.

#### Scenario: Unsupported resilience pattern remains outside core
- **WHEN** a caller needs parallel execution, hedging, bulkheads, rate limiting, or unrelated dependency injection
- **THEN** the core package does not add those patterns as built-in requirements and callers can integrate separate behavior through explicit custom pipeline strategies if needed

#### Scenario: Polly retry behavior is expressible through retry extension points
- **WHEN** a caller needs retry behavior equivalent to Polly retry configuration
- **THEN** the caller can express that behavior through retry decision, delay, and hook extension points without requiring Polly-compatible option objects
