## MODIFIED Requirements

### Requirement: Define stable public extension contracts
The package SHALL document and test public contracts that callers can implement or subclass to extend resilience behavior without changing package internals, including outcome predicates, retry decisions, delay strategies, fallback actions, circuit meters, timeout duration generators, hedging action generators, rate limiter leases, and pipeline strategies.

#### Scenario: Caller implements a public extension contract
- **WHEN** a caller provides an implementation of a documented extension contract
- **THEN** the package accepts that implementation through the corresponding public API and executes it according to the documented contract

#### Scenario: Built-in implementations remain internal details
- **WHEN** the package changes private built-in implementation classes
- **THEN** callers using documented public extension contracts remain compatible

#### Scenario: Custom outcome predicate receives metadata
- **WHEN** a caller implements a custom outcome predicate extension
- **THEN** the extension receives typed result or exception outcome metadata and the shared pipeline context

### Requirement: Support callback-based custom extensions
The package SHALL provide callback-based custom factories for extension points where callers commonly need simple custom behavior, including outcome predicates, retry decisions, delay generation, jitter calculation, fallback actions, circuit break duration generation, timeout duration generation, hedging delays/actions, rate limiter acquisition, and lifecycle hooks.

#### Scenario: Caller creates simple custom behavior without named class
- **WHEN** a caller configures custom behavior with a public callback factory
- **THEN** the behavior runs with the same context and composition semantics as an equivalent named implementation

#### Scenario: Callback extension returns a future
- **WHEN** a strategy predicate, generator, action, or hook callback returns a future
- **THEN** the package waits for that future at the documented lifecycle point

### Requirement: Preserve testable custom behavior
Custom extension behavior SHALL receive strategy metadata through public outcome/context objects and SHALL be testable through public strategy APIs, `package:clock` time control, direct calculations, explicit callbacks, and event observers instead of runtime dependency injection.

#### Scenario: Custom behavior uses public testing paths
- **WHEN** tests configure clock zones, direct delay calculations, limiter leases, timeout operations, or event callbacks
- **THEN** custom extensions observe the same public behavior as built-in strategies

#### Scenario: Stateful strategy extension is testable per execution
- **WHEN** a custom extension keeps per-execution state
- **THEN** tests can verify that state through repeated executions without relying on private internals

### Requirement: Keep extension model retry-focused
The package SHALL expand the public extension model beyond retry-only behavior to cover composable resilience strategies while preserving explicit pipeline integration.

#### Scenario: Resilience pattern is built into core
- **WHEN** a caller needs retry, timeout, fallback, circuit breaker, hedging, rate limiting, or concurrency limiting
- **THEN** the core package provides a documented built-in strategy or public extension contract for that pattern

#### Scenario: Unrelated integration remains outside core
- **WHEN** a caller needs dependency injection, pipeline registry, dynamic reload, or unrelated framework integration
- **THEN** the core package does not add those patterns as built-in requirements
