## Why

Reactive strategies now share the same conceptual model: they inspect an outcome, apply an asynchronous predicate, and compose predicates with OR, AND, and NOT. The implementation still repeats that model across fallback, circuit breaker, hedging, and outcome predicates, which risks semantic drift and makes future strategy work harder than necessary.

## What Changes

- Introduce a shared outcome-context contract that exposes the common outcome, retry context, and elapsed-time metadata used by reactive strategy predicates and hooks.
- Introduce reusable context-predicate composition so strategy-specific predicates no longer need private `_Or*`, `_And*`, and `_Not*` implementations.
- Rebase fallback, circuit breaker, hedging, and generic outcome predicates on the shared predicate composition model while preserving their domain-specific names.
- Add shared outcome-context access helpers for result, error, and stack trace metadata instead of duplicating failure-only getters in each strategy context.
- Align built-in predicate semantics across strategies, especially `any`, `exception`, `result`, `never`, and cancellation bypass.
- **BREAKING**: Adjust fallback predicate naming so default fallback exception handling is not expressed through `any()`.
- **BREAKING**: Normalize strategy predicate factory shapes where current APIs require awkward generic ordering or static factories.

## Capabilities

### New Capabilities
- `outcome-predicate-unification`: Shared outcome context and reusable context-predicate composition contracts for reactive resilience strategies.

### Modified Capabilities
- `fallback-strategy`: Fallback predicates and contexts will use the shared outcome-context and predicate composition model.
- `circuit-breaker-strategy`: Circuit failure predicates and contexts will use the shared outcome-context and predicate composition model.
- `public-extension-points`: Public extension contracts will include the shared context-predicate base and outcome-context access helpers.

## Impact

- Affects `lib/src/outcome.dart`, `lib/src/predicate.dart`, `lib/src/fallback_strategy.dart`, `lib/src/circuit_breaker_strategy.dart`, and `lib/src/hedging_strategy.dart`.
- Updates tests for predicate composition, default predicate semantics, fallback result/error context access, circuit failure classification, and hedging handled-outcome classification.
- Updates README/API examples where fallback or circuit predicate factories use old generic/static forms.
- No new runtime dependency is required.
