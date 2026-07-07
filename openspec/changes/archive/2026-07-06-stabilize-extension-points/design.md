## Context

`retry_plus` already exposes several abstraction points: `RetryPipelineStrategy<T>`, `DelayStrategy`, `StopStrategy`, `RetryPredicate<T>`, `FallbackPredicate<T>`, `CircuitFailurePredicate`, and `Jitter`. These are the right boundaries for open/closed extensibility, but the public contract is not yet explicit enough. Some extension points require callers to write named classes even for small custom rules, and documentation does not clearly separate stable extension interfaces from built-in implementation details.

The package should remain a retry-focused package. It should not grow into a generic dependency injection framework or a full Polly-style builder surface. The existing split is the right one: `RetryPolicy<T>` is the convenient high-level facade, while `RetryPipeline<T>` is the lower-level open composition engine.

## Goals / Non-Goals

**Goals:**

- Make public extension contracts explicit and test-covered.
- Provide callback factories for simple custom behavior without forcing callers to subclass.
- Preserve existing strategy composition semantics and default policy behavior.
- Keep `RetryPipeline<T>` as the advanced path for custom ordered strategy composition.
- Document which public types are stable extension points.

**Non-Goals:**

- Do not add parallel execution, hedging, bulkhead, or rate-limiting strategies.
- Do not introduce a service container, global dependency injection, reflection, or code generation.
- Do not turn `RetryPolicy<T>` into a general-purpose builder for arbitrary strategy ordering.
- Do not require built-in strategies to cover every domain-specific retry rule.

## Decisions

### Keep `RetryPolicy<T>` opinionated and `RetryPipeline<T>` open

`RetryPolicy<T>` should continue to build the canonical retry-oriented order used by the package. Users that need arbitrary composition should use `RetryPipeline<T>` directly with `RetryPipelineStrategy<T>` implementations.

Alternative considered: add a Polly-like builder to `RetryPolicy<T>`. This would blur the package boundary and make the common API more complex. The current two-layer model keeps common use simple and advanced composition explicit.

### Add callback factories at the existing extension points

The package should add public factory constructors such as `DelayStrategy.custom(...)`, `StopStrategy.custom(...)`, and `Jitter.custom(...)` where small custom behavior is common. Predicate types already expose callback-oriented factories for many cases, but the public docs and tests should still treat them as stable extension points.

Alternative considered: require callers to subclass every strategy or predicate. Subclassing remains supported, but callback factories reduce boilerplate and make extension easier without weakening type safety.

### Treat public extension interfaces as compatibility contracts

Types intended for user implementation should be documented as stable extension contracts. Internal built-in implementations can remain private and `final`; the open surface is the abstract/interface type and its public callback factories.

Alternative considered: make built-in strategy classes inheritable. That would expose implementation details and make future internal changes riskier. Composition through explicit extension contracts is cleaner.

### Keep custom behavior deterministic

Custom delay and jitter logic must receive the same deterministic runtime inputs used by built-in behavior. Custom pipeline strategies should use `PipelineContext<T>` for runtime dependencies, cancellation, elapsed time, attempt metadata, and event emission.

Alternative considered: allow custom strategies to access global time/randomness directly. That would weaken deterministic tests and make behavior less observable.

## Risks / Trade-offs

- Public extension interfaces become long-term compatibility commitments. → Keep the stable surface small and document it clearly.
- Callback factories can encourage large inline closures. → Document that complex behavior should use named strategy classes implementing the public contracts.
- Custom pipeline order can change fallback, timeout, retry, and circuit breaker semantics. → Keep it on `RetryPipeline<T>` and document it as advanced behavior.
- Generic custom factories can be too weakly typed if designed carelessly. → Keep signatures aligned with existing context objects such as `RetryContext<T>`, `AttemptOutcome<T>`, and `PipelineContext<T>`.
