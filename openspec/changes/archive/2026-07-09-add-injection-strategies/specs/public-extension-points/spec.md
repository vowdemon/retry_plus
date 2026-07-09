## MODIFIED Requirements

### Requirement: Define stable public extension contracts
The package SHALL document and test the public contracts that callers can implement or subclass to extend retry and resilience behavior without changing package internals, including injection triggers.

#### Scenario: Caller implements a public extension contract
- **WHEN** a caller provides an implementation of a documented extension contract
- **THEN** the package accepts that implementation through the corresponding public API and executes it according to the documented contract

#### Scenario: Built-in implementations remain internal details
- **WHEN** the package changes private built-in implementation classes
- **THEN** callers using documented public extension contracts remain compatible

#### Scenario: Shared predicate composition remains public
- **WHEN** a caller implements a strategy predicate using the shared context-predicate contract
- **THEN** the predicate can compose with built-in predicates through the documented OR, AND, and NOT operators

### Requirement: Support callback-based custom extensions
The package SHALL provide callback-based custom factories for extension points where callers commonly need simple custom behavior, including injection triggers, injection error generators, injection delay generators, injection result generators, and injection behavior callbacks.

#### Scenario: Caller creates simple custom behavior without named class
- **WHEN** a caller configures custom behavior with a public callback factory
- **THEN** the behavior runs with the same context and composition semantics as an equivalent named implementation

#### Scenario: Callback receives shared outcome context
- **WHEN** a callback-based predicate factory classifies an execution outcome
- **THEN** the callback receives a context that implements the shared outcome-context contract when that extension point is outcome-aware

#### Scenario: Callback extension returns a future
- **WHEN** a strategy predicate, generator, action, or hook callback returns a future
- **THEN** the package waits for that future at the documented lifecycle point

### Requirement: Preserve testable custom behavior
Custom extension behavior SHALL receive pipeline metadata through `RetryPipelineContext<T>` or strategy-specific metadata through a dedicated strategy context that exposes `RetryPipelineContext<T>`, and SHALL be testable through public strategy APIs, `package:clock` time control, direct calculations, explicit callbacks, and event observers instead of runtime dependency injection.

#### Scenario: Custom behavior uses public testing paths
- **WHEN** tests configure clock zones, direct delay calculations, limiter leases, timeout operations, injection triggers, or event callbacks
- **THEN** custom extensions observe the same public behavior as built-in strategies

#### Scenario: Custom outcome predicate uses public outcome helpers
- **WHEN** tests configure a custom outcome-aware predicate
- **THEN** the predicate can classify results, errors, and stack traces through public outcome-context helpers

### Requirement: Keep extension model focused on resilience composition
The package SHALL keep custom extension support focused on retry execution, retry decisions, timing, fallback handling, circuit failure classification, hedging classification, rate limiter behavior, injection behavior, and ordered pipeline wrapping.

#### Scenario: Resilience pattern is built into core
- **WHEN** a caller needs retry, timeout, fallback, circuit breaker, hedging, rate limiting, concurrency limiting, or injection strategies
- **THEN** the core package provides a documented built-in strategy or public extension contract for that pattern

#### Scenario: Unrelated integration remains outside core
- **WHEN** a caller needs dependency injection, pipeline registry, dynamic reload, or unrelated framework integration
- **THEN** the core package does not add those patterns as built-in requirements

#### Scenario: external retry behavior is expressible through retry extension points
- **WHEN** a caller needs retry behavior equivalent to external retry configuration
- **THEN** the caller can express that behavior through retry decision, delay, and hook extension points without requiring fixed external option objects
