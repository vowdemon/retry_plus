## 1. Cancellation Correctness

- [x] 1.1 Add regression tests proving fallback does not handle `RetryCancelledException`, including `FallbackPredicate<T>.any()`.
- [x] 1.2 Add regression tests proving retry does not treat cancellation as an attempt outcome and does not emit give-up for cancellation.
- [x] 1.3 Add regression tests proving circuit breaker does not count cancellation as a guarded execution failure.
- [x] 1.4 Update fallback, retry, and circuit breaker strategies to rethrow cancellation before classification or recovery behavior.

## 2. Retry Event And Predicate Polish

- [x] 2.1 Add a test showing `RetryEvent<T>.outcome` is statically usable as `AttemptOutcome<T>`.
- [x] 2.2 Change `RetryEvent<T>.outcome` from `Object` to `AttemptOutcome<T>`.
- [x] 2.3 Add regression tests for retry predicate OR, AND, and NOT behavior.
- [x] 2.4 Refactor retry predicate implementations to share operator implementations through an internal base class or mixin.

## 3. Fallback Predicate Composition

- [x] 3.1 Add tests for fallback predicate OR, AND, and NOT composition.
- [x] 3.2 Implement fallback predicate composition while preserving existing `FallbackPredicate.any`, `exceptionType`, `where`, and `retryExhausted` behavior.
- [x] 3.3 Document cancellation bypass and fallback predicate composition in dartdocs and README.

## 4. Circuit Failure Classification

- [x] 4.1 Add tests for circuit breaker failure predicates, including non-matching failures that do not open the circuit.
- [x] 4.2 Add tests proving cancellation does not affect circuit breaker state.
- [x] 4.3 Implement circuit breaker failure classification with a default predicate that counts ordinary failures and excludes cancellation.
- [x] 4.4 Add OR, AND, and NOT composition for circuit failure predicates.
- [x] 4.5 Update circuit breaker dartdocs and README examples for failure classification.

## 5. Custom Pipeline Ordering

- [x] 5.1 Add tests proving `RetryPipeline<T>` applies caller-provided strategies in list order.
- [x] 5.2 Add or document an explicit custom construction path such as `RetryPipeline.custom(...)` while keeping `RetryPolicy<T>` canonical.
- [x] 5.3 Add README guidance showing custom order as advanced usage and warning that order changes fallback, retry, timeout, and circuit breaker semantics.

## 6. Verification

- [x] 6.1 Run `dart format`.
- [x] 6.2 Run `dart analyze`.
- [x] 6.3 Run `dart test`.
