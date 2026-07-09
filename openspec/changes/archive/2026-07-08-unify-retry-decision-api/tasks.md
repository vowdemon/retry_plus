## 1. Retry Decision Contract

- [x] 1.1 Add failing tests for `retryIf` receiving typed outcome, retry index, attempt number, elapsed time, attempt duration, and retry context.
- [x] 1.2 Add failing tests for synchronous and asynchronous `retryIf` callbacks.
- [x] 1.3 Introduce attempt-oriented retry decision public contracts and callback factories.
- [x] 1.4 Add retry decision composition for AND, OR, and NOT.
- [x] 1.5 Add retry decision combinators for exception matching, typed exception matching, result matching, and maximum retries.

## 2. Delay Contract

- [x] 2.1 Add failing tests for asynchronous generated delays returning a duration.
- [x] 2.2 Add failing tests for generated delays returning null and falling back to another delay strategy.
- [x] 2.3 Add failing tests for stateful jitter remaining scoped to one retry execution.
- [x] 2.4 Update delay strategy contracts to support `FutureOr<Duration?>` and attempt metadata.
- [x] 2.5 Add or migrate fixed, linear, exponential, random, additive, capped, fallback, generated, and jitter delay implementations.

## 3. Retry Engine

- [x] 3.1 Add failing tests that `retryIf` is the only continuation decision after exception outcomes.
- [x] 3.2 Add failing tests that `retryIf` is the only continuation decision after result outcomes.
- [x] 3.3 Replace stop-strategy checks in the retry loop with the unified retry decision flow.
- [x] 3.4 Preserve final exception rethrow with captured stack trace.
- [x] 3.5 Preserve final retry-handled result exhaustion by returning the last result.
- [x] 3.6 Preserve cancellation as non-retryable control flow that bypasses retry and give-up hooks.

## 4. Retry Hooks And Events

- [x] 4.1 Add failing tests for asynchronous `onRetry` hooks.
- [x] 4.2 Add failing tests for retry hook metadata including retry index, attempt number, attempt duration, elapsed time, outcome, and next delay.
- [x] 4.3 Update retry event arguments and hook invocation to expose the expanded metadata.
- [x] 4.4 Ensure hook failures propagate according to existing retry hook failure behavior.

## 5. API Migration

- [x] 5.1 Remove stop strategy from primary retry policy and top-level retry configuration.
- [x] 5.2 Migrate existing stop-strategy tests to retry decision combinators.
- [x] 5.3 Remove or unexport obsolete stop-strategy retry API surface.
- [x] 5.4 Update README and examples to show `retryIf` as the continuation decision and delay as the wait calculation.
- [x] 5.5 Update public exports to expose the new retry decision and delay contracts.

## 6. Verification

- [x] 6.1 Run focused retry tests.
- [x] 6.2 Run resilience strategy and pipeline tests affected by retry behavior.
- [x] 6.3 Run full Dart test suite.
- [x] 6.4 Run Dart analyzer.
- [x] 6.5 Review OpenSpec deltas against implementation before marking tasks complete.
