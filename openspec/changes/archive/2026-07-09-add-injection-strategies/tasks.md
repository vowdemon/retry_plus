## 1. Public API Shape

- [x] 1.1 Add `lib/src/injection_strategy.dart` with injection triggers and callbacks receiving `RetryPipelineContext<T>` directly.
- [x] 1.2 Implement `InjectionTrigger<T>` on top of `ContextPredicate` with `rate`, `always`, `never`, and `where` factories plus OR/AND/NOT composition.
- [x] 1.3 Validate trigger inputs, including rate range and non-negative generated delays.
- [x] 1.4 Export the injection API from `lib/src/retry_plus.dart`.

## 2. Strategy Implementation

- [x] 2.1 Implement `InjectionThrowStrategy<T>` as a `RetryPipelineStrategy<T>` that emits an event, throws a generated error, and skips the inner pipeline when triggered.
- [x] 2.2 Implement `InjectionDelayStrategy<T>` as a `RetryPipelineStrategy<T>` that emits an event, sleeps through `RetryPipelineContext.sleep`, and then invokes the inner pipeline when triggered.
- [x] 2.3 Implement `InjectionResultStrategy<T>` as a `RetryPipelineStrategy<T>` that emits an event, returns a generated result, and skips the inner pipeline when triggered.
- [x] 2.4 Implement `InjectionBehaviorStrategy<T>` as a `RetryPipelineStrategy<T>` that emits an event, awaits custom behavior, and then invokes the inner pipeline when triggered.
- [x] 2.5 Ensure all injection strategies check cancellation before trigger evaluation and before applying disturbance behavior.

## 3. Pipeline Events

- [x] 3.1 Add `injectionThrow`, `injectionDelay`, `injectionResult`, and `injectionBehavior` to `PipelineEventType`.
- [x] 3.2 Emit injection events only when a strategy triggers; skipped injection must remain silent.
- [x] 3.3 Include public event metadata for strategy name, elapsed time, and kind-specific data such as delay duration.

## 4. Behavior Tests

- [x] 4.1 Add tests for `InjectionTrigger` rate, always, never, custom callback, async callback, and boolean composition.
- [x] 4.2 Add tests that throw injection is visible to outer retry and can be handled by fallback or counted by circuit breaker according to pipeline order.
- [x] 4.3 Add tests that delay injection is covered by outer timeout and observes cancellation while sleeping.
- [x] 4.4 Add tests that result injection can be retried by result-based retry decisions and bypasses the inner operation when triggered.
- [x] 4.5 Add tests that behavior injection runs before the inner operation and propagates behavior callback failures.
- [x] 4.6 Add tests that skipped injection invokes the inner pipeline and emits no injection event.

## 5. Documentation And Specs

- [x] 5.1 Update README with an explicit `RetryPipeline<T>` injection example and placement notes.
- [x] 5.2 Keep `RetryPolicy<T>` documentation free of injection convenience parameters.
- [x] 5.3 Update public API comments for injection contexts, triggers, and strategies.

## 6. Verification

- [x] 6.1 Run `dart format` on modified Dart files.
- [x] 6.2 Run `dart analyze`.
- [x] 6.3 Run targeted injection, pipeline, retry, timeout, fallback, circuit breaker, and hedging tests.
- [x] 6.4 Run `openspec validate add-injection-strategies --strict`.
