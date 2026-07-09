## 1. Rate Limiter Tests

- [x] 1.1 Add token bucket tests for available token acquisition, empty-bucket rejection, retry-after, elapsed-time refill, and capacity clamping.
- [x] 1.2 Add fixed window tests for permit consumption, exhausted-window rejection, retry-after, and reset after window rollover.
- [x] 1.3 Add sliding window tests for rolling permit consumption, rejection, stale segment expiry, and retry-after around segment boundaries.
- [x] 1.4 Add passive limiter tests proving time-based limiters do not require background work and shared limiter instances share limiter state.

## 2. Rate Limiter Implementation

- [x] 2.1 Implement `TokenBucketLimiter` behind the existing `RateLimiter` contract.
- [x] 2.2 Implement `FixedWindowLimiter` behind the existing `RateLimiter` contract.
- [x] 2.3 Implement `SlidingWindowLimiter` behind the existing `RateLimiter` contract.
- [x] 2.4 Validate limiter constructor inputs for positive limits, positive windows or refill periods, valid segment counts, and non-negative initial capacity.
- [x] 2.5 Export new limiter classes through the public package surface.

## 3. Verification

- [x] 3.1 Run Dart format on changed Dart files.
- [x] 3.2 Run Dart analyze.
- [x] 3.3 Run Dart tests.
- [x] 3.4 Run OpenSpec validation for `extend-limiter-and-hedging-context`.
