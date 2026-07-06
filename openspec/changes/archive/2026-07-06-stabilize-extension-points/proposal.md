## Why

`retry_plus` cannot anticipate every retry predicate, stop rule, delay algorithm, jitter algorithm, or pipeline wrapper that callers will need. The package needs a stable public extension model so built-in strategies can stay focused while users can add custom behavior without modifying package internals.

## What Changes

- Define the public extension contracts that are intended to be implemented or subclassed by callers.
- Add callback-based custom factories for common extension points so callers do not need to create named classes for simple custom behavior.
- Document the intended split between `RetryPolicy<T>` as the convenient canonical facade and `RetryPipeline<T>` as the advanced open composition engine.
- Add tests proving custom strategies, predicates, delay, stop, and jitter implementations compose with existing built-in behavior.
- No breaking changes: existing built-in strategies and high-level policy behavior remain compatible.

## Capabilities

### New Capabilities

- `public-extension-points`: Defines the stable open/closed extension model for custom retry behavior, including strategy, predicate, delay, stop, jitter, and pipeline extension contracts.

### Modified Capabilities

- `retry-pipeline`: Clarifies that caller-defined `PipelineStrategy<T>` implementations are supported in ordered pipelines, including multiple custom strategies.
- `strategy-retry`: Adds explicit custom extension support for retry predicates, delay strategies, stop strategies, and jitter.
- `fallback-strategy`: Adds explicit custom extension support for fallback predicates.
- `circuit-breaker-strategy`: Adds explicit custom extension support for circuit failure predicates.

## Impact

- Public API additions in strategy and predicate modules.
- Documentation updates to identify stable extension points and recommended customization paths.
- Tests for custom extension behavior across retry, fallback, circuit breaker, and pipeline composition.
- No new runtime dependencies.
