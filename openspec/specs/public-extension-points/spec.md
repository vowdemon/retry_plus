## Purpose

Defines the stable public extension model for custom retry behavior in `retry_plus`.

## Requirements

### Requirement: Define stable public extension contracts
The package SHALL document and test the public contracts that callers can implement or subclass to extend retry behavior without changing package internals.

#### Scenario: Caller implements a public extension contract
- **WHEN** a caller provides an implementation of a documented extension contract
- **THEN** the package accepts that implementation through the corresponding public API and executes it according to the documented contract

#### Scenario: Built-in implementations remain internal details
- **WHEN** the package changes private built-in implementation classes
- **THEN** callers using documented public extension contracts remain compatible

### Requirement: Support callback-based custom extensions
The package SHALL provide callback-based custom factories for extension points where callers commonly need simple custom behavior.

#### Scenario: Caller creates simple custom behavior without named class
- **WHEN** a caller configures custom behavior with a public callback factory
- **THEN** the behavior runs with the same context and composition semantics as an equivalent named implementation

### Requirement: Preserve deterministic custom behavior
Custom extension behavior SHALL receive deterministic runtime inputs through existing context and runtime APIs instead of relying on hidden global state.

#### Scenario: Custom behavior uses deterministic runtime inputs
- **WHEN** tests configure deterministic clock, sleep, random, timeout, or observer behavior
- **THEN** custom extensions observe the same deterministic inputs as built-in strategies

### Requirement: Keep extension model retry-focused
The package SHALL keep custom extension support focused on retry execution, retry decisions, timing, fallback handling, circuit failure classification, and ordered pipeline wrapping.

#### Scenario: Unsupported resilience pattern remains outside core
- **WHEN** a caller needs parallel execution, hedging, bulkheads, rate limiting, or unrelated dependency injection
- **THEN** the core package does not add those patterns as built-in requirements and callers can integrate separate behavior through explicit custom pipeline strategies if needed
