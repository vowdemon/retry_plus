## ADDED Requirements

### Requirement: Represent strategy outcomes
The package SHALL provide a shared typed outcome contract that represents either a returned result or a thrown exception with stack trace and execution metadata for resilience strategies.

#### Scenario: Outcome represents result
- **WHEN** a strategy receives an operation result
- **THEN** the shared outcome exposes the typed result without requiring casts through exception-only context

#### Scenario: Outcome represents exception
- **WHEN** a strategy receives an operation exception
- **THEN** the shared outcome exposes the exception and captured stack trace

### Requirement: Provide outcome metadata
The shared outcome contract SHALL expose pipeline context, elapsed time, strategy-local attempt or action indexes when available, and strategy metadata needed by predicates and hooks.

#### Scenario: Predicate reads context metadata
- **WHEN** an outcome predicate is evaluated inside a pipeline execution
- **THEN** it can read the shared pipeline context and elapsed execution time

#### Scenario: Strategy adds metadata
- **WHEN** a strategy creates outcome metadata such as retry attempt number, hedging action index, or limiter retry-after
- **THEN** downstream predicates and hooks can inspect that metadata through public fields or typed event arguments

### Requirement: Support composable asynchronous outcome predicates
The package SHALL provide outcome predicate contracts that support synchronous or asynchronous result/exception classification with OR, AND, and NOT composition.

#### Scenario: Predicate matches result
- **WHEN** an outcome predicate is configured to match a returned result
- **THEN** it returns true for matching result outcomes and false for non-matching outcomes

#### Scenario: Predicate matches exception
- **WHEN** an outcome predicate is configured to match an exception type
- **THEN** it returns true for matching exception outcomes and false for non-matching outcomes

#### Scenario: Predicate composes with boolean operators
- **WHEN** two outcome predicates are combined with OR, AND, or NOT
- **THEN** the composed predicate follows the documented boolean semantics

#### Scenario: Predicate returns future
- **WHEN** an outcome predicate callback returns a future
- **THEN** the evaluating strategy waits for that future before making its decision

### Requirement: Exclude cancellation from default handled outcomes
Default outcome predicates SHALL treat package cancellation and caller cancellation as unhandled unless callers explicitly opt in through a custom predicate.

#### Scenario: Default predicate receives cancellation
- **WHEN** a default outcome predicate receives a cancellation outcome
- **THEN** it returns false and the strategy preserves cancellation semantics
