## Why

The V1 pipeline implementation needs a correctness and API polish pass before more behavior is built on top of it. Cancellation currently risks being treated as a retryable/fallback/circuit-breaker failure, retry events expose an imprecise `Object` outcome type, fallback and circuit failure predicates are less composable than retry predicates, and custom pipeline ordering needs an explicit advanced API boundary.

## What Changes

- Ensure cancellation bypasses retry, fallback, and circuit breaker failure counting.
- Tighten `RetryEvent<T>.outcome` from `Object` to `AttemptOutcome<T>`.
- Reduce `RetryPredicate<T>` implementation duplication through an internal base class or mixin while preserving public behavior.
- Add fallback predicate composition with OR, AND, and NOT semantics.
- Add circuit breaker failure classification so only configured failures count toward opening the circuit.
- Add an explicit custom pipeline construction path while keeping high-level `RetryPolicy<T>` on the canonical safe order.
- Document strategy order risks and cancellation behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `strategy-retry`: Cancellation handling, typed retry events, and retry predicate implementation cleanup.
- `retry-pipeline`: Explicit custom pipeline ordering API and documentation of canonical versus custom order.
- `fallback-strategy`: Cancellation bypass and fallback predicate composition.
- `circuit-breaker-strategy`: Cancellation bypass and configurable failure classification.

## Impact

- Public API polish in `RetryEvent<T>`, fallback predicates, circuit breaker configuration, and pipeline constructors.
- Internal refactor in retry predicate implementation to reduce repeated operator methods.
- New regression tests for cancellation across retry, fallback, and circuit breaker.
- Documentation updates for custom pipeline ordering and cancellation semantics.
