## Context

`retry_plus` V1 development currently exposes a strategy-based `RetryPolicy<T>` that owns both configuration and execution. The package now needs to support timeout, fallback, circuit breaker, richer boolean strategy composition, and explicit runtime dependency injection. Keeping all of that inside `RetryPolicy<T>` would blur responsibilities and make the V1 API harder to evolve.

This change introduces a lower-level `RetryPipeline<T>` execution engine and keeps `RetryPolicy<T>` as the user-facing facade. The naming remains retry-focused for the package, but the architecture becomes a small resilience pipeline for V1.

## Goals / Non-Goals

**Goals:**

- Introduce `RetryPipeline<T>` as the internal and optionally advanced public execution engine.
- Keep `RetryPolicy<T>` as the primary top-level API for common users.
- Add timeout, fallback, and circuit breaker strategies.
- Preserve existing retry behavior while moving retry execution into a pipeline strategy.
- Define a deterministic runtime dependency model for clock, sleeper, random, scheduling, and observation.
- Split the current single implementation file into focused modules.

**Non-Goals:**

- Do not introduce a service locator, reflection, annotations, code generation, or framework DI integration.
- Do not depend on Flutter, HTTP packages, logging packages, or metrics packages.
- Do not make fallback operations retryable by default.
- Do not forcibly cancel arbitrary in-flight user code beyond Dart's cooperative `Future.timeout` behavior.
- Do not make strategy ordering caller-defined in the high-level `RetryPolicy<T>` constructor for V1.

## Decisions

### Bottom-level pipeline, top-level policy

`RetryPipeline<T>` will own execution. It will run a chain of strategy handlers around a user operation and pass a mutable execution context plus immutable policy options through the chain. `RetryPolicy<T>` will become a facade that accepts friendly configuration objects and builds the canonical pipeline.

Alternative considered: keep adding fields to `RetryPolicy<T>`. That is simpler short term, but it turns the policy into a mixed retry, timeout, fallback, circuit breaker, runtime, and event orchestration class.

### Fixed high-level strategy order

The high-level policy will use this order:

```text
Fallback
  -> CircuitBreaker
    -> Retry
      -> Timeout
        -> Operation
```

This order gives predictable semantics:

- A fallback can recover from circuit-open failures, retry exhaustion, timeout failures, and final operation failures.
- The circuit breaker protects the downstream operation and sees the final result of retry execution as one guarded call.
- Retry owns attempt scheduling and calls the timeout-wrapped operation once per attempt.
- Per-attempt timeout applies to each individual attempt.

Alternative considered: `Retry -> CircuitBreaker -> Timeout -> Fallback -> Operation`. That can retry fallback values and distort circuit breaker measurements. It is more flexible but less safe for the default V1 API.

### Timeout has per-attempt and overall modes

`TimeoutStrategy.perAttempt(duration)` wraps each operation attempt. `TimeoutStrategy.overall(duration)` caps the whole pipeline execution budget. When both are configured, overall timeout is outer and per-attempt timeout remains inside retry.

Alternative considered: only exposing `Future.timeout` at the operation boundary. That does not distinguish between each attempt timing out and the whole policy budget expiring.

### Fallback handles final failure only

Fallback strategy will convert final failures into a result. It can be configured with a value or callback and can filter by exception or exhausted result context. Fallback does not run inside retry and is not retried by default.

Alternative considered: retrying fallback. That can hide fallback instability and produce surprising repeated side effects.

### Circuit breaker is stateful and shared by policy instance

Circuit breaker state belongs to a strategy instance, so a reusable `RetryPolicy<T>` reuses the breaker across calls. The breaker has closed, open, and half-open states. It opens after configured failures, rejects calls while open, transitions to half-open after the recovery duration, and closes after configured successful probe calls.

Alternative considered: per-execution breaker state. That would be easy to implement but useless as a circuit breaker because every call would start closed.

### Runtime dependencies replace complex DI

`RetryRuntime` will carry clock, sleeper, random, timeout scheduler behavior where needed, and optional observer callbacks. Strategies use this runtime through the pipeline context. This gives deterministic tests without a general-purpose DI container.

Alternative considered: pass clock/sleeper/random separately into every strategy. That leaks test infrastructure across the public API and makes constructors noisy.

### Boolean logic belongs to strategies, not pipeline composition

Retry predicates and stop strategies get richer boolean composition: OR, AND, and NOT where meaningful. Pipeline composition remains ordered strategy execution rather than boolean logic. This keeps boolean expressions local to decisions and keeps execution order easy to reason about.

## Risks / Trade-offs

- [Risk] The package may feel broader than "retry" -> Keep `RetryPolicy<T>` as the main API and document timeout, fallback, and circuit breaker as policy strategies.
- [Risk] Pipeline abstractions can overcomplicate V1 -> Keep strategy order fixed in the high-level API and make custom pipeline use an advanced path.
- [Risk] Circuit breaker state can surprise users who expect stateless policies -> Document that a policy instance owns breaker state and provide explicit reset or state inspection APIs.
- [Risk] Timeout cannot safely terminate arbitrary synchronous work -> Document async/cooperative behavior and apply timeout to futures.
- [Risk] Fallback can hide real failures -> Require explicit fallback configuration and include final failure metadata in fallback callbacks.
- [Risk] Breaking constructor changes during V1 development can disrupt examples -> Update README, examples, tests, and changelog in the same change.

## Migration Plan

1. Introduce focused modules for runtime, events, pipeline, retry, timeout, fallback, circuit breaker, exceptions, and public facade exports.
2. Move current retry behavior into a retry pipeline strategy while keeping existing public retry examples working where possible.
3. Add new strategy APIs and deterministic tests.
4. Update documentation to present `RetryPolicy<T>` first and `RetryPipeline<T>` as the lower-level engine.

## Open Questions

- Should advanced users be allowed to construct arbitrary strategy order in V1, or should `RetryPipeline<T>` expose only the canonical order until the API stabilizes?
- Should circuit breaker count retry-exhausted execution as one failure or count each failed attempt? The recommended default is one failure per guarded policy execution.
