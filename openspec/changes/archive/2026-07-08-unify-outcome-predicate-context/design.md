## Context

`retry_plus` now has several reactive resilience strategies that classify completed execution outcomes:

- `OutcomePredicate<T>` classifies generic `StrategyOutcome<T>` values.
- `FallbackPredicate<T>` classifies final failures before returning fallback results.
- `CircuitFailurePredicate` classifies guarded execution failures before updating breaker state.
- `HedgingPredicate<T>` classifies outcomes that should trigger alternate executions.

Each predicate family repeats the same shape: receive a context, evaluate synchronously or asynchronously, and compose with OR, AND, and NOT. Context objects also repeat outcome access, elapsed time, retry metadata, and failure/result helpers. This change consolidates that common model without forcing fixed-option names or fixed configuration enums.

## Goals / Non-Goals

**Goals:**

- Define a shared `OutcomeContext<T>` contract for strategy contexts that carry an execution outcome.
- Define reusable predicate composition using two generic parameters: context type and concrete predicate type.
- Remove duplicated private `_Or*`, `_And*`, and `_Not*` predicate implementations from fallback, circuit breaker, hedging, and generic outcome predicates.
- Keep strategy-specific public names such as `FallbackPredicate`, `CircuitFailurePredicate`, and `HedgingPredicate`.
- Normalize built-in predicate semantics across strategies for `any`, `exception`, `result`, `never`, custom callbacks, and cancellation bypass.
- Preserve open-ended predicate callbacks so callers can express behavior beyond fixed enum-style configuration.

**Non-Goals:**

- Do not copy external API names or configuration shapes.
- Do not replace strategy-specific predicates with one generic predicate type at every call site.
- Do not introduce runtime dependency injection or a new package dependency.
- Do not change retry, fallback, circuit breaker, hedging, timeout, or rate limiter execution ordering except where predicate semantics are explicitly normalized.

## Decisions

### Shared outcome-context contract

Introduce an `OutcomeContext<T>` interface that exposes the common data reactive strategies inspect:

- `StrategyOutcome<T> outcome`
- `RetryContext<T> retryContext`
- `Duration elapsed`

Fallback, hedging, and generic outcome contexts implement `OutcomeContext<T>` directly. Circuit breaker contexts can implement `OutcomeContext<Object?>` if the breaker remains non-generic internally, or `OutcomeContext<T>` if the public breaker predicate becomes generic during implementation. The key contract is that breaker failure classification uses the same outcome-context shape even if breaker state remains shared across result types.

Alternative considered: one large base context containing all strategy-specific fields. That would couple unrelated strategies and make the common abstraction harder to understand. A small interface keeps the shared contract focused.

### Reusable predicate composition with context and self type

Introduce a generic base such as:

```dart
abstract class ContextPredicate<C, Self extends ContextPredicate<C, Self>>
    with PredicateOperators<Self> {
  const ContextPredicate();

  FutureOr<bool> test(C context);

  Self build(FutureOr<bool> Function(C context) callback);
}
```

The existing operator mixins can delegate `or`, `and`, and `not` to shared implementations that call `build(...)`, so each concrete predicate family only defines how to wrap a callback in its own type. This directly addresses the duplicated `_OrFallbackPredicate<T>`, `_OrOutcomePredicate<T>`, `_OrHedgingPredicate<T>`, and `_OrCircuitFailurePredicate` classes.

Alternative considered: top-level helper functions for each boolean operator. That would reduce some code but still leave every predicate family responsible for exposing a consistent public composition API.

### Keep domain-specific predicate classes

Keep public predicate classes per strategy:

- `OutcomePredicate<T>`
- `FallbackPredicate<T>`
- `CircuitFailurePredicate` or `CircuitFailurePredicate<T>`
- `HedgingPredicate<T>`

They become thin wrappers around the shared context-predicate composition model. This preserves readable call sites, static factories, documentation, and strategy-specific semantics while sharing the mechanics.

Alternative considered: a single `ContextPredicate<C>` type everywhere. Dart typedefs and generic bases cannot provide strategy-specific factory constructors cleanly, and call sites would lose useful domain names.

### Normalize outcome access

Use `StrategyOutcome<T>` as the primary source of outcome data. Provide shared access helpers for:

- `result`
- `error` or `failure`
- `stackTrace`
- boolean state checks such as success/failure/cancellation if they are not already available on `StrategyOutcome<T>`

Strategy contexts should avoid duplicating derived getters unless they provide a domain alias for readability. If aliases remain, they delegate to the shared helpers.

Alternative considered: keep `failure` and `stackTrace` copied into each context. That is simple locally but creates drift as more strategies inspect both exceptions and results.

### Align built-in predicate semantics

Built-in predicate factories should mean the same thing across strategy families:

- `where(...)`: caller-defined full-context predicate.
- `exception(...)`: matches exception outcomes, excluding cancellation unless a strategy explicitly documents otherwise.
- `result(...)`: matches successful result outcomes.
- `any()`: matches any non-cancellation outcome that the strategy is allowed to handle.
- `never()`: matches no outcome.

Fallback default exception handling should be expressed as exception matching, not as `any()`. Cancellation bypass remains outside normal predicate evaluation for strategies that must not swallow cancellation.

Alternative considered: keep existing `any()` as “all exceptions” for fallback. That name conflicts with result-aware strategies and makes cross-strategy behavior harder to reason about.

## Risks / Trade-offs

- API churn in a development version -> Accept the breaking change now and update tests/examples in the same implementation.
- Generic self types can look complex -> Keep the base API tiny: `test`, `build`, and shared boolean composition only.
- Circuit breaker result typing may conflict with shared state across result types -> Keep breaker state independent from predicate type; use `OutcomeContext<Object?>` or carefully scoped generics during implementation.
- Normalized `any()` may change fallback behavior -> Make default fallback use exception matching and add explicit tests for cancellation, exception, result, and retry-exhausted outcomes.
- Over-generalization risk -> Only share outcome context and boolean predicate composition; keep policy execution, event hooks, and strategy-specific metadata owned by each strategy.

## Migration Plan

1. Add shared outcome-context and context-predicate contracts.
2. Rebase generic outcome predicates on the shared predicate base.
3. Rebase fallback predicates and contexts, then update fallback tests and examples.
4. Rebase circuit failure predicates and contexts, then update breaker classification tests.
5. Rebase hedging predicates and contexts, then update hedging classification tests.
6. Remove obsolete private OR/AND/NOT classes and duplicate derived context fields.
7. Run formatting, analysis, targeted tests, and strict OpenSpec validation.

Rollback is a normal source revert while this remains unreleased development work.
