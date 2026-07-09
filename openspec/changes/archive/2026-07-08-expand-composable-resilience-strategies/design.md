## Context

`retry_plus` already has an ordered `RetryPipeline<T>` and an open retry decision API. The current lower-level pipeline applies strategies in caller-provided order, which matches the key composition rule: earlier strategies wrap later strategies. However, several existing convenience APIs still encode strategy scope as options, especially timeout per-attempt/overall behavior, and non-retry reactive strategies classify only failures rather than typed results and failures.

A mainstream resilience model separates proactive strategies, such as timeout and rate limiting, from reactive strategies, such as retry, fallback, circuit breaker, and hedging outcome handling. The important capability to preserve is not fixed option names; it is that strategy order, outcome classification, dynamic generators, hooks, and cancellation semantics can express the same behavior.

## Goals / Non-Goals

**Goals:**

- Make ordered pipeline composition the authoritative way to express strategy scope and interaction.
- Provide a shared outcome model for result and exception classification across retry, fallback, circuit breaker, and hedging.
- Preserve open extension points through public abstract contracts and callback factories rather than fixed enums.
- Cover equivalent fallback, circuit breaker, hedging, rate limiter, concurrency limiter, and timeout composition capabilities.
- Keep cancellation distinct from timeout and rate-limit rejection.
- Keep strategies testable through public APIs, clock control, explicit hooks, and pipeline events.

**Non-Goals:**

- Do not clone fixed option-object API, builder extension names, or `System.Threading.RateLimiting` abstractions.
- Do not add dependency injection, registry, dynamic reload, telemetry source hierarchy, or chaos strategies in this change.
- Do not make `RetryPolicy<T>` the complete composition surface; it remains a convenience facade.
- Do not guarantee forced cancellation of arbitrary user work that ignores the provided execution context.

## Decisions

### Decision: introduce shared typed outcome handling

Reactive strategies will classify a typed outcome object that can represent either a result or an exception with stack trace and execution metadata. Built-in predicates will cover exception type, result predicate, any, never, and boolean composition. Callback factories will support `FutureOr<bool>`.

Alternative considered: keep separate `RetryIf`, `FallbackPredicate`, and `CircuitFailurePredicate` models. That preserves smaller local APIs, but prevents fallback and circuit breaker from matching returned results and makes equivalent `ShouldHandle` behavior inconsistent.

### Decision: keep strategy names domain-specific but share predicate shape

The user-facing names remain domain-specific: `retryIf`, `fallbackIf`, `failureIf`, and `hedgeIf`. They should feel like rp APIs rather than a generic `ShouldHandle` clone. Internally and structurally they share the same outcome metadata and composition behavior.

Alternative considered: expose one public `ShouldHandle<T>` everywhere. That would be simpler mechanically but less readable at call sites and too close to external naming.

### Decision: make timeout position-scoped

Timeout becomes a normal strategy with one timeout duration or generator. Per-attempt and overall semantics are expressed by placement:

```text
Retry
  Timeout
    operation
```

means each retry attempt is timed. Conversely:

```text
Timeout
  Retry
    operation
```

means the whole retry flow is timed.

Alternative considered: keep `TimeoutStrategy.perAttempt` and `TimeoutStrategy.overall` as primary constructors. That is familiar but duplicates information already expressed by pipeline position and fails for multiple nested retry/hedging scenarios.

### Decision: move high-level policy toward a thin convenience facade

`RetryPipeline<T>` remains the authoritative composition surface. `RetryPolicy<T>` may continue to offer a common default order, but it must not be required for expressing equivalent combinations. Examples and specs should prefer explicit pipeline ordering for advanced behavior.

Alternative considered: keep expanding `RetryPolicy<T>` with more named fields. That leads to a rigid canonical graph and cannot express multiple retries, multiple timeouts, nested hedging, or user-defined strategy placement cleanly.

### Decision: upgrade circuit breaker through pluggable metering

Circuit breaker state management will be separated from failure classification and failure metering. The built-in meters will include consecutive failures and failure ratio over a sampling window with minimum throughput. Break duration can be fixed or generated from open-event metadata. State provider and manual control are public views over the same breaker instance.

Alternative considered: replace the current breaker with only fixed-option ratio settings. That would regress simple consecutive failure use cases and make small workloads harder to configure.

### Decision: model rate limiting through leases

Rate limiter and concurrency limiter strategies will acquire a lease before calling the inner pipeline. If the lease is acquired, it is released after the inner pipeline completes. If not acquired, the strategy emits rejection metadata, invokes an optional hook, and throws a rejection exception that can carry `retryAfter`.

Alternative considered: expose only fixed concurrency and queue parameters. That covers the common case but blocks token buckets, sliding windows, external limiters, and dynamic retry-after metadata.

### Decision: implement hedging as a parallel strategy with explicit action generation

Hedging starts the primary action, starts additional actions when the delay expires or prior outcomes are handled, and returns the first acceptable outcome. Built-in default actions rerun the original inner pipeline; custom action generators can route hedges to alternate endpoints or behavior. Losing actions receive cancellation through execution context when possible.

Alternative considered: simulate hedging with retry. That is not equivalent because retry is serial and cannot reduce tail latency by racing concurrent work.

## Risks / Trade-offs

- **API churn**: Outcome-aware predicates replace some exception-only contracts. Mitigation: this is a development version; provide clear migration examples from exception predicates to outcome predicates.
- **Scope confusion**: Position-scoped timeout is powerful but requires users to understand order. Mitigation: document order with diagrams and keep simple convenience helpers as wrappers where they do not hide semantics.
- **Hedging resource cost**: Hedging can multiply downstream load. Mitigation: require explicit max hedged attempts, expose delay generators, and document pairing with rate/concurrency limiters.
- **Cancellation limitations**: Dart futures cannot always stop underlying work. Mitigation: make cancellation cooperative through execution context and document that ignored cancellation can delay resource release.
- **Breaker complexity**: Ratio windows and half-open probes add state complexity. Mitigation: keep meter/state/control components separately testable and retain a simple consecutive-failure factory.
- **Limiter fairness**: Queue ordering and cancellation can be subtle. Mitigation: specify FIFO semantics for built-in queues and expose custom limiter contracts for advanced policies.

## Migration Plan

1. Add shared outcome and outcome predicate contracts without changing strategy behavior.
2. Update fallback and circuit breaker to use outcome-aware predicates and asynchronous hooks.
3. Replace timeout scope-specific core behavior with position-scoped timeout while preserving compatibility helpers where reasonable.
4. Add rate limiter and concurrency limiter strategies using lease abstractions.
5. Add hedging strategy after execution context/cancellation support is sufficient.
6. Update `RetryPolicy<T>` and README to position explicit `RetryPipeline<T>` as the advanced composition API.
7. Update the capability report to reflect covered strategy capabilities.

Rollback is straightforward while unreleased: revert this change and keep current exception-only fallback/circuit plus scoped timeout APIs.

## Open Questions

- Should the shared outcome type replace the existing `AttemptOutcome<T>` directly, or should `AttemptOutcome<T>` become a retry-specific view over a more general strategy outcome?
- Should the package rename `RetryPipeline<T>` to a more general resilience name in this development version, or keep the current name to avoid churn beyond strategy APIs?
- How much cooperative cancellation context should be exposed to user operations in the first hedging implementation?
