## Why

The current retry API splits continuation decisions between outcome predicates and stop strategies, which makes retry behavior harder to reason about and harder to extend toward broad resilience retry capability. Since this is still a development version, the retry API can be simplified around one decision model without preserving the older stop-oriented API.

## What Changes

- **BREAKING** Remove the public stop strategy as a primary retry configuration concept.
- **BREAKING** Make `retryIf` the single decision point for whether another attempt should be scheduled after an outcome.
- Expand retry decision input so callers can decide from outcome, retry index, attempt number, elapsed time, cancellation context, and execution metadata.
- Allow retry decisions to be synchronous or asynchronous.
- Keep delay as an open strategy extension point rather than a fixed enum-based backoff option.
- Expand delay generation so it can express fixed, linear, exponential, random, jittered, stateful, generated, and fallback delay behavior.
- Expand retry hooks so they can be synchronous or asynchronous and observe outcome, retry delay, retry index, attempt duration, and elapsed time without changing the retry decision.
- Preserve final outcome behavior: final exception outcomes are rethrown with stack trace, while final retryable result outcomes return the last result.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `strategy-retry`: Retry continuation decisions move from separate outcome predicate and stop strategy concepts into a unified `retryIf` decision model while preserving open delay and hook extension points.
- `public-extension-points`: Public extension contracts change so retry decisions and delay generation can use richer attempt metadata and `FutureOr` behavior.

## Impact

- Affects public retry APIs in `RetryStrategy<T>`, `RetryPolicy<T>`, top-level `retry<T>(...)`, retry decision types, delay strategy types, retry event types, tests, README, and examples.
- Existing stop-strategy API and tests will be removed or migrated to retry decision combinators.
- No new runtime dependencies are expected.
