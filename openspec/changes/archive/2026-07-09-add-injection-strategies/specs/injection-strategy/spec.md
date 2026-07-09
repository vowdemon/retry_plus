## ADDED Requirements

### Requirement: Trigger injection through open predicates
The package SHALL provide an `InjectionTrigger<T>` contract that decides whether an injection strategy applies to the current pipeline execution using `RetryPipelineContext<T>`.

#### Scenario: Rate trigger applies injection
- **WHEN** a rate-based injection trigger evaluates with a random value inside its configured rate
- **THEN** the injection strategy applies its disturbance behavior

#### Scenario: Custom trigger controls injection
- **WHEN** a caller provides a custom injection trigger callback
- **THEN** the injection strategy applies only when that callback returns true

#### Scenario: Trigger composition follows predicate semantics
- **WHEN** injection triggers are combined with OR, AND, or NOT
- **THEN** the composed trigger follows the shared context-predicate boolean semantics

### Requirement: Provide injection context metadata
Injection callbacks SHALL receive the current `RetryPipelineContext<T>` directly.

#### Scenario: Trigger reads pipeline metadata
- **WHEN** an injection trigger evaluates during a pipeline execution
- **THEN** it can read the current pipeline context and elapsed time

#### Scenario: Trigger uses random source
- **WHEN** a rate-based or custom trigger needs randomness
- **THEN** it uses the random source exposed by injection context rather than creating an unrelated source

### Requirement: Throw injection errors
The package SHALL provide `InjectionThrowStrategy<T>` that throws a generated error instead of invoking the inner pipeline when triggered.

#### Scenario: Throw injection triggers
- **WHEN** throw injection is triggered
- **THEN** the strategy throws the generated error and does not invoke the inner pipeline

#### Scenario: Outer retry observes thrown injection
- **WHEN** a retry strategy wraps triggered throw injection and its retry decision matches the thrown error
- **THEN** retry can schedule another attempt according to its retry decision and delay

### Requirement: Delay injection execution
The package SHALL provide `InjectionDelayStrategy<T>` that waits for a generated delay before invoking the inner pipeline when triggered.

#### Scenario: Delay injection triggers
- **WHEN** delay injection is triggered
- **THEN** the strategy waits for the generated duration and then invokes the inner pipeline

#### Scenario: Timeout can cover injection delay
- **WHEN** a timeout strategy wraps triggered delay injection
- **THEN** the injection delay is part of the timeout scope

#### Scenario: Cancellation interrupts injection delay
- **WHEN** caller cancellation occurs while delay injection is waiting
- **THEN** the execution completes with cancellation instead of continuing to the inner pipeline

### Requirement: Return injection results
The package SHALL provide `InjectionResultStrategy<T>` that returns a generated result instead of invoking the inner pipeline when triggered.

#### Scenario: Result injection triggers
- **WHEN** result injection is triggered
- **THEN** the strategy returns the generated result and does not invoke the inner pipeline

#### Scenario: Outer retry observes injection result
- **WHEN** a retry strategy wraps triggered result injection and its retry decision matches the returned result
- **THEN** retry can schedule another attempt according to its retry decision and delay

### Requirement: Run injection behavior
The package SHALL provide `InjectionBehaviorStrategy<T>` that runs a custom behavior callback and then invokes the inner pipeline when triggered.

#### Scenario: Behavior injection triggers
- **WHEN** behavior injection is triggered
- **THEN** the strategy waits for the behavior callback and then invokes the inner pipeline

#### Scenario: Behavior failure propagates
- **WHEN** the injection behavior callback throws or returns a failed future
- **THEN** that failure is propagated according to pipeline order

### Requirement: Emit injection pipeline events
Triggered injection strategies SHALL emit an injection-specific `PipelineEvent` before applying their disturbance behavior.

#### Scenario: Throw injection emits event
- **WHEN** throw injection is triggered
- **THEN** the pipeline observer receives an `injectionThrow` event with public metadata

#### Scenario: Delay injection emits event
- **WHEN** delay injection is triggered
- **THEN** the pipeline observer receives an `injectionDelay` event with public metadata including the delay duration

#### Scenario: Result injection emits event
- **WHEN** result injection is triggered
- **THEN** the pipeline observer receives an `injectionResult` event with public metadata

#### Scenario: Behavior injection emits event
- **WHEN** behavior injection is triggered
- **THEN** the pipeline observer receives an `injectionBehavior` event with public metadata

### Requirement: Preserve silent skip behavior
Injection strategies SHALL invoke the inner pipeline without emitting injection events when their trigger does not apply.

#### Scenario: Injection is skipped
- **WHEN** an injection strategy trigger returns false
- **THEN** the strategy invokes the inner pipeline without emitting an injection event

### Requirement: Preserve explicit pipeline placement
Injection strategies SHALL only run when callers place them in a `RetryPipeline<T>` strategy list.

#### Scenario: Policy convenience API excludes injection
- **WHEN** a caller uses `RetryPolicy<T>` convenience fields
- **THEN** injection strategies are not added implicitly

#### Scenario: Pipeline order controls injection scope
- **WHEN** a caller places injection before or after retry, timeout, fallback, circuit breaker, hedging, or rate limiter strategies
- **THEN** injection behavior is observed only by the strategies that wrap it according to normal pipeline order
