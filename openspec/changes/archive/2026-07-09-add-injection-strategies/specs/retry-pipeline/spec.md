## MODIFIED Requirements

### Requirement: Surface pipeline events
The pipeline SHALL emit lifecycle events for strategy decisions, retries, timeout failures, fallback execution, circuit breaker state changes, rate limiter rejections, hedging actions, triggered injection behavior, cancellation, and final completion through explicit `onEvent` callbacks.

#### Scenario: Observer receives ordered events
- **WHEN** a pipeline execution triggers multiple strategies
- **THEN** observers receive events in the order the decisions occur

#### Scenario: Observer receives triggered injection event
- **WHEN** an injection strategy triggers inside a pipeline execution
- **THEN** the observer receives the corresponding injection event with public metadata

### Requirement: Document custom order semantics
The package SHALL document that custom pipeline order changes fallback handling, retry visibility, timeout scope, rate limiting scope, hedging scope, injection scope, and circuit breaker failure counting.

#### Scenario: Documentation warns about order changes
- **WHEN** documentation shows custom pipeline usage
- **THEN** it explains that custom order is the main model for advanced composition and changes observable behavior

#### Scenario: Documentation explains injection placement
- **WHEN** documentation shows injection strategy usage
- **THEN** it explains that placement controls whether retry, timeout, fallback, circuit breaker, hedging, or rate limiter strategies observe the injection behavior
