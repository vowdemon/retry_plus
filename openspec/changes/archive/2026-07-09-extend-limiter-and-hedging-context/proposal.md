## Why

`retry_plus` already exposes an open limiter contract, but common time-window rate limiting algorithms are not available out of the box. This change adds built-in time-based limiters while preserving the existing open strategy model.

## What Changes

- Add built-in time-based rate limiter implementations for token bucket, fixed window, and sliding window behavior.
- Keep `RateLimiterStrategy` algorithm-agnostic: built-in limiters continue to implement the public `RateLimiter` contract and return `RateLimitLease` values.
- Define `retryAfter` behavior for built-in limiter rejections so outer retry strategies can react without knowing the limiter algorithm.
- Add tests for the new limiter algorithms and hedging action context isolation/selection behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `rate-limiter-strategy`: Add built-in token bucket, fixed window, and sliding window limiter requirements with retry-after behavior.

## Impact

- Affected production code: `lib/src/rate_limiter_strategy.dart`.
- Affected tests: `test/rate_limiter_strategy_test.dart`.
- Public API impact: new built-in limiter classes. Existing development-version APIs may be adjusted without compatibility shims.
- No new package dependency is planned; algorithms should use existing time helpers and deterministic clock-based testing.
