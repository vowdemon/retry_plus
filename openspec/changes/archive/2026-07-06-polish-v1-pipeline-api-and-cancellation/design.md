## Context

The V1 development pipeline now supports retry, timeout, fallback, circuit breaker, and runtime injection. The next risk is not missing a large feature; it is letting subtle semantics become public API debt. Cancellation is a control signal and should not be treated as a recoverable failure. Custom strategy order is useful for advanced users, but unsafe as the default. Predicate composition should be consistent across retry, fallback, and circuit classification.

## Goals / Non-Goals

**Goals:**

- Make cancellation bypass retry, fallback, and circuit breaker failure counting.
- Tighten public event typing by returning `AttemptOutcome<T>` from `RetryEvent<T>.outcome`.
- Add fallback predicate OR, AND, and NOT composition.
- Add circuit breaker failure classification with safe defaults.
- Keep `RetryPolicy<T>` on canonical order while adding an explicit custom `RetryPipeline<T>` construction path.
- Reduce internal retry predicate operator duplication without changing public behavior.

**Non-Goals:**

- Do not make `RetryPolicy<T>` accept arbitrary strategy order.
- Do not redesign pipeline execution or change canonical strategy order.
- Do not introduce logging, metrics, or HTTP-specific helpers.
- Do not change cancellation into a mechanism for forcibly interrupting in-flight user code.

## Decisions

### Cancellation is a control flow signal

`RetryCancelledException` and cancellation token reasons must bypass fallback, retry classification, and circuit breaker failure accounting. Strategies that catch broad errors must immediately rethrow cancellation before applying their own behavior.

Alternative considered: allowing fallback to handle cancellation when `FallbackPredicate<T>.any()` is used. That makes cancellation unreliable because a caller asking execution to stop can receive a normal fallback value.

### High-level order remains fixed, custom order is advanced

`RetryPolicy<T>` keeps the safe canonical order. `RetryPipeline<T>` exposes explicit custom construction for advanced users who understand the consequences of order. Documentation must show that changing order changes retry visibility, fallback retryability, timeout scope, and circuit breaker failure counting.

Alternative considered: adding ordered strategy lists to `RetryPolicy<T>`. That would make the common facade easier to misuse and weaken the distinction between safe defaults and advanced composition.

### Predicate composition becomes consistent

Fallback predicates get the same OR, AND, and NOT operator shape as retry predicates. Circuit breaker failure classification gets a predicate model as well, so callers can decide which failures should affect circuit state.

Alternative considered: leaving fallback and breaker predicates as ad hoc callbacks. That keeps implementation smaller but makes strategy APIs inconsistent and harder to extend.

### Retry predicate deduplication stays internal

Retry predicate implementations should share operator implementations through an internal base class or mixin. This reduces maintenance cost without changing public type names or behavior.

Alternative considered: leaving repeated methods in each predicate class. That is not a functional bug, but every new predicate would repeat the same operator boilerplate.

## Risks / Trade-offs

- [Risk] Custom pipeline order enables surprising behavior -> Keep it off `RetryPolicy<T>`, name it as advanced, and document examples of changed semantics.
- [Risk] Cancellation bypass can prevent intentional fallback-on-cancel use cases -> Treat cancellation as stop semantics for V1; callers can model user abort as a regular exception if they want fallback.
- [Risk] Adding circuit failure predicates increases API surface -> Use a small default predicate that counts ordinary failures but excludes cancellation.
- [Risk] Internal predicate refactor could accidentally change behavior -> Add regression tests for existing OR, AND, and NOT retry predicates.

## Migration Plan

1. Add cancellation regression tests across retry, fallback, and circuit breaker.
2. Add typed `RetryEvent<T>.outcome` tests and update the getter.
3. Add predicate composition tests for fallback and circuit failure classification.
4. Add explicit custom pipeline construction tests and docs.
5. Refactor retry predicate internals after behavior is covered.

## Open Questions

- Should circuit breaker failure classification count `RetryExhaustedException<T>` by default? Recommended: yes, while still excluding cancellation.
