## 1. Shared Contracts

- [x] 1.1 Add a public `OutcomeContext<T>` contract that exposes `outcome`, `retryContext`, and `elapsed`.
- [x] 1.2 Add shared outcome access helpers for result, error/failure, stack trace, and unavailable-metadata errors.
- [x] 1.3 Add a reusable two-generic context-predicate base for context type and concrete predicate type.
- [x] 1.4 Move OR, AND, and NOT composition into the shared predicate implementation while preserving existing operator ergonomics.

## 2. Predicate Migration

- [x] 2.1 Rebase `OutcomePredicate<T>` on the shared context-predicate model.
- [x] 2.2 Rebase `FallbackPredicate<T>` and `FallbackContext<T>` on shared outcome-context and predicate contracts.
- [x] 2.3 Rebase `CircuitFailurePredicate` and `CircuitFailureContext` on shared outcome-context and predicate contracts.
- [x] 2.4 Rebase `HedgingPredicate<T>` and hedging outcome contexts on shared outcome-context and predicate contracts.

## 3. Predicate Semantics

- [x] 3.1 Normalize `where`, `exception`, `result`, `any`, and `never` factory semantics across predicate families.
- [x] 3.2 Ensure cancellation bypasses fallback and circuit-breaker predicate evaluation.
- [x] 3.3 Ensure fallback default exception handling is expressed through exception matching rather than `any()`.
- [x] 3.4 Remove obsolete private `_Or*`, `_And*`, and `_Not*` predicate classes.

## 4. Tests and Documentation

- [x] 4.1 Add tests for shared predicate OR, AND, NOT composition with synchronous and asynchronous predicates.
- [x] 4.2 Add fallback tests for exception, exhausted-result, any, never, cancellation, and shared context helper behavior.
- [x] 4.3 Add circuit breaker tests for exception/result classification, cancellation bypass, and custom predicate composition.
- [x] 4.4 Add hedging tests for normalized outcome predicate semantics and composition.
- [x] 4.5 Update README and API examples that reference old fallback or circuit predicate factory shapes.

## 5. Verification

- [x] 5.1 Run `dart format` on changed Dart files.
- [x] 5.2 Run targeted Dart tests for outcome, fallback, circuit breaker, and hedging behavior.
- [x] 5.3 Run `dart analyze`.
- [x] 5.4 Run strict OpenSpec validation for `unify-outcome-predicate-context`.
