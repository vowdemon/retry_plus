## ADDED Requirements

### Requirement: Cover injection behavior parity
The injection test suite SHALL cover trigger, throw, result, delay, behavior, cancellation, placement, and telemetry behavior represented by reference chaos/fault-injection tests while using rp injection terminology.

#### Scenario: Injection trigger controls behavior
- **WHEN** an injection strategy evaluates always, never, rate, random, custom, or composed triggers
- **THEN** tests SHALL prove injection occurs or is skipped according to trigger semantics

#### Scenario: Throw injection is observable by outer strategies
- **WHEN** throw injection triggers inside retry, fallback, or circuit breaker scope
- **THEN** tests SHALL prove the outer strategy observes the injected failure according to pipeline order

#### Scenario: Result injection is observable by outer strategies
- **WHEN** result injection triggers inside retry or fallback scope
- **THEN** tests SHALL prove the outer strategy observes the injected result according to pipeline order

#### Scenario: Delay injection cooperates with timeout and cancellation
- **WHEN** delay injection triggers
- **THEN** tests SHALL prove timeout can cover the delay by position and cancellation interrupts the delay without invoking the inner operation

#### Scenario: Behavior injection runs or fails predictably
- **WHEN** behavior injection triggers
- **THEN** tests SHALL prove injected behavior runs before the inner operation, can replace or augment execution as specified, and propagates behavior failures

#### Scenario: Injection observations are emitted
- **WHEN** throw, result, delay, or behavior injection triggers
- **THEN** tests SHALL cover telemetry event data, strategy name, and skipped-injection silence
