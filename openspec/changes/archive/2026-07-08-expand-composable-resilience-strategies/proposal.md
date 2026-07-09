## Why

`retry_plus` now has an open retry model, but its other resilience strategies still lag behind mainstream composable pipeline capabilities. To make rp capable of expressing broad resilience behavior without copying fixed option-object APIs, circuit breaker, fallback, hedging, rate limiting, timeout, and pipeline composition need a shared outcome-oriented, position-driven strategy model.

## What Changes

- Add a shared outcome-handling model so reactive strategies can classify both returned results and exceptions with open, composable, asynchronous predicates.
- Upgrade fallback from exception-only recovery to outcome-based recovery with asynchronous fallback actions and observation hooks.
- Upgrade circuit breaker from consecutive-failure counting to richer circuit meters, including failure ratio, sampling duration, minimum throughput, generated break durations, state observation, manual control, and result/exception classification.
- Introduce hedging as a first-class parallel strategy that can start additional executions on latency or handled outcomes, use generated delays/actions, return the first acceptable outcome, and coordinate cancellation.
- Introduce rate limiter and concurrency limiter strategies with lease-based extension points, queue/rejection behavior, retry-after metadata, and rejection hooks.
- Rework timeout as a position-scoped strategy whose per-attempt or overall behavior is determined by pipeline order, while still preserving cancellation-vs-timeout distinction.
- Make explicit pipeline ordering the primary way to express strategy scope and interaction; keep convenience APIs thin and non-authoritative.
- **BREAKING**: Remove or de-emphasize rigid per-attempt/overall timeout configuration from high-level policy APIs in favor of ordered strategy composition.
- **BREAKING**: Replace exception-only fallback/circuit predicate contracts with outcome-aware contracts.

## Capabilities

### New Capabilities

- `outcome-handling`: Shared typed result/exception outcome contracts, predicates, and lifecycle metadata used by reactive strategies.
- `hedging-strategy`: Parallel hedging strategy behavior, action generation, delay generation, outcome selection, hooks, and cancellation coordination.
- `rate-limiter-strategy`: Lease-based rate limiter and concurrency limiter behavior, queuing, rejection, retry-after metadata, and hooks.

### Modified Capabilities

- `retry-pipeline`: Pipeline order becomes the authoritative strategy composition model and high-level policy convenience order becomes secondary.
- `public-extension-points`: Extension contracts expand beyond retry-focused customization to cover outcome predicates, hedging, rate limiting, and richer strategy hooks.
- `fallback-strategy`: Fallback becomes outcome-based and supports asynchronous fallback actions and result handling.
- `circuit-breaker-strategy`: Circuit breaker supports outcome classification, ratio-based metering, generated break durations, state providers, manual control, and lifecycle hooks.
- `timeout-strategy`: Timeout behavior becomes position-scoped rather than encoded as fixed per-attempt/overall variants.

## Impact

- Affects public strategy APIs in `lib/src/retry_policy.dart`, `lib/src/pipeline.dart`, `lib/src/timeout_strategy.dart`, `lib/src/fallback_strategy.dart`, `lib/src/circuit_breaker_strategy.dart`, and new hedging/rate limiter modules.
- Requires updated tests for strategy ordering, timeout scope, fallback result handling, circuit metering, hedging races, limiter leases, cancellation, and equivalent compositions.
- Requires README and comparison report updates to document ordered composition and capability coverage.
- No external dependency is required; built-in limiter implementations should use Dart primitives and expose custom extension points for advanced users.
