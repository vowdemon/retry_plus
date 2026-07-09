## ADDED Requirements

### Requirement: Cover pipeline behavior parity
The pipeline test suite SHALL cover execution, ordering, nesting, context visibility, and cross-strategy scope behavior represented by the reference suite and rp pipeline specs.

#### Scenario: Empty pipeline is transparent
- **WHEN** a pipeline has no strategies
- **THEN** tests SHALL prove synchronous and asynchronous result/error behavior is unchanged

#### Scenario: Strategy order defines scope
- **WHEN** a pipeline contains multiple strategies
- **THEN** tests SHALL prove earlier strategies wrap later strategies and observe inner outcomes according to order

#### Scenario: Same-kind strategies are nested
- **WHEN** a pipeline contains multiple strategies of the same kind
- **THEN** tests SHALL prove each strategy instance applies to the inner pipeline it wraps

#### Scenario: Pipeline context hides retry attempt state
- **WHEN** a non-retry strategy or custom strategy receives pipeline context
- **THEN** tests SHALL prove retry attempt number, retry index, and retry-local outcome are not exposed through pipeline context

#### Scenario: Order-dependent composition differs predictably
- **WHEN** retry, timeout, fallback, circuit breaker, hedging, rate limiter, or injection strategies are placed in different orders
- **THEN** tests SHALL prove the changed scope and outcome are consistent with explicit pipeline ordering

#### Scenario: Pipeline telemetry remains ordered
- **WHEN** a pipeline execution triggers multiple strategy events
- **THEN** tests SHALL prove telemetry events are emitted in decision order with pipeline and strategy source identity
