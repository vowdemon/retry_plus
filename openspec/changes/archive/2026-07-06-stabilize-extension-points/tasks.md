## 1. Public Extension API

- [x] 1.1 Add callback-based custom factories for delay strategies, stop strategies, and jitter.
- [x] 1.2 Review retry, fallback, and circuit predicate APIs and add missing callback aliases only where they improve consistency without duplicating existing behavior.
- [x] 1.3 Ensure public extension contracts have API documentation that marks them as intended for caller-defined behavior.

## 2. Pipeline Extension Coverage

- [x] 2.1 Add tests proving multiple caller-defined `RetryPipelineStrategy<T>` implementations execute in caller-provided order.
- [x] 2.2 Add tests proving custom pipeline strategies can read shared context and emit observable pipeline events.
- [x] 2.3 Keep `RetryPolicy<T>` canonical and add or update tests that distinguish high-level policy order from custom pipeline order.

## 3. Retry Strategy Extension Coverage

- [x] 3.1 Add tests for custom retry predicate implementations and callback-based retry predicates.
- [x] 3.2 Add tests for custom delay implementations and callback-based delay strategies using deterministic random input.
- [x] 3.3 Add tests for custom stop implementations and callback-based stop strategies using next-delay metadata.
- [x] 3.4 Add tests for custom jitter implementations and callback-based jitter.

## 4. Fallback And Circuit Predicate Coverage

- [x] 4.1 Add tests for custom fallback predicate implementations and callback-based fallback predicates.
- [x] 4.2 Add tests proving custom fallback predicates compose with built-in predicates using OR, AND, and NOT.
- [x] 4.3 Add tests for custom circuit failure predicate implementations and callback-based circuit predicates.
- [x] 4.4 Add tests proving custom circuit failure predicates compose with built-in predicates using OR, AND, and NOT.

## 5. Documentation And Verification

- [x] 5.1 Update README examples to show the recommended customization paths: simple callbacks, named extension classes, and advanced `RetryPipeline<T>` composition.
- [x] 5.2 Document that `RetryPolicy<T>` remains the canonical convenience facade and `RetryPipeline<T>` is the advanced open composition API.
- [x] 5.3 Run formatter, targeted tests, full test suite, and static analysis.
