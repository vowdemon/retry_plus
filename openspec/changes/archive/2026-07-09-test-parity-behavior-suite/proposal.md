## Why

`retry_plus` is adding multiple resilience strategies with open extension points and explicit pipeline ordering. The test suite needs to prove the behavior promised by each module spec and make differences from the external reference suite visible instead of accidental.

## What Changes

- Add a module-owned behavior test plan: each strategy/spec owns its relevant behavior tests.
- Add a cross-module parity process for comparing behavior against an external reference behavior suite at a logical level.
- Add a difference report requirement for any behavior that differs from the reference suite, including the reason and decision.
- Restructure planned tests so strategy-specific behavior lives in strategy-specific test files, while pipeline ordering and cross-strategy interaction remain in pipeline tests.
- Do not require API parity with the reference library; this change targets capability and behavior parity.

## Capabilities

### New Capabilities

- `behavior-test-parity`: Defines the test planning, reference comparison, and difference-reporting workflow for behavior parity.

### Modified Capabilities

- `strategy-retry`: Add retry-owned behavior test coverage based on retry reference behavior and rp-specific open predicates/policies.
- `retry-pipeline`: Add pipeline-owned behavior test coverage for ordering, nesting, same-kind strategies, context visibility, and cross-strategy scope.
- `timeout-strategy`: Add timeout-owned behavior test coverage for position-scoped timeouts, dynamic timeout computation, cancellation, hooks, and telemetry.
- `fallback-strategy`: Add fallback-owned behavior test coverage for handled outcomes, fallback callbacks, cancellation bypass, hooks, and telemetry.
- `circuit-breaker-strategy`: Add circuit-breaker-owned behavior test coverage for state transitions, metering, predicates, manual control, hooks, and telemetry.
- `hedging-strategy`: Add hedging-owned behavior test coverage for delayed hedges, winner selection, generated actions, cancellation coordination, hooks, and telemetry.
- `rate-limiter-strategy`: Add rate-limiter-owned behavior test coverage for leases, rejections, retry-after metadata, concurrency queues, cancellation, hooks, and telemetry.
- `injection-strategy`: Add injection-owned behavior test coverage for trigger semantics, throw/result/delay/behavior injections, cancellation, placement, and telemetry.
- `telemetry-core`: Add telemetry-owned behavior test coverage for event identity, source identity, listener fan-out, suppression, strategy names, and listener failure isolation.
- `telemetry-hook-lifecycle`: Add behavior test coverage for canonical event names and the separation between telemetry listeners and side-effect hooks.
- `outcome-handling`: Add outcome-owned behavior test coverage for result/error representation, metadata, cancellation exclusion, and predicate composition.
- `outcome-predicate-unification`: Add predicate-unification test coverage for shared context predicates and boolean composition across strategy predicate families.
- `public-extension-points`: Add extension-point behavior test coverage for custom strategy, predicate, delay, jitter, limiter, and telemetry extension contracts.

## Impact

- Affected planning artifacts: module specs under `openspec/specs/*`.
- Affected tests: `test/*_test.dart`, with planned splits for retry, timeout, fallback, circuit breaker, and pipeline composition tests.
- Affected docs/reporting: add a behavior parity difference report that records intentional and unintentional deviations.
- No runtime API change is required by this proposal; implementation tasks may add tests and test-support utilities only unless a parity gap exposes a product bug.
